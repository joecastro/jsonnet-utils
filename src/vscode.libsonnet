// VS Code helpers to define launch/task configs concisely
local stdEx = import './stdEx.libsonnet';
local pkgDef = import './packageDefinitions.libsonnet';

local envMapping = {
  dev: 'Dev',
  staging: 'Staging',
  prod: 'Production',
};

local commonNode = {
  type: 'node',
  request: 'launch',
  cwd: '${workspaceFolder}',
  console: 'integratedTerminal',
  internalConsoleOptions: 'neverOpen',
  skipFiles: ['<node_internals>/**'],
};

local tsxLaunch(name, env) = commonNode + {
  name: name,
  runtimeExecutable: 'node',
  runtimeArgs: ['--import', 'tsx'],
  program: '${workspaceFolder}/src/index.ts',
  env: env,
};

local watchLaunch(name, script, env) = commonNode + {
  name: name,
  runtimeExecutable: 'npm',
  runtimeArgs: ['run', script],
  autoAttachChildProcesses: true,
  env: env,
};

local distLaunch(name, env) = commonNode + {
  name: name,
  program: '${workspaceFolder}/dist/index.js',
  env: env,
};

local attach(port=9229) = {
  name: 'Attach: Node (' + ('' + port) + ')',
  type: 'node',
  request: 'attach',
  port: port,
  restart: true,
  skipFiles: ['<node_internals>/**'],
  cwd: '${workspaceFolder}',
};

// Task helpers
local normalizeDepends(d) =
  if d == null then null
  else if std.isString(d) then d
  else if std.isArray(d) then [normalizeDepends(x) for x in d]
  else d.label;

local commonTask(label, detail=null, group=null, dependsOn=null) = {
  label: label,
  [if detail != null then 'detail']: detail,
  [if group != null && group != 'none' then 'group']: group,
  [if normalizeDepends(dependsOn) != null then 'dependsOn']: normalizeDepends(dependsOn),
};

local tscWatchTask = commonTask('tsc: watch', null, { kind: 'build', isDefault: true }) + {
  type: 'shell',
  command: 'tsc -w --noEmit',
  isBackground: true,
  problemMatcher: '$tsc-watch',
};

local npmTask(label, script, detail, group=null, dependsOn=null) =
  commonTask(label, detail, group, dependsOn) + { type: 'npm', script: script };

local shellTask(label, command, detail, group=null, dependsOn=null) =
  commonTask(label, detail, group, dependsOn) + { type: 'shell', command: command };

local maybeFormatEnvironmentString(w) =
    if std.objectHas(envMapping, w) then envMapping[w] else w;

local formatLabel(scriptName) =
    local parts = std.split(scriptName, ':');
    local first = stdEx.titleCase(parts[0]);
    local second = if std.length(parts) > 1 then ': ' + maybeFormatEnvironmentString(parts[1]) else '';
    local rest = if std.length(parts) > 2 then ' (' + std.join(', ', parts[2:]) + ')' else '';
    if second == '' then first + rest else
    first + second + rest;

local npmTaskFromScript(script, group = null, dependsOn = null) =
  npmTask(formatLabel(script.key), script.key, script.description, group, dependsOn);

{
  // launch helpers
  tsxLaunch: tsxLaunch,
  watchLaunch: watchLaunch,
  distLaunch: distLaunch,
  attach: attach,
  // task helpers
  tscWatchTask: tscWatchTask,
  npmTask: npmTask,
  shellTask: shellTask,
  npmTaskFromScript: npmTaskFromScript,
  taskExecutionGroups: {
    build: 'build',
    test: 'test',
    none: 'none',
  },
}

