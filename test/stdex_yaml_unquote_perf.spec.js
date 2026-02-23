const assert = require('assert');
const { execFileSync } = require('child_process');
const { performance } = require('perf_hooks');

const repoRoot = `${__dirname}/..`;
const scenarioLineCount = Number(process.env.STDEX_UNQUOTE_PROFILE_LINES || 20000);
const scenarioIterations = Number(process.env.STDEX_UNQUOTE_PROFILE_ITERATIONS || 3);

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
};

const jsonnetExprForScenario = (scenario, lineCount) => {
  let lineExpr;
  if (scenario === 'plain_unquoted') {
    lineExpr = '\'k\' + std.toString(i) + \': value\'';
  } else if (scenario === 'quoted_safe') {
    lineExpr = '\'k\' + std.toString(i) + \': "alpha-beta-\' + std.toString(i) + \'"\'';
  } else if (scenario === 'quoted_escaped') {
    lineExpr = '\'k\' + std.toString(i) + \': "line\\\\\\\\nvalue"\'';
  } else if (scenario === 'quoted_implicit') {
    lineExpr = '\'k\' + std.toString(i) + \': "123"\'';
  } else {
    throw new Error(`unknown scenario: ${scenario}`);
  }

  return `
local stdEx = import 'src/stdEx.libsonnet';
local n = ${lineCount};
local lines = [${lineExpr} for i in std.range(0, n - 1)];
local out = stdEx._yamlUnquoteSafeStrings(lines);
{
  len: std.length(out),
  first: out[0],
  last: out[n - 1],
}
`;
};

const runScenario = (scenario, lineCount, iterations) => {
  const expr = jsonnetExprForScenario(scenario, lineCount);
  const durations = [];
  let parsed = null;
  for (let i = 0; i < iterations; i += 1) {
    const started = performance.now();
    const raw = execFileSync('jsonnet', ['-e', expr], { cwd: repoRoot, encoding: 'utf8' });
    durations.push(performance.now() - started);
    parsed = JSON.parse(raw);
  }
  return {
    result: parsed,
    medianMs: median(durations),
    durations,
  };
};

describe('stdEx yamlUnquoteSafeStrings perf profile', () => {
  it('reports scenario timing comparison (informational)', function testYamlUnquotePerfProfile() {
    this.timeout(120000);

    const scenarios = ['plain_unquoted', 'quoted_safe', 'quoted_escaped', 'quoted_implicit'];
    const runs = {};
    for (const scenario of scenarios) {
      runs[scenario] = runScenario(scenario, scenarioLineCount, scenarioIterations);
      assert.strictEqual(runs[scenario].result.len, scenarioLineCount, `${scenario} output length mismatch`);
    }

    const base = runs.plain_unquoted.medianMs;
    const lines = scenarios.map((scenario) => {
      const current = runs[scenario].medianMs;
      const delta = current - base;
      const pct = base === 0 ? 0 : (delta / base) * 100;
      return `${scenario}: ${current.toFixed(1)}ms (${delta >= 0 ? '+' : ''}${delta.toFixed(1)}ms, ${delta >= 0 ? '+' : ''}${pct.toFixed(1)}%)`;
    });

    console.log(
      `yamlUnquoteSafeStrings profile (${scenarioIterations} run median, ${scenarioLineCount} lines):\n  ${lines.join('\n  ')}`
    );
  });
});
