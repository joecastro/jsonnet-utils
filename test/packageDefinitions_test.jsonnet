local T = import './test.libsonnet';
local pkg = import '../src/packageDefinitions.libsonnet';
local trimTrailingNewline(s) =
  if std.endsWith(s, '\n')
  then std.substr(s, 0, std.length(s) - 1)
  else s;

// manifestPackageJson ordering
local obj = {
  repository: {},
  scripts: { build: 'tsc' },
  name: 'example',
  version: '1.0.0',
  engines: { node: '>=18' },
  private: true,
  type: 'module',
  description: 'd',
  main: 'dist/index.js',
  keywords: [],
  homepage: '',
  author: '',
  license: 'UNLICENSED',
  'scripts-info': { build: 'Build' },
  devDependencies: { a: '1.0.0' },
  dependencies: { b: '^2.0.0' },
};

local expected = trimTrailingNewline(importstr './assets/packageDefinitions_manifestPackageJson_expected.json');

[
  T.equal('manifestPackageJson: sorts keys', pkg.manifestPackageJson(obj), expected),
]
