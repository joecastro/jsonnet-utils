local T = import './test.libsonnet';
local pkg = import '../src/packageDefinitions.libsonnet';

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

local expected = '{\n' +
  '    "name": "example",\n' +
  '    "version": "1.0.0",\n' +
  '    "private": true,\n' +
  '    "type": "module",\n' +
  '    "engines": {\n' +
  '        "node": ">=18"\n' +
  '    },\n' +
  '    "scripts": {\n' +
  '        "build": "tsc"\n' +
  '    },\n' +
  '    "scripts-info": {\n' +
  '        "build": "Build"\n' +
  '    },\n' +
  '    "devDependencies": {\n' +
  '        "a": "1.0.0"\n' +
  '    },\n' +
  '    "dependencies": {\n' +
  '        "b": "^2.0.0"\n' +
  '    },\n' +
  '    "description": "d",\n' +
  '    "main": "dist/index.js",\n' +
  '    "homepage": "",\n' +
  '    "author": "",\n' +
  '    "license": "UNLICENSED"\n' +
  '}';

[
  T.equal('manifestPackageJson: sorts keys', pkg.manifestPackageJson(obj), expected),
]
