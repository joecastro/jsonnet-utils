local T = import './test.libsonnet';
local stdEx = import '../src/stdEx.libsonnet';

local words = 'hello-world_test';

local props_input = { a: true, b: 2, c: null };
// Note: keys sorted alphabetically: a, b, c
local props_expected = 'a=true\nb=2\nc=';

[
  T.equal('indexOf: present', stdEx.indexOf([1,2,3], 2), 1),
  T.equal('indexOf: missing -> -1', stdEx.indexOf([1,2,3], 9), -1),

  T.equal('pascalCase', stdEx.pascalCase(words), 'HelloWorldTest'),
  T.equal('camelCase', stdEx.camelCase(words), 'helloWorldTest'),
  T.equal('titleCase', stdEx.titleCase('hello world'), 'Hello World'),

  T.equal('manifestProperties', stdEx.manifestProperties(props_input), props_expected),

  // regex passthroughs
  T.truthy('matchRegex passthrough', stdEx.matchRegex('a.c', 'abc')),
  T.truthy('validateRegex passthrough ok', stdEx.validateRegex('a.c').ok),
]
