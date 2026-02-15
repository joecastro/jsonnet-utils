local gha = import '../../../src/github-automation.libsonnet';
local jsonnet_version = '0.21.0';
local jsonnet_cache_key = 'jsonnet-' + gha.expr('runner.os') + '-v' + jsonnet_version;

local workflow = gha.Workflow(
  'Jsonnet Tests',
  [
    { push: {} },
    { pull_request: {} },
  ],
  [
    gha.Job(
      'test',
      'Run tests',
      [
        gha.steps.checkout,
        gha.steps.setupNode('20'),
        gha.steps.cache(
          'jsonnet-cache',
          'Restore jsonnet cache',
          '~/.cache/jsonnet',
          jsonnet_cache_key
        ),
        gha.steps.buildJsonnet(jsonnet_version),
        gha.Step(null, 'Install deps', run='npm ci'),
        gha.Step(null, 'Check generated config drift', run='npm run bootstrap:check'),
        gha.Step(null, 'Lint', run='npm run lint'),
        gha.Step(null, 'Run tests (Mocha)', run='npm test'),
      ],
      gha.runners.ubuntu,
      gha.permissions.default
    ),
  ]
);

gha.manifestYaml(workflow)
