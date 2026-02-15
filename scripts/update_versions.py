#!/usr/bin/env python3
"""Update config/versions.libsonnet with current package and toolchain versions."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

VERSIONS_FILE = Path('config/versions.libsonnet')


RE_DEP = re.compile(
    r"(pkgDef\.Dependency\('(?P<name>[^']+)'\s*,\s*')(?P<version>[^']+)('\s*(?:,\s*true)?\s*\))"
)


def run_command(cmd: list[str]) -> str:
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def latest_npm_version(package_name: str) -> str:
    raw = run_command(['npm', 'view', package_name, 'version', '--json'])
    parsed = json.loads(raw)
    if isinstance(parsed, str):
        return parsed
    if isinstance(parsed, list) and parsed:
        return parsed[-1]
    raise ValueError(f'Unexpected npm version response for {package_name}: {raw}')


def major_version(version: str) -> str:
    match = re.match(r'^(\d+)\.', version)
    if not match:
        raise ValueError(f'Could not parse major version from: {version}')
    return match.group(1)


def replace_scalar(content: str, key: str, value: str) -> str:
    pattern = re.compile(rf"({re.escape(key)}\s*:\s*)'[^']+'")
    return pattern.sub(rf"\1'{value}'", content, count=1)


def update_dependency_versions(content: str) -> tuple[str, list[tuple[str, str, str]]]:
    updates: list[tuple[str, str, str]] = []

    def replacer(match: re.Match[str]) -> str:
        name = match.group('name')
        old = match.group('version')
        new = latest_npm_version(name)
        updates.append((name, old, new))
        return f"{match.group(1)}{new}{match.group(4)}"

    updated = RE_DEP.sub(replacer, content)
    return updated, updates


def main() -> int:
    path = VERSIONS_FILE
    original = path.read_text(encoding='utf-8')
    updated = original

    updated, dep_updates = update_dependency_versions(updated)
    for name, old, new in dep_updates:
        status = 'unchanged' if old == new else 'updated'
        print(f'{name}: {old} -> {new} ({status})')

    node_version = run_command(['node', '-p', 'process.versions.node'])
    npm_version = run_command(['npm', '--version'])
    updated = replace_scalar(updated, 'node', f'>={major_version(node_version)}')
    updated = replace_scalar(updated, 'npm', f'>={major_version(npm_version)}')
    updated = replace_scalar(updated, 'packageManager', f'npm@{npm_version}')
    print(f'node: >= {major_version(node_version)}')
    print(f'npm: >= {major_version(npm_version)}')
    print(f'packageManager: npm@{npm_version}')

    if updated == original:
        print('No changes.')
        return 0

    path.write_text(updated, encoding='utf-8')
    print(f'Updated {path}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
