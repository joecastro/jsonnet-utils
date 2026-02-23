local stdEx = import '../src/stdEx.libsonnet';
local T = import './test.libsonnet';
local trimTrailingNewlines(s) =
  if std.endsWith(s, '\n')
  then trimTrailingNewlines(std.substr(s, 0, std.length(s) - 1))
  else s;
local trimTrailingNewline(s) =
  trimTrailingNewlines(s);
local fromLines(lines) = std.join('\n', lines) + '\n';

local words = 'hello-world_test';

local props_input = { a: true, b: 2, c: null };
// Note: keys sorted alphabetically: a, b, c
local props_expected = 'a=true\nb=2\nc=';
local pretty_yaml_options = stdEx.manifestYamlProfiles.pretty;

T.suite('stdEx', [
  T.equal('indexOf: present', stdEx.indexOf([1, 2, 3], 2), 1),
  T.equal('indexOf: missing -> -1', stdEx.indexOf([1, 2, 3], 9), -1),

  T.equal('pascalCase', stdEx.pascalCase(words), 'HelloWorldTest'),
  T.equal('camelCase', stdEx.camelCase(words), 'helloWorldTest'),
  T.equal('titleCase', stdEx.titleCase('hello world'), 'Hello World'),

  T.equal('manifestProperties', stdEx.manifestProperties(props_input), props_expected),

  // regex passthroughs
  T.truthy('matchRegex passthrough', stdEx.matchRegex('a.c', 'abc')),
  T.truthy('validateRegex passthrough ok', stdEx.validateRegex('a.c').ok),

  // new: objectFromArrays
  T.equal('objectFromArrays', stdEx.objectFromArrays(['a', 'b'], [1, 2]), { a: 1, b: 2 }),

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
    'manifestYamlEx orders name/on first with blank lines',
    stdEx.manifestYamlEx({
      jobs: { test: { 'runs-on': 'ubuntu-latest' } },
      name: 'Example',
      on: { push: {} },
    }, pretty_yaml_options { compact_null_children_of_top_level_key: null }),
    trimTrailingNewline(importstr './assets/stdEx_manifestYaml_order_expected.yml')
  ),
  T.equal(
    'manifestYamlEx can unquote safe strings',
    stdEx.manifestYamlEx(
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
      pretty_yaml_options
    ),
    trimTrailingNewline(importstr './assets/stdEx_manifestYaml_unquote_safe_strings_expected.yml')
  ),
  T.equal(
    'manifestYamlEx keeps backslash-escaped values quoted and keeps leading * quoted',
    stdEx.manifestYamlEx(
      {
        alias: '*build',
        escaped: 'line\\nvalue',
      },
      pretty_yaml_options
    ),
    'alias: "*build"\n\nescaped: "line\\\\nvalue"'
  ),
  T.equal(
    'manifestYamlEx handles complex workflow rendering',
    stdEx.manifestYamlEx({
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
              run: fromLines([
                'npm ci',
                'npm test',
                'npm run lint',
              ]),
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
    }, pretty_yaml_options { compact_null_children_of_top_level_key: null }),
    trimTrailingNewline(importstr './assets/stdEx_manifestYaml_complex_workflow_expected.yml')
  ),
  T.equal(
    'manifestYamlEx keeps scalar quotes when unquote is disabled',
    stdEx.manifestYamlEx(
      {
        jobs: {
          demo: {
            steps: [
              {
                name: 'Echo',
                run: fromLines([
                  'echo hello',
                  'echo world',
                ]),
              },
            ],
          },
        },
        labels: ['alpha', 'beta', '123'],
        name: 'Quoted Mode',
      },
      pretty_yaml_options {
        unquote_safe_strings: false,
        top_level_key_order: ['jobs', 'labels', 'name'],
      }
    ),
    trimTrailingNewline(importstr './assets/stdEx_manifestYaml_unquote_disabled_expected.yml')
  ),
  T.equal(
    'manifestYamlEx accepts profile string options',
    {
      pretty: stdEx.manifestYamlEx(
        { name: 'Example', on: { push: {} }, jobs: { test: { 'runs-on': 'ubuntu-latest' } } },
        'pretty'
      ),
      fast: stdEx.manifestYamlEx(
        { name: 'Example', on: { push: {} }, jobs: { test: { 'runs-on': 'ubuntu-latest' } } },
        'fast'
      ),
    },
    {
      pretty: stdEx.manifestYamlEx(
        { name: 'Example', on: { push: {} }, jobs: { test: { 'runs-on': 'ubuntu-latest' } } },
        stdEx.manifestYamlProfiles.pretty
      ),
      fast: stdEx.manifestYamlEx(
        { name: 'Example', on: { push: {} }, jobs: { test: { 'runs-on': 'ubuntu-latest' } } },
        stdEx.manifestYamlProfiles.fast
      ),
    }
  ),
  T.equal(
    'manifestYamlEx can disable on normalization and null compaction',
    stdEx.manifestYamlEx(
      {
        on: {
          workflow_dispatch: {},
        },
      },
      pretty_yaml_options {
        normalize_top_level_on_key: false,
        compact_null_values: false,
      }
    ),
    '"on":\n  workflow_dispatch: {}'
  ),
])
