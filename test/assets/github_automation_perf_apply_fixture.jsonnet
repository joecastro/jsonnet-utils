local gha = import '../../src/github-automation.libsonnet';

// Self-contained synthetic input for workflow_dispatch environment selection.
local inputConfig = {
  default_environment: gha.environments.dev,
  choices: [gha.environments.dev, gha.environments.prod],
};

local environmentInput = gha.Input(
  'environment',
  'Deployment environment to apply',
  'choice',
  true,
  inputConfig.default_environment,
  inputConfig.choices
);

local workflowTriggers = [
  gha.triggers.manually_invokable_with_inputs([environmentInput]),
];

local selectedEnvironment = gha.expr(
  environmentInput.arg_path('github.event.inputs') + " || '" + gha.environments.dev + "'"
);

local applyInfraStep = gha.Step(
  null,
  'Apply infrastructure',
  uses='./.github/actions/apply-infra',
  with={
    'deploy-env': gha.expr('env.DEPLOY_ENV'),
    role: gha.expr('vars.CLOUD_ROLE_ARN'),
    region: gha.expr('vars.CLOUD_REGION'),
  }
);

local applyJob = gha.Job(
  'apply',
  'Apply infrastructure',
  [
    gha.steps.checkout,
    applyInfraStep,
  ],
  runs_on=gha.runners.ubuntu,
  permissions=gha.permissions.deploy,
  env={
    DEPLOY_ENV: selectedEnvironment,
  },
  environment=selectedEnvironment
);

local workflow = gha.Workflow(
  'Apply Infrastructure',
  workflowTriggers,
  [applyJob],
  {
    group: 'apply-infra-' + gha.expr('github.ref'),
    'cancel-in-progress': true,
  }
);

gha.manifestYamlFast(workflow)
