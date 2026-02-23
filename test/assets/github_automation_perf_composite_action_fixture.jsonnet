local gha = import '../../src/github-automation.libsonnet';

local versions = {
  terraform: '1.9.8',
};

local deployEnvInput = gha.Input('deploy-env', 'Target environment to apply', null, true);
local cloudRoleInput = gha.Input('cloud-role-arn', 'Cloud role ARN for credentials', null, true, '');
local cloudRegionInput = gha.Input('cloud-region', 'Cloud region for credentials', null, true, '');
local actionInputs = [
  deployEnvInput,
  cloudRoleInput,
  cloudRegionInput,
];

local configureCloudStep = gha.Step(
  null,
  'Configure cloud credentials',
  uses='cloudcorp/configure-credentials@v1',
  with={
    role: cloudRoleInput.arg_ref(),
    region: cloudRegionInput.arg_ref(),
  }
);

local setupInfraCliStep = gha.steps.setupTerraform(versions.terraform);

local infraInitStep = gha.BashShellStep(
  null,
  'Initialize infrastructure',
  run=['terraform -chdir=infra/environments/' + deployEnvInput.arg_ref() + ' init']
);

local infraApplyStep = gha.BashShellStep(
  null,
  'Apply infrastructure',
  run=['terraform -chdir=infra/environments/' + deployEnvInput.arg_ref() + ' apply -auto-approve']
);

local createDeploymentStep = gha.steps.githubScript(
  'create-deployment',
  'Create deployment',
  std.join('\n', [
    'const { data } = await github.rest.repos.createDeployment({',
    '  owner: context.repo.owner,',
    '  repo: context.repo.repo,',
    '  ref: context.sha,',
    '  environment: "' + deployEnvInput.arg_ref() + '",',
    '  required_contexts: [],',
    '  transient_environment: false,',
    '  production_environment: false,',
    '  description: "Apply infrastructure for ' + deployEnvInput.arg_ref() + '",',
    '});',
    'core.setOutput("deployment_id", data.id.toString());',
  ])
);

local markDeploymentSuccessStep = gha.steps.githubScript(
  null,
  'Mark deployment success',
  std.join('\n', [
    'await github.rest.repos.createDeploymentStatus({',
    '  owner: context.repo.owner,',
    '  repo: context.repo.repo,',
    '  deployment_id: Number("' + createDeploymentStep.output_ref('deployment_id') + '"),',
    '  state: "success",',
    '  environment: "' + deployEnvInput.arg_ref() + '",',
    '  log_url: `https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`,',
    '});',
  ])
) + { 'if': createDeploymentStep.output_ref('deployment_id', "!= ''") };

local applyAction = gha.CompositeAction(
  'Apply Infrastructure',
  'Apply infrastructure for a target environment.',
  actionInputs,
  [
    configureCloudStep,
    setupInfraCliStep,
    infraInitStep,
    infraApplyStep,
    createDeploymentStep,
    markDeploymentSuccessStep,
  ]
);

gha.manifestYamlFast(applyAction)
