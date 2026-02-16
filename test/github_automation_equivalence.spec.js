const assert = require('assert');
const { execFileSync, spawnSync } = require('child_process');
const path = require('path');

const fixturePath = path.join(__dirname, 'assets/github_automation_manifest_equivalence_fixture.jsonnet');

const sortDeep = (value) => {
  if (typeof value === 'string') {
    if (value.includes('\n') && value.endsWith('\n')) return value.slice(0, -1);
    return value;
  }
  if (Array.isArray(value)) return value.map(sortDeep);
  if (value && typeof value === 'object') {
    const out = {};
    for (const key of Object.keys(value).sort()) out[key] = sortDeep(value[key]);
    return out;
  }
  return value;
};

const parseYamlToObject = (yamlText) => {
  const rubyScript = `
require 'yaml'
require 'json'
input = STDIN.read
obj = YAML.safe_load(input, permitted_classes: [], aliases: false)
puts JSON.generate(obj)
`;
  const result = spawnSync('ruby', ['-e', rubyScript], { input: yamlText, encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(`Ruby YAML parse failed: ${result.stderr || result.stdout}`);
  }
  return JSON.parse(result.stdout);
};

describe('github automation yaml equivalence', () => {
  const outputs = JSON.parse(execFileSync('jsonnet', [fixturePath], { encoding: 'utf8' }));

  const assertEquivalent = (name, prettyYaml, fastYaml) => {
    const prettyObj = sortDeep(parseYamlToObject(prettyYaml));
    const fastObj = sortDeep(parseYamlToObject(fastYaml));
    assert.deepStrictEqual(fastObj, prettyObj, `${name} fast/pretty YAML should be functionally equivalent`);
  };

  it('workflow pretty and fast outputs are equivalent in-memory', () => {
    assertEquivalent('workflow', outputs.workflow.pretty, outputs.workflow.fast);
  });

  it('composite pretty and fast outputs are equivalent in-memory', () => {
    assertEquivalent('composite', outputs.composite.pretty, outputs.composite.fast);
  });
});
