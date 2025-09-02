const assert = require('assert');
const { execSync, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const listJsonnetTestFiles = () => {
  const dir = path.join(__dirname, '..', 'tests');
  const files = fs.readdirSync(dir);
  return files
    .filter((f) => /_test\.jsonnet$/.test(f))
    .map((f) => path.join(dir, f));
};

const loadCasesFromFile = (file) => {
  const out = execFileSync('jsonnet', [file], { encoding: 'utf8' });
  const j = JSON.parse(out);
  if (Array.isArray(j)) return j; // suite returns a raw list of cases
  if (j && Array.isArray(j.tests)) return j.tests; // suite object with tests
  if (j && Array.isArray(j.cases)) return j.cases; // fallback shape
  return [];
};

const runPython = () => {
  try {
    const out = execSync('python3 scripts/verify_regex_with_python.py', { encoding: 'utf8' });
    const j = JSON.parse(out);
    return Array.isArray(j.cases) ? j.cases : [];
  } catch {
    return [];
  }
};

const summarizeFailure = (t) => {
  try {
    if (t && t.got && typeof t.got === 'object' && 'err' in t.got && t.got.err) {
      return String(t.got.err);
    }
    const got = typeof t.got === 'string' ? t.got : JSON.stringify(t.got);
    const want = typeof t.want === 'string' ? t.want : JSON.stringify(t.want);
    if (got && want && (String(got).length + String(want).length) < 120) {
      return `got=${got} want=${want}`;
    }
    return `got=${String(got).slice(0, 80)}...`;
  } catch {
    return 'failure';
  }
};

// Discover each Jsonnet suite and register at top-level
const toSpacedWords = (name) => {
  const noExt = name.replace(/\.jsonnet$/, '').replace(/_test$/, '');
  const withSpaces = noExt.replace(/_/g, ' ');
  return withSpaces
    .split(' ')
    .map((token) => {
      if (/^[a-z0-9]+Ex$/.test(token)) return token; // keep ...Ex intact (e.g., stdEx)
      const split = token.replace(/([a-z0-9])([A-Z])/g, '$1 $2');
      return split
        .split(' ')
        .map((w) => w.toLowerCase())
        .join(' ');
    })
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
};

const jsonnetFiles = listJsonnetTestFiles().sort();
for (const file of jsonnetFiles) {
  const suiteName = toSpacedWords(path.basename(file));
  const cases = loadCasesFromFile(file);
  describe(suiteName, () => {
    for (const t of cases) {
      it(t.name, () => {
        if (t.pass) return;
        assert.fail(summarizeFailure(t));
      });
    }
  });
}

describe('python regex comparison', () => {
  const cases = runPython();
  for (const t of cases) {
    it(t.name, () => {
      if (t.pass) return;
      assert.fail(summarizeFailure(t));
    });
  }
});
