local gha = import '../src/github-automation.libsonnet';
local T = import './test.libsonnet';

local trimTrailingNewlines(s) =
  if std.endsWith(s, '\n')
  then trimTrailingNewlines(std.substr(s, 0, std.length(s) - 1))
  else s;
local trimTrailingNewline(s) =
  trimTrailingNewlines(s);

local sampleJob = gha.Job(
  'test',
  'Test',
  [gha.steps.checkout],
  gha.runners.ubuntu,
  gha.permissions.default
);

T.suite('github-automation', [
  T.equal(
    'Workflow manifest renders empty pull_request trigger using empty Github syntax when mixed with configured triggers',
    gha.manifestYamlPretty(
      gha.Workflow(
        'CI',
        [
          { pull_request: {} },
          gha.triggers.on_push_to_main,
        ],
        [sampleJob]
      )
    ),
    trimTrailingNewline(importstr './assets/github_automation_manifest_pull_request_empty_expected.yml')
  ),
  T.equal(
    'Workflow manifest renders empty workflow_dispatch trigger using empty Github syntax when mixed with configured triggers',
    gha.manifestYamlPretty(
      gha.Workflow(
        'CI',
        [
          gha.triggers.manually_invokable,
          gha.triggers.on_push_to_main,
        ],
        [sampleJob]
      )
    ),
    trimTrailingNewline(importstr './assets/github_automation_manifest_workflow_dispatch_empty_expected.yml')
  ),
  T.equal(
    'Workflow manifest renders job strategy matrix',
    gha.manifestYamlPretty(
      gha.Workflow(
        'Matrix CI',
        [
          gha.triggers.on_push_to_main,
        ],
        [
          gha.Job(
            'test',
            'Test Matrix',
            [gha.steps.checkout],
            gha.runners.ubuntu,
            gha.permissions.default,
            strategy={
              matrix: {
                node: ['18', '20'],
              },
            }
          ),
        ]
      )
    ),
    'name: Matrix CI\n\non:\n  push:\n    branches:\n    - main\n\njobs:\n  test:\n    name: Test Matrix\n    permissions:\n      contents: read\n      id-token: write\n    runs-on: ubuntu-22.04\n    steps:\n    - name: Checkout\n      uses: actions/checkout@v4\n      with:\n        fetch-depth: 0\n    strategy:\n      matrix:\n        node:\n        - "18"\n        - "20"'
  ),
])
