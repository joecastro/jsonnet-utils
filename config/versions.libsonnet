local pkgDef = import '../src/packageDefinitions.libsonnet';

{
  node: '>=24',
  npm: '>=11',
  packageManager: 'npm@11.6.2',
  dependencies: [],
  devDependencies: [
    pkgDef.Dependency('eslint', '10.0.0', true),
    pkgDef.Dependency('mocha', '11.7.5', true),
  ],
}
