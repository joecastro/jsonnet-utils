local stdEx = import '../../src/stdEx.libsonnet';

stdEx.manifestJsonEx({
  recommendations: [
    'Grafana.vscode-jsonnet',
    'EditorConfig.EditorConfig',
    'johnpapa.vscode-peacock',
    'hbenl.vscode-test-explorer',
    'hbenl.vscode-mocha-test-adapter',
    'dbaeumer.vscode-eslint',
  ],
})
