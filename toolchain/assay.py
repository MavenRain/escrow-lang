#!/usr/bin/env python3
"""Build and run escrow-lang's pinned, locally patched Assay compiler."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CHECKOUT = ROOT / '.tools/assay'
PATCH = ROOT / 'toolchain/assay-surface-branch.patch'
STAMP = ROOT / '.tools/assay-build.json'
REPOSITORY = 'https://github.com/MavenRain/assay.git'


def git(*args):
    return subprocess.check_output(['git', '-C', str(CHECKOUT), *args])


def identity():
    return {'base': (ROOT / 'PIN').read_text().strip(),
            'patch': hashlib.sha256(PATCH.read_bytes()).hexdigest()}


def verify_checkout(wanted):
    if not (CHECKOUT / '.git').is_dir():
        raise ValueError('run python3 toolchain/assay.py setup first')
    if git('rev-parse', 'HEAD').decode().strip() != wanted['base']:
        raise ValueError('local Assay checkout does not match PIN')
    if git('diff', '--binary', '--unified=0', 'HEAD') != PATCH.read_bytes():
        raise ValueError('local Assay changes do not match the recorded patch')
    if git('ls-files', '--others', '--exclude-standard').strip():
        raise ValueError('local Assay checkout has untracked source files')


def setup(args):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=REPOSITORY,
                        help='repository URL or local repository to clone read-only')
    options = parser.parse_args(args)
    wanted = identity()
    if not CHECKOUT.exists():
        CHECKOUT.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--no-hardlinks', '--no-checkout',
                        options.source, str(CHECKOUT)], check=True)
        subprocess.run(['git', '-C', str(CHECKOUT), 'checkout', '--detach',
                        wanted['base']], check=True)
        subprocess.run(['git', '-C', str(CHECKOUT), 'apply', '--index',
                        '--unidiff-zero', '--whitespace=error-all', str(PATCH)],
                       check=True)
    verify_checkout(wanted)
    if not os.environ.get('BEND') and not (CHECKOUT / '.tools/bend/bin/bend').is_file():
        subprocess.run([sys.executable, '-P', 'dev/bootstrap-bend.py'],
                       cwd=CHECKOUT, check=True)
    # Select only the CLI target, not the complete upstream test battery.
    subprocess.run([sys.executable, '-P', 'dev/build.py', 'build', '_build/bin/assay'],
                   cwd=CHECKOUT, check=True)
    STAMP.write_text(json.dumps(wanted, sort_keys=True) + '\n')
    print('escrow-lang Assay toolchain ready')


def main():
    if sys.argv[1:2] == ['setup']:
        setup(sys.argv[2:])
        return
    wanted = identity()
    verify_checkout(wanted)
    if not STAMP.is_file() or json.loads(STAMP.read_text()) != wanted:
        raise ValueError('compiler build is stale; run python3 toolchain/assay.py setup')
    binary = CHECKOUT / '_build/bin/assay'
    os.execv(str(binary), [str(binary), *sys.argv[1:]])


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'escrow-lang toolchain: {error}', file=sys.stderr)
        sys.exit(1)
