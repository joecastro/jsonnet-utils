#!/usr/bin/env python3
"""Render repository config files from Jsonnet templates in config/."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

RENDER_TARGETS: dict[str, str] = {
    'config/github/workflows/jsonnet-tests.jsonnet': '.github/workflows/jsonnet-tests.yml',
    'config/vscode/extensions.jsonnet': '.vscode/extensions.json',
    'config/vscode/launch.jsonnet': '.vscode/launch.json',
    'config/vscode/settings.jsonnet': '.vscode/settings.json',
    'config/vscode/tasks.jsonnet': '.vscode/tasks.json',
    'config/package.jsonnet': 'package.json',
}

SETTINGS_CHECK_IGNORE_KEYS = {
    '.vscode/settings.json': {'workbench.colorCustomizations'},
}


def render_jsonnet(source: Path) -> str:
    result = subprocess.run(
        ['jsonnet', '-S', str(REPO_ROOT / source)],
        check=True,
        capture_output=True,
        text=True,
    )
    content = result.stdout
    if not content.endswith('\n'):
        content += '\n'
    return content


def write_if_changed(path: Path, content: str) -> bool:
    if path.exists() and path.read_text(encoding='utf-8') == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')
    return True


def normalized_for_check(destination: str, content: str) -> str:
    ignore_keys = SETTINGS_CHECK_IGNORE_KEYS.get(destination)
    if not ignore_keys:
        return content

    try:
        parsed = json.loads(content) if content.strip() else {}
    except json.JSONDecodeError:
        # Keep original behavior: invalid JSON should still fail the check.
        return content

    if not isinstance(parsed, dict):
        return content

    normalized = {k: v for k, v in parsed.items() if k not in ignore_keys}
    return json.dumps(normalized, sort_keys=True, separators=(',', ':'))


def main() -> int:
    parser = argparse.ArgumentParser(description='Bootstrap repo configuration from Jsonnet templates')
    parser.add_argument('--check', action='store_true', help='Validate generated files are up-to-date without modifying files')
    args = parser.parse_args()

    changed: list[str] = []

    for source, destination in RENDER_TARGETS.items():
        rendered = render_jsonnet(Path(source))
        destination_path = REPO_ROOT / destination

        if args.check:
            current = destination_path.read_text(encoding='utf-8') if destination_path.exists() else ''
            if normalized_for_check(destination, current) != normalized_for_check(destination, rendered):
                changed.append(destination)
            continue

        if write_if_changed(destination_path, rendered):
            changed.append(destination)

    if args.check:
        if changed:
            print('Out-of-date generated files:')
            for file in changed:
                print(f'  - {file}')
            return 1
        print('All generated files are up-to-date.')
        return 0

    if changed:
        print('Updated generated files:')
        for file in changed:
            print(f'  - {file}')
    else:
        print('No changes; generated files already up-to-date.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr)
        raise
