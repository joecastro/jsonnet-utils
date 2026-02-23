const assert = require('assert');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { performance } = require('perf_hooks');

const renderJsonnet = (fixturePath) => {
  const started = performance.now();
  const raw = execFileSync('jsonnet', [fixturePath], { encoding: 'utf8' });
  let output = raw;
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed === 'string') output = parsed;
  } catch {
    output = raw;
  }
  const elapsedMs = performance.now() - started;
  return { output, elapsedMs };
};

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
};

const measureRender = (fixturePath, iterations = 1) => {
  const durations = [];
  let output = '';
  for (let i = 0; i < iterations; i += 1) {
    const run = renderJsonnet(fixturePath);
    output = run.output;
    durations.push(run.elapsedMs);
  }
  return {
    output,
    medianMs: median(durations),
    durations,
  };
};

const includesAny = (text, candidates) => candidates.some((candidate) => text.includes(candidate));
const profileCompareIterations = Number(process.env.PROFILE_COMPARE_ITERATIONS || 3);

const renderFixtureWithProfile = (fixturePath, profile = 'fast') => {
  if (profile === 'fast') return fixturePath;

  const source = fs.readFileSync(fixturePath, 'utf8');
  const rewritten = source.replace(/gha\.manifestYamlFast\(/g, 'gha.manifestYamlPretty(');
  const tmpFixture = fixturePath.replace(/\.jsonnet$/, '.tmp_pretty_profile_bench.jsonnet');
  fs.writeFileSync(tmpFixture, rewritten, 'utf8');
  return tmpFixture;
};

describe('github automation performance', () => {
  const publishFixture = path.join(__dirname, 'assets/github_automation_perf_workflow_fixture.jsonnet');
  const applyFixture = path.join(__dirname, 'assets/github_automation_perf_apply_fixture.jsonnet');
  const compositeFixture = path.join(__dirname, 'assets/github_automation_perf_composite_action_fixture.jsonnet');
  const publishBudgetMs = Number(process.env.PERF_BUDGET_PUBLISH_MS || 45000);
  const applyBudgetMs = Number(process.env.PERF_BUDGET_APPLY_MS || 20000);
  const compositeBudgetMs = Number(process.env.PERF_BUDGET_COMPOSITE_MS || 25000);

  it('renders representative publish workflow under budget', function testPublishPerf() {
    this.timeout(60000);
    const run = measureRender(publishFixture);
    assert.ok(includesAny(run.output, ['name: Publish Platform (staging)', 'name: "Publish Platform (staging)"']), 'expected publish workflow output');
    assert.ok(run.output.includes('publish-service-service-0:'), 'expected service jobs in output');
    assert.ok(run.medianMs <= publishBudgetMs, `median render ${run.medianMs.toFixed(1)}ms exceeded ${publishBudgetMs}ms (${run.durations.map((d) => d.toFixed(1)).join(', ')})`);
  });

  it('renders representative apply workflow under budget', function testApplyPerf() {
    this.timeout(60000);
    const run = measureRender(applyFixture);
    assert.ok(includesAny(run.output, ['name: Apply Infrastructure', 'name: "Apply Infrastructure"']), 'expected apply workflow output');
    assert.ok(run.output.includes('concurrency:'), 'expected concurrency block in output');
    assert.ok(run.medianMs <= applyBudgetMs, `median render ${run.medianMs.toFixed(1)}ms exceeded ${applyBudgetMs}ms (${run.durations.map((d) => d.toFixed(1)).join(', ')})`);
  });

  it('renders representative composite action under budget', function testCompositePerf() {
    this.timeout(60000);
    const run = measureRender(compositeFixture);
    assert.ok(includesAny(run.output, ['name: Apply Infrastructure', 'name: "Apply Infrastructure"']), 'expected composite action output');
    assert.ok(run.output.includes('runs:'), 'expected runs block in output');
    assert.ok(includesAny(run.output, ['using: composite', 'using: "composite"']), 'expected composite action type in output');
    assert.ok(run.medianMs <= compositeBudgetMs, `median render ${run.medianMs.toFixed(1)}ms exceeded ${compositeBudgetMs}ms (${run.durations.map((d) => d.toFixed(1)).join(', ')})`);
  });

  it('reports fast vs pretty profile timing comparison (informational)', function testProfileComparison() {
    this.timeout(120000);

    const fixtures = [
      ['workflow', publishFixture],
      ['apply', applyFixture],
      ['composite', compositeFixture],
    ];

    const reportLines = [];

    for (const [name, baseFixture] of fixtures) {
      const fastFixture = renderFixtureWithProfile(baseFixture, 'fast');
      const prettyFixture = renderFixtureWithProfile(baseFixture, 'pretty');
      try {
        const fastRun = measureRender(fastFixture, profileCompareIterations);
        const prettyRun = measureRender(prettyFixture, profileCompareIterations);
        const deltaMs = prettyRun.medianMs - fastRun.medianMs;
        const deltaPct = fastRun.medianMs === 0 ? 0 : (deltaMs / fastRun.medianMs) * 100;
        reportLines.push(
          `${name}: fast=${fastRun.medianMs.toFixed(1)}ms pretty=${prettyRun.medianMs.toFixed(1)}ms ` +
          `delta=${deltaMs >= 0 ? '+' : ''}${deltaMs.toFixed(1)}ms (${deltaMs >= 0 ? '+' : ''}${deltaPct.toFixed(1)}%)`
        );
        assert.ok(fastRun.output.length > 0 && prettyRun.output.length > 0, `expected ${name} outputs for both profiles`);
      } finally {
        if (prettyFixture !== baseFixture && fs.existsSync(prettyFixture)) fs.unlinkSync(prettyFixture);
      }
    }

    console.log(`profile comparison (${profileCompareIterations} run median):\n  ${reportLines.join('\n  ')}`);
  });
});
