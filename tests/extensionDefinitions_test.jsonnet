local T = import './test.libsonnet';
local ext = import '../src/extensionDefinitions.libsonnet';

local cfg = ext.bind('myext').ConfigurationProperty;

local cp_text = cfg.String('foo', 'Plain text');
local cp_md = cfg.String('bar', 'Use [link] in text');

local icon = { key: 'beaker' };
local cmd = ext.FullCommandDefinition('Title', 'Cat', 'myext.cmd', icon, 'whenExpr');

local aspect = ext.AspectDefinition(
  { name: 'myext' },
  'Build',
  'build',
  [ ext.Command('Run', 'run', icon) ]
);

[
  T.equal('ConfigurationProperty: plain uses description', cp_text.projection.description, 'Plain text'),
  T.equal('ConfigurationProperty: markdown uses markdownDescription', cp_md.projection.markdownDescription, 'Use [link] in text'),

  T.equal('FullCommandDefinition: icon projection', cmd.icon, '$(beaker)'),
  T.equal('FullCommandDefinition: enablement key', cmd.enablement, 'whenExpr'),

  T.equal('AspectDefinition: commandProjection count', std.length(aspect.commands_projection), 1),
  T.equal('AspectDefinition: commandProjection command', aspect.commands_projection[0].command, 'myext.build.run'),
]
