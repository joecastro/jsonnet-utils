local stdEx = import './stdEx.libsonnet';

local Dependency(name, version, minVersion=false) = {
    name: name,
    version: (if minVersion then "^" else "") + version,
};

local envAssign(env) =
  if env == {} then ''
  else std.join(' ', [k + '=' + env[k] for k in std.objectFields(env)]) + ' ';

local npmRunArgSuffix(args) =
   if args == '' || args == null then ''
   else ' -- ' + args;

local Script(key, action = '', description, dependsOn=[]) = {
    key: key,
    action: std.join(' && ', ['npm run ' + x.key for x in dependsOn] + (if action != '' then [action] else [])),
    description: description,
    projection():: self.action,
    subscript(subkey, description):: $ {
        key: $.key + ':' + subkey,
        action: 'npm run ' + $.key,
        description: description,
    },
    withArgs(args, envVars = {}):: $ {
        args: args,
        envVars: envVars,
        action: envAssign(envVars) + $.action + npmRunArgSuffix(args),
    },

};

local Engine(name, version) = {
    name: name,
    version: version,
};

local Package(name, description, version, main, engine, devDependencies, dependencies, scripts) = {
    name: name,
    description: description,
    version: version,
    main: main,
    engine: engine,
    devDependencies: devDependencies,
    dependencies: dependencies,
    scripts: scripts,
    projection():: self + {
        engine: null,
        engines: {
          [$.engine.name]: $.engine.version,
        },
        private: true,
        type: "module",
        keywords: [],
        author: "",
        license: "UNLICENSED",
        devDependencies: { [d.name]: d.version for d in $.devDependencies },
        dependencies: { [d.name]: d.version for d in $.dependencies },
        scripts: { [s.key]: s.projection() for s in $.scripts },
        'scripts-info': { [s.key]: s.description for s in $.scripts },
    },
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
    'scripts',
    'scripts-info',
    'devDependencies',
    'dependencies',
    'description',
    'main',
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
    '    ',
    '\n',
    ': ',
    packageJsonKeySorter);

{
    manifestPackageJson: manifestPackageJson,
    Dependency:: Dependency,
    Engine:: Engine,
    Package:: Package,
    Script:: Script,
}
