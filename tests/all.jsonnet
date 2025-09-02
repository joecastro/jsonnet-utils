// Aggregate and summarize all tests (imports are relative to this file)
local regex = import './regex_test.jsonnet';
local stdEx = import './stdEx_test.jsonnet';
local pkg = import './packageDefinitions_test.jsonnet';
local vs = import './vscode_test.jsonnet';
local ext = import './extensionDefinitions_test.jsonnet';
local icons = import './vscode_iconDefinitions_test.jsonnet';

local tests = regex.tests + stdEx + pkg + vs + ext + icons;

{
  total: std.length(tests),
  passed: std.length([t for t in tests if t.pass]),
  failed: std.length([t for t in tests if !t.pass]),
  failures: [t for t in tests if !t.pass],
  // Expose all tests for debugging
  cases: tests,
}
