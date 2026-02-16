local T = import './test.libsonnet';
local stdEx = import '../src/stdEx.libsonnet';
local trimTrailingNewline(s) =
  if std.endsWith(s, '\n')
  then std.substr(s, 0, std.length(s) - 1)
  else s;

local words = 'hello-world_test';

local props_input = { a: true, b: 2, c: null };
// Note: keys sorted alphabetically: a, b, c
local props_expected = 'a=true\nb=2\nc=';

T.suite('stdEx', [
    T.equal('indexOf: present', stdEx.indexOf([1,2,3], 2), 1),
    T.equal('indexOf: missing -> -1', stdEx.indexOf([1,2,3], 9), -1),

    T.equal('pascalCase', stdEx.pascalCase(words), 'HelloWorldTest'),
    T.equal('camelCase', stdEx.camelCase(words), 'helloWorldTest'),
    T.equal('titleCase', stdEx.titleCase('hello world'), 'Hello World'),

    T.equal('manifestProperties', stdEx.manifestProperties(props_input), props_expected),

    // regex passthroughs
    T.truthy('matchRegex passthrough', stdEx.matchRegex('a.c', 'abc')),
    T.truthy('validateRegex passthrough ok', stdEx.validateRegex('a.c').ok),

    // new: objectFromArrays
    T.equal('objectFromArrays', stdEx.objectFromArrays(['a','b'], [1,2]), { a: 1, b: 2 }),

    // new: manifestJson (basic)
    T.equal(
      'manifestJson simple object',
      stdEx.manifestJson({ a: 1 }),
      trimTrailingNewline(importstr './assets/stdEx_manifestJson_simple_object_expected.json')
    ),
    T.equal(
      'manifestJsonEx defaults prioritize version key',
      stdEx.manifestJsonEx({ z: 1, version: '1.2.3', a: 2 }),
      trimTrailingNewline(importstr './assets/stdEx_manifestJsonEx_version_first_expected.json')
    ),
    T.equal(
      'manifestYamlWithRunBlocks orders name/on first with blank lines',
      stdEx.manifestYamlWithRunBlocks({
        jobs: { test: { 'runs-on': 'ubuntu-latest' } },
        name: 'Example',
        on: { push: {} },
      }),
      trimTrailingNewline(importstr './assets/stdEx_manifestYaml_order_expected.yml')
    ),
    T.equal(
      'manifestYamlWithRunBlocks supports custom key sorting/newlines',
      stdEx.manifestYamlWithRunBlocks(
        { b: 2, a: 1 },
        '\n',
        '\n---\n',
        function(k) k
      ),
      trimTrailingNewline(importstr './assets/stdEx_manifestYaml_custom_separator_expected.yml')
    ),
    T.equal(
      'manifestYamlWithRunBlocks can unquote safe strings',
      stdEx.manifestYamlWithRunBlocks(
        {
          a: 'hello world',
          b: 'on',
          c: '123',
          d: 'actions/checkout@v4',
          e: '1e3',
          f: 'line\\nvalue',
          g: 'name: value',
          h: 'bootstrap:check',
        },
        '\n',
        '\n\n',
        function(k) k,
        true
      ),
      trimTrailingNewline(importstr './assets/stdEx_manifestYaml_unquote_safe_strings_expected.yml')
    ),
    T.equal(
      'manifestYamlWithRunBlocks handles complex workflow rendering',
      stdEx.manifestYamlWithRunBlocks({
        jobs: {
          build: {
            'runs-on': 'ubuntu-latest',
            steps: [
              {
                name: 'Setup',
                uses: 'actions/setup-node@v4',
                with: {
                  'node-version': '20',
                  cache: 'npm',
                },
              },
              {
                name: 'Test',
                run: 'npm ci\nnpm test\nnpm run lint',
              },
              {
                name: 'Args',
                with: {
                  args: [
                    'bootstrap:check',
                    'name: value',
                    '123',
                    'actions/checkout@v4',
                    '? weird',
                    'alpha_beta-1',
                  ],
                },
              },
            ],
          },
        },
        name: 'CI',
        on: { pull_request: {}, push: { branches: ['main'] } },
      }),
      trimTrailingNewline(importstr './assets/stdEx_manifestYaml_complex_workflow_expected.yml')
    ),
    T.equal(
      'manifestYamlWithRunBlocks keeps scalar quotes when unquote is disabled',
      stdEx.manifestYamlWithRunBlocks(
        {
          jobs: {
            demo: {
              steps: [
                {
                  name: 'Echo',
                  run: 'echo hello\necho world',
                },
              ],
            },
          },
          labels: ['alpha', 'beta', '123'],
          name: 'Quoted Mode',
        },
        '\n',
        '\n\n',
        function(k) k,
        false
      ),
      trimTrailingNewline(importstr './assets/stdEx_manifestYaml_unquote_disabled_expected.yml')
    ),
])
