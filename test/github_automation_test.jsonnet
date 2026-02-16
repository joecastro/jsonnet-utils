local gha = import '../src/github-automation.libsonnet';
local T = import './test.libsonnet';

local trimTrailingNewline(s) =
  if std.endsWith(s, '\n')
  then std.substr(s, 0, std.length(s) - 1)
  else s;

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
])
