const assert = require('assert');
const { execFileSync } = require('child_process');
const path = require('path');
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
});
