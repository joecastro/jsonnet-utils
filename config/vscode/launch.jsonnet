local stdEx = import '../../src/stdEx.libsonnet';
local vs = import '../../src/vscode.libsonnet';

stdEx.manifestJsonEx({
  version: '0.2.0',
  configurations: [
    vs.commonLaunch('Run Tests (npm)', 'node', 'npm', ['test']) + {
      console: 'integratedTerminal',
    },
  ],
})
