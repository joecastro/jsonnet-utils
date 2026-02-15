local stdEx = import './stdEx.libsonnet';

local packageManagers = {
  npm: {
    name: 'npm',
    argSeparator: ' -- ',
  },
  pnpm: {
    name: 'pnpm',
    argSeparator: ' ',
  },
  yarn: {
    name: 'yarn',
    argSeparator: ' -- ',
  },
};

local Dependency(name, version, minVersion=false) = {
  name: name,
  version: (if minVersion then '^' else '') + version,
};

local Engine(name, version) = {
  name: name,
  version: version,
};

// Script helpers

// Elements in `dependsOn` can be either Script objects or [Script, args] arrays
// where `args` is a string of extra arguments to pass to the script when invoked as a dependency.
local normalizeDependsScript(d) =
  if std.isArray(d) then {
    script: d[0],
    args: d[1],
  } else {
    script: d,
    args: '',
  };

local makeCommand(script, args, runBin, env) =
  local env_prefix = if !script.isEnvSensitive || env == {}
  then ''
  else std.join(' ', [k + '=' + env[k] for k in std.objectFields(env)]) + ' ';
  local script_action = if runBin == 'shell'
  then script.shellAction(args)
  else script.pmAction(runBin, args);
  if script_action == ''
  then ''
  else env_prefix + script_action;

local Script(key, runBin, action, description, isEnvSensitive, dependsOn) = {
  key: key,
  runBin: runBin,
  isEnvSensitive: isEnvSensitive,
  envVars: {},
  args: '',
  action: action,
  description: description,
  shellAction(args)::
    local a = stdEx.firstNonEmpty([args, $.args], '');
    local args_suffix = if a == '' then '' else ' ' + a;
    assert action != '' || args_suffix == '' : 'Shell script must have an action defined if args are provided';
    if action == '' then '' else action + args_suffix,
  pmAction(pm, args)::
    local pmObj = packageManagers[pm];
    local a = stdEx.firstNonEmpty([args, $.args], '');
    local args_suffix = if a == '' then '' else pmObj.argSeparator + a;
    pm + ' run ' + $.key + args_suffix,
  command()::
    local this_script_command = makeCommand($, $.args, 'shell', $.envVars);
    local this_script_command_array = if this_script_command == '' then [] else [this_script_command];
    local normalized_dependencies = [normalizeDependsScript(dep) for dep in dependsOn];
    local dependency_commands = [makeCommand(dep.script, dep.args, runBin, $.envVars) for dep in normalized_dependencies];
    std.join(' && ', dependency_commands + this_script_command_array),
};

local ShellScript(key, action, description, isEnvSensitive=false, dependsOn=[]) =
  Script(key, 'shell', action, description, isEnvSensitive, dependsOn);

// PackageScript is a specialization of Script that also exposes `<pm> run <key>` as its subscript action
// Pass the package manager explicitly ('pnpm' | 'npm')
local PackageScript(pm, key, action='', description, isEnvSensitive=false, dependsOn=[]) =
  Script(key, pm, action, description, isEnvSensitive, dependsOn) + {
    // Subscripts invoke the script via the package manager
    subscript(subkey, description):: $ {
      key: $.key + ':' + subkey,
      action: pm + ' run ' + $.key,
      description: description,
    },
  };

local Package(name, description, version, main, engine, packageManager, devDependencies, dependencies, scripts) = {
  name: name,
  description: description,
  version: version,
  main: main,
  engines: {
    [engine.name]: engine.version,
  },
  packageManager: packageManager,
  private: true,
  type: 'module',
  keywords: [],
  author: '',
  license: 'UNLICENSED',
  devDependencies: { [d.name]: d.version for d in devDependencies },
  dependencies: { [d.name]: d.version for d in dependencies },
  scripts: { [s.key]: s.command() for s in scripts },
  'scripts-info': { [s.key]: s.description for s in scripts },

  obj_devDependencies:: devDependencies,
  obj_dependencies:: dependencies,
  obj_scripts:: scripts,
};

local preferred_key_order = [
  '//',
  'id',
  'name',
  'displayName',
  'version',
  'private',
  'type',
  'engines',
  'packageManager',
  'scripts',
  'scripts-info',
  'devDependencies',
  'dependencies',
  'description',
  'main',
  'types',
  'keywords',
  'homepage',
  'author',
  'license',
  'repository',
];

local packageJsonKeySorter(key) =
  local index = stdEx.indexOf(preferred_key_order, key);
  if index != -1 then '%03d' % index + key else '999' + key;

local manifestPackageJson(packageInfo) = stdEx.manifestJsonEx(
  std.prune(packageInfo),
  key_sort_func=packageJsonKeySorter
);

{
  packageManagers: { [k]: k for k in std.objectFields(packageManagers) },

  manifestPackageJson:: manifestPackageJson,
  Dependency:: Dependency,
  Engine:: Engine,
  Package:: Package,
  PackageScript:: PackageScript,
  Script:: ShellScript,
}
