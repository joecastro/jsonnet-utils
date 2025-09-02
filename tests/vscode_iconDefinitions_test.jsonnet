local T = import './test.libsonnet';
local icons = import '../src/vscode-iconDefinitions.libsonnet';

local s = icons.StandardIcon('rocket');
local i = icons.IconDefinition('plane', 'Airplane', 'font.ttf', '\uE001');

[
  T.equal('StandardIcon id format', s.id, '$(rocket)'),
  T.equal('IconDefinition projection.default.fontPath', i.projection.default.fontPath, 'font.ttf'),
]
