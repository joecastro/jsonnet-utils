local pkgDef = import '../src/packageDefinitions.libsonnet';

{
  node: '>=24',
  npm: '>=11',
  packageManager: 'npm@11.6.2',
  dependencies: [],
  devDependencies: [
    pkgDef.Dependency('@eslint/eslintrc', '3.3.3', true),
    pkgDef.Dependency('@eslint/js', '10.0.1', true),
    pkgDef.Dependency('eslint', '10.0.0', true),
    pkgDef.Dependency('globals', '17.3.0', true),
    pkgDef.Dependency('mocha', '11.7.5', true),
  ],
}
