jsonnet-utils
=============

Small collection of reusable Jsonnet helpers and utilities. It includes a tiny regex engine, helpers for crafting VS Code configurations, utilities to generate package.json with a preferred key order, and a few standard-library extensions.

Features
--------
- Regex: minimal matcher/validator supporting `^`, `$`, `?`, `*`, `.`, character classes, and negative lookahead for literals.
- VS Code: concise builders for launch configs and tasks.
- Package: declarative `package.json` modeling with stable key ordering.
- Std extensions: extra helpers (string casing, indexOf, manifest utilities).

Project Layout
--------------
- `src/regex.libsonnet`: minimal regex engine and validator.
- `src/stdEx.libsonnet`: stdlib extensions and manifest helpers.
- `src/packageDefinitions.libsonnet`: package.json DSL and manifest generator.
- `src/vscode.libsonnet`: VS Code launch/task helpers.
- `src/vscode-extensionDefinitions.libsonnet`: extension manifest building blocks.
- `src/vscode-iconDefinitions.libsonnet`: icon helpers (minimal CodIcons map; extend as needed).
- `tests/`: Jsonnet-based test suites (`*_test.jsonnet`).

Requirements
------------
- Jsonnet CLI installed
  - macOS: `brew install jsonnet`
  - Ubuntu/Debian: `sudo apt-get update && sudo apt-get install -y jsonnet`

Running Tests
-------------
- Preferred: `npm test`
- Direct: run a specific suite, e.g. `jsonnet tests/regex_test.jsonnet`

CI runs `npm test` via GitHub Actions: `.github/workflows/jsonnet-tests.yml`.

Usage Examples
--------------
- Import std extensions:

  local stdEx = import 'src/stdEx.libsonnet';
  stdEx.camelCase('hello-world_test')  // => "helloWorldTest"

- Generate ordered package.json:

  local pkg = import 'src/packageDefinitions.libsonnet';
  pkg.manifestPackageJson({ name: 'example', version: '1.0.0', engines: { node: '>=18' } })

- Regex matching:

  local re = import 'src/regex.libsonnet';
  re.match('^ab*c$', 'abbbc')  // => true
  re.validate('a+')             // => { ok: false, err: "Unsupported metacharacter '+'" }

Notes
-----
- Imports in this repo assume paths relative to the repo root (e.g., `src/...`). When embedding into other projects, adjust import paths or set `-J` (Jsonnet library paths) accordingly.
