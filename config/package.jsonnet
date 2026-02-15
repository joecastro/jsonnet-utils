local pkgDef = import '../src/packageDefinitions.libsonnet';
local versions = import './versions.libsonnet';

local dependencyMap(dependencies) = { [d.name]: d.version for d in dependencies };
local formatJsonnetScript = pkgDef.Script(
  'format:jsonnet',
  "find . -type f \\( -name '*.jsonnet' -o -name '*.libsonnet' \\) -not -path './node_modules/*' -not -path './out/*' -not -path './.git/*' -exec jsonnetfmt -i {} +",
  'Format Jsonnet files with jsonnetfmt'
);
local lintFixScript = pkgDef.Script(
  'lint:fix',
  'eslint . --fix',
  'Run ESLint with auto-fix',
  dependsOn=[formatJsonnetScript]
);

local scripts = [
  pkgDef.Script('bootstrap', 'python3 scripts/bootstrap_config.py', 'Generate repo config files'),
  pkgDef.Script('bootstrap:check', 'python3 scripts/bootstrap_config.py --check', 'Validate generated repo config files'),
  pkgDef.Script(
    'publish',
    "rm -rf dist && mkdir -p dist && find src -maxdepth 1 -type f \\( -name '*.jsonnet' -o -name '*.libsonnet' \\) -exec cp {} dist/ \\;",
    'Build dist with source Jsonnet files'
  ),
  pkgDef.Script('update:versions', 'python3 scripts/update_versions.py', 'Update config/versions.libsonnet from npm and local toolchain versions'),
  pkgDef.Script('test', 'mocha "test/**/*.spec.js"', 'Run tests'),
  pkgDef.Script('lint', 'eslint .', 'Run ESLint'),
  formatJsonnetScript,
  lintFixScript,
];

pkgDef.manifestPackageJson({
  name: 'jsonnet-utils',
  version: '0.0.0',
  private: true,
  description: 'Reusable Jsonnet helpers and utilities',
  license: 'UNLICENSED',
  engines: {
    node: versions.node,
    npm: versions.npm,
  },
  packageManager: versions.packageManager,
  scripts: { [s.key]: s.command() for s in scripts },
  dependencies: dependencyMap(versions.dependencies),
  devDependencies: dependencyMap(versions.devDependencies),
})
