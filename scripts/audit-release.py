#!/usr/bin/env python3
"""Check the exact Git payload and optional release binary before publication."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
ROOT_FILES = {'.gitignore', '.gitattributes', 'Package.swift', 'VERSION', 'LICENSE',
              'README.md', 'README.ru.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md'}
PREFIXES = ('Sources/', 'Tests/', 'scripts/', '.github/', 'docs/')
PATTERNS = {
    'private home path': rb'/(?:Users|home)/[^/\s\"\']+/',
    'OpenAI secret': rb'\bsk-[A-Za-z0-9_-]{24,}',
    'GitHub secret': rb'\b(?:gh[pousr]_[A-Za-z0-9]{24,}|github_pat_[A-Za-z0-9_]{30,})',
    'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'JWT': rb'\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}',
}

def scan(data, label):
    issues = []
    for name, pattern in PATTERNS.items():
        if re.search(pattern, data): issues.append(f'{label}: {name}')
    return issues

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--staged', action='store_true', help='Check index bytes instead of working files')
    parser.add_argument('--binary', type=Path)
    args = parser.parse_args()
    if args.binary:
        issues = scan(args.binary.read_bytes(), 'release executable')
        total = 1
    else:
        top = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip()
        if Path(top).resolve() != ROOT:
            sys.exit('Initialize a dedicated Git repository in ChatGPTLimits before auditing.')
        names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
        names = [name for name in names if name]
        if not names: sys.exit('No tracked files to audit.')
        issues = []
        for name in names:
            path = Path(name)
            if name not in ROOT_FILES and not name.startswith(PREFIXES):
                issues.append(f'{name}: outside publication allowlist')
                continue
            if any(part in {'.env', '.codex', '.build', 'dist', '.git', '__pycache__'} or part.endswith(('.app', '.dSYM')) for part in path.parts):
                issues.append(f'{name}: private/generated path')
            if (ROOT / path).is_symlink(): issues.append(f'{name}: symlink is not allowed')
            data = subprocess.check_output(['git', 'show', f':{name}'], cwd=ROOT) if args.staged else (ROOT / path).read_bytes()
            if path.suffix == '.png' and name.startswith('docs/images/'):
                if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) > 1_000_000:
                    issues.append(f'{name}: unexpected image payload')
            else:
                try: data.decode('utf-8')
                except UnicodeDecodeError: issues.append(f'{name}: unexpected binary file')
                issues.extend(scan(data, name))
        total = len(names)
    if issues:
        print('\n'.join(issues), file=sys.stderr)
        return 1
    print(f'Publication audit passed: {total} file(s). No known secret patterns or private home paths.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
