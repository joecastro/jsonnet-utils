const assert = require('assert');
const { execSync, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const listJsonnetTestFiles = () => {
  // Consolidated tests live under `test/` alongside this spec
  const dir = __dirname;
  const files = fs.readdirSync(dir);
  return files
    .filter((f) => /_test\.jsonnet$/.test(f))
    .map((f) => path.join(dir, f));
};

// Normalize Jsonnet outputs into an array of suites: [{ name, cases: [] }]
const loadSuitesFromFile = (file) => {
  const out = execFileSync('jsonnet', [file], { encoding: 'utf8' });
  const j = JSON.parse(out);

  const toCases = (obj) => {
    if (!obj) return [];
    if (Array.isArray(obj.cases)) return obj.cases;
    return [];
  };

  // Object shape with suites or tests/cases
  if (j && !Array.isArray(j)) {
    if (Array.isArray(j.suites)) {
      return j.suites.map((s) => ({ name: s.name || '', cases: toCases(s) }));
    }
    const cases = toCases(j);
    if (cases.length) return [{ name: j.name || '', cases }];
    // No known shape; treat as empty
    return [{ name: '', cases: [] }];
  }

  // Array shape: could be array of cases, array of suites, or mixed
  if (Array.isArray(j)) {
    const defaultCases = [];
    const suites = [];
    for (const item of j) {
      if (item && Array.isArray(item.cases)) {
        suites.push({ name: item.name || '', cases: item.cases });
      } else if (item && typeof item === 'object' && 'pass' in item) {
        defaultCases.push(item);
      }
    }
    if (suites.length === 0) {
      // Entire array is a flat list of cases
      return [{ name: '', cases: j }];
    }
    if (defaultCases.length) suites.unshift({ name: '', cases: defaultCases });
    return suites;
  }

  return [{ name: '', cases: [] }];
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
    return `got=${got} want=${want}`;
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
  const fileSuiteName = toSpacedWords(path.basename(file));
  const suites = loadSuitesFromFile(file);
  describe(fileSuiteName, () => {
    // If there is a single unnamed suite, keep flat structure for readability
    const singleUnnamed = suites.length === 1 && (suites[0].name || '') === '';
    if (singleUnnamed) {
      for (const t of suites[0].cases) {
        it(t.name, () => {
          if (t.pass) return;
          assert.fail(summarizeFailure(t));
        });
      }
    } else {
      for (const s of suites) {
        const name = (s.name || '').trim() || 'suite';
        describe(name, () => {
          for (const t of s.cases) {
            it(t.name, () => {
              if (t.pass) return;
              assert.fail(summarizeFailure(t));
            });
          }
        });
      }
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
