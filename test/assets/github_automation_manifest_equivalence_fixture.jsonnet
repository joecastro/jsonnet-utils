local gha = import '../../src/github-automation.libsonnet';

local workflow = gha.Workflow(
  'Equivalence',
  [
    gha.triggers.on_push_to_main,
    gha.triggers.manually_invokable,
  ],
  [
    gha.Job(
      'test',
      'Test',
      [
        gha.steps.checkout,
        gha.BashShellStep(
          null,
          'Run',
          run=[
            'echo one',
            'echo two',
          ]
        ),
      ],
      runs_on=gha.runners.ubuntu,
      permissions=gha.permissions.default
    ),
  ],
  {
    group: 'eq-' + gha.expr('github.ref'),
    'cancel-in-progress': true,
  }
);

local composite = gha.CompositeAction(
  'Equivalence Action',
  'Exercise composite rendering equivalence.',
  [
    gha.Input('target', 'Target environment', null, true, gha.environments.dev),
  ],
  [
    gha.steps.setupTerraform('1.9.8'),
    gha.BashShellStep(
      null,
      'Apply',
      run=[
        'echo "target=${{ inputs.target }}"',
        'echo done',
      ]
    ),
  ]
);

{
  workflow: {
    pretty: gha.manifestYamlPretty(workflow),
    fast: gha.manifestYamlFast(workflow),
  },
  composite: {
    pretty: gha.manifestYamlPretty(composite),
    fast: gha.manifestYamlFast(composite),
  },
}
