local gha = import '../../src/github-automation.libsonnet';

// Self-contained synthetic inputs for representative workflow rendering load.
local inputs = {
  env: gha.environments.staging,
  services: [
    {
      name: 'service-' + std.toString(i),
      package: '@repo/service-' + std.toString(i),
    }
    for i in std.range(0, 1)
  ],
  frontends: [
    {
      name: 'frontend-' + std.toString(i),
      package: '@repo/frontend-' + std.toString(i),
    }
    for i in std.range(0, 1)
  ],
};

local env = inputs.env;
local services = inputs.services;
local frontends = inputs.frontends;

local skipDeployInput = gha.Input('skip_deploy', 'Skip deploy phase', 'boolean', false, false);
local workflowInputs = [skipDeployInput];
local skipDeployRef = skipDeployInput.arg_ref('inputs');
local deployEnvRef = gha.expr('env.DEPLOY_ENV');
local cloudRoleVar = gha.expr('vars.CLOUD_ROLE_ARN');
local cloudRegionVar = gha.expr('vars.CLOUD_REGION');

local workflowTriggers =
  if env == gha.environments.prod then
    [
      gha.triggers.manually_invokable_with_inputs(workflowInputs),
    ]
  else
    [
      gha.triggers.on_push_to_main,
      gha.triggers.manually_invokable_with_inputs(workflowInputs),
    ];

local infraJobId = 'infra';
local orderedServices = std.sort([s.name for s in services]);
local frontendByName = { [f.name]: f for f in frontends };
local orderedFrontends = [frontendByName[name] for name in std.sort(std.objectFields(frontendByName))];
local serviceJobIds = ['publish-service-' + name for name in orderedServices];

local checkoutStep = gha.steps.checkout;

local setupCloudStep = gha.Step(
  null,
  'Set up cloud',
  uses='cloudcorp/setup-runner@v1',
  with={
    role: cloudRoleVar,
    region: cloudRegionVar,
  }
);

local applyInfraStep = gha.Step(
  null,
  'Apply infrastructure',
  uses='./.github/actions/apply-infra',
  with={
    'deploy-env': deployEnvRef,
    role: cloudRoleVar,
    region: cloudRegionVar,
  }
);

local infraJob = gha.Job(
  infraJobId,
  'Apply infrastructure',
  [
    checkoutStep,
    applyInfraStep,
  ],
  runs_on=gha.runners.ubuntu,
  permissions=gha.permissions.deploy,
  env={
    DEPLOY_ENV: env,
  },
  environment=env
);

local publishServiceStep(name) =
  gha.BashShellStep(
    null,
    'Publish service',
    run=[
      'args=(service "' + name + '" --environment "' + deployEnvRef + '")',
      'if [ "' + skipDeployRef + '" = "true" ]; then args+=(--skip-deploy); fi',
      'echo "meta: name=' + name + ' ? phase=publish"',
      'uv run publish "${args[@]}"',
    ]
  );

local serviceJobs = [
  gha.Job(
    'publish-service-' + name,
    'Publish ' + name,
    [
      checkoutStep,
      setupCloudStep,
      publishServiceStep(name),
    ],
    runs_on=gha.runners.ubuntu,
    needs=[infraJobId],
    env={
      DEPLOY_ENV: env,
      SERVICE_NAME: name,
    },
    environment=env,
    permissions=gha.permissions.default
  )
  for name in orderedServices
];

local deployFrontendStep(frontend) =
  gha.BashShellStep(
    null,
    'Deploy frontend',
    run=[
      'pnpm install --filter "' + frontend.package + '..." --frozen-lockfile --prefer-offline',
      'echo "target: ' + frontend.name + ' / env=' + deployEnvRef + '"',
      'uv run publish frontend "' + frontend.name + '" --environment "' + deployEnvRef + '"',
    ]
  );

local frontendJobs = [
  gha.Job(
    'deploy-frontend-' + f.name,
    'Deploy ' + f.name,
    [
      checkoutStep,
      setupCloudStep,
      deployFrontendStep(f),
    ],
    runs_on=gha.runners.ubuntu,
    needs=[infraJobId] + serviceJobIds,
    env={
      DEPLOY_ENV: env,
      FRONTEND_NAME: f.name,
    },
    environment=env,
    permissions=gha.permissions.default
  )
  for f in orderedFrontends
];

local workflow = gha.Workflow(
  'Publish Platform (' + env + ')',
  workflowTriggers,
  [infraJob] + serviceJobs + frontendJobs
);

gha.manifestYamlFast(workflow)
