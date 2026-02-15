local T = import './test.libsonnet';
local vs = import '../src/vscode.libsonnet';

local fakeScript(key, description='desc') = { key: key, description: description };

local task1 = vs.npmTaskFromScript(fakeScript('build:dev'), null, null);
local task2 = vs.npmTaskFromScript(fakeScript('deploy:prod:canary:fast'), null, null);
local testTask = vs.npmTestTask();
local attach = vs.attach(9333);

[
  T.equal('npmTaskFromScript label (env mapping)', task1.label, 'Build: Dev'),
  T.equal('npmTaskFromScript label (rest in parens)', task2.label, 'Deploy: Production (canary, fast)'),
  T.equal('npmTestTask default script', testTask.script, 'test'),
  T.equal('npmTestTask group kind', testTask.group.kind, 'test'),
  T.truthy('npmTestTask is default', testTask.group.isDefault),
  T.equal('attach name', attach.name, 'Attach: Node (9333)'),
]
