local stdEx = import '../../src/stdEx.libsonnet';

stdEx.manifestJsonEx({
  recommendations: [
    'Grafana.vscode-jsonnet',
    'EditorConfig.EditorConfig',
    'hbenl.vscode-test-explorer',
    'hbenl.vscode-mocha-test-adapter',
    'dbaeumer.vscode-eslint',
  ],
})
