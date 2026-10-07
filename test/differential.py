#!/usr/bin/env python3
"""Compare kernel evaluation of the program rule with the emitted contract.

The kernel side evaluates the rule `F` of the Arrow-Debreu example on each
ballot vector. The kernel prints no normal forms, so a wrong `reflNat`
candidate gives the value in its error text (probe P3). That value is only
a hint: one kernel file then checks each value with `reflNat`, and that
check is the certificate. The contract side runs the constructor, then
`cast` and `settle`, in the Assay model and in geth. No expected verdict
comes from Python.

usage: python3 -P test/differential.py [--contract PATH]
"""
import argparse
import functools
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ASSAY = ROOT / '.tools/assay'
WORK = ROOT / '.gatework/differential'
sys.path.insert(0, str(ASSAY / 'dev'))
spec = importlib.util.spec_from_file_location('escrow_context', ASSAY / 'dev/context-test.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
C.WORK = WORK

PROGRAM = ROOT / 'examples/programs/arrow-debreu.asy'
FIXTURE = ROOT / 'examples/contracts/arrow-debreu.asy'
NAMES = {1: 'release', 2: 'refund', 3: 'hold'}
GROUP = 9
LAYOUT = ('ledger', 'claimCount', 'payer', 'payee', 'amount', 'weight', 'verdict')


def members():
    first = PROGRAM.read_text().splitlines()[0]
    found = re.fullmatch(r'def members : Nat := ([0-9]+)', first)
    C.require(found is not None, f'line 1 of {PROGRAM} must be def members : Nat := N')
    return int(found.group(1))


def verdict_term(vector):
    ballots = functools.reduce(lambda rest, code: f'bcons {NAMES[code]} ({rest})',
                               reversed(vector), 'bnil')
    return f'decCode (F (mkConfig ({ballots}) (reflNat {len(vector)})))'


def packed(vectors):
    terms = [verdict_term(vector) for vector in vectors]
    return functools.reduce(lambda rest, term: f'natAdd ({term}) (natMul 4 ({rest}))',
                            reversed(terms[:-1]), terms[-1])


def kernel_file(definitions):
    program = subprocess.run(['zsh', str(ROOT / 'prelude/assemble.sh'), str(PROGRAM)],
                             capture_output=True, text=True, check=True).stdout
    return '\n'.join([program,
                      'def decCode : Decision -> Nat := fun (d : Decision) => decide Nat 1 2 3 d',
                      *definitions, ''])


def kernel_check(label, text):
    path = C.WORK / f'{label}.asy'
    path.write_text(text)
    status = subprocess.run(['zsh', str(ROOT / 'probe/run.sh'), label, 'check', str(path)],
                            env={**os.environ, 'TMPDIR': str(C.WORK)},
                            capture_output=True, text=True).returncode
    log = C.WORK / 'escrow-probe/logs' / f'{label}.err'
    return status, log.read_text() if log.exists() else ''


def hint(index, vectors):
    # Run 1: a wrong candidate. Every code is 1, 2 or 3, so 0 is wrong.
    status, error = kernel_check(f'hint-{index}', kernel_file([
        f'def diffCode : Nat := {packed(vectors)}',
        'def diffOk : EqNat diffCode 0 := reflNat 0']))
    C.require(status != 0, f'hint {index}: the kernel accepted the wrong candidate 0')
    found = re.search(r'the type asks for ([0-9]+)', error)
    C.require(found is not None, f'hint {index}: no value in the kernel error')
    value = int(found.group(1))
    codes = [value // 4 ** place % 4 for place in range(len(vectors))]
    C.require(value < 4 ** len(vectors) and all(code in NAMES for code in codes),
              f'hint {index}: value {value} is not {len(vectors)} codes in 1..3')
    return codes


def kernel_verdicts(vectors):
    groups = [vectors[start:start + GROUP] for start in range(0, len(vectors), GROUP)]
    codes = [code for index, group in enumerate(groups) for code in hint(index, group)]
    status, error = kernel_check('certificate', kernel_file([
        f'def diffOk{index} : EqNat ({verdict_term(vector)}) {code} := reflNat {code}'
        for index, (vector, code) in enumerate(zip(vectors, codes))]))
    C.require(status == 0, f'the certificate file was refused: {error.strip()[:400]}')
    return dict(zip(vectors, codes))


@functools.cache
def slot(base, key):
    # Independent keccak oracle, not Assay's mapping-slot implementation.
    digest = C.checked(f'slot-{base}-{key}',
                       ['cast', 'keccak', f'0x{key:064x}{base:064x}']).strip()
    return int(digest, 16)


def data(name, *values):
    signature = name + '(' + ','.join(['uint256'] * len(values)) + ')'
    selector = C.checked('selector-' + name, ['cast', 'sig', signature]).strip()[2:]
    return selector + ''.join(f'{value:064x}' for value in values)


def results(name, path, runtime, calldata, before):
    arguments = [C.BINARY, 'run', str(path), '--calldata', calldata,
                 *[part for key, value in before.items() for part in ('--storage', f'{key}={value}')]]
    model = json.loads(C.checked('model-' + name, arguments, timeout=90))
    actual, _ = C.evm_run(name, runtime, calldata, C.SENDER,
                          slots={hex(key): hex(value) for key, value in before.items() if value})
    return model, actual


def contract_verdicts(source, vectors):
    path, output, runtime = C.emit('differential', source.read_text())
    layout = json.loads((output / 'layout.json').read_text())
    C.require([(row['label'], int(row['slot'])) for row in layout['storage']] ==
              list(zip(LAYOUT, range(len(LAYOUT)))), 'unexpected storage layout')
    created, raw = C.evm_run('constructor', (output / 'init.hex').read_text().strip(),
                             '', C.SENDER, create=True)
    deployed = [words for words in raw['storage'].values() if words]
    C.require(created['status'] == 'success' and len(deployed) == 1,
              f'constructor failed or wrote {len(deployed)} accounts')
    # The tables come from the constructor run, not from the codes.
    tables = {int(key, 0): int(value, 0) for key, value in deployed[0].items()}
    claim = {**tables, 1: 1, slot(2, 0): 17, slot(3, 0): 34, slot(4, 0): 5,
             slot(0, 17): 20, slot(0, 34): 10}

    def verdict(label, calldata, before):
        model, actual = results(label, path, runtime, calldata, before)
        return {'model': model, 'evm': actual}

    return {vector: {'cast': verdict(f'cast-{index}', data('cast', *vector), tables),
                     'settle': verdict(f'settle-{index}', data('settle', 0, *vector), claim)}
            for index, vector in enumerate(vectors)}


def mismatches(kernel, contract):
    return [(vector, entry, engine, run['status'], int(run['output'], 16), code)
            for vector, code in kernel.items()
            for entry, engines in contract[vector].items()
            for engine, run in engines.items()
            if (run['status'], run['output']) != ('success', f'0x{code:064x}')]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--contract', type=Path, default=FIXTURE)
    source = parser.parse_args().contract.resolve()
    C.require(shutil.which('evm') and shutil.which('cast'), 'evm and cast are required')
    WORK.mkdir(parents=True, exist_ok=True)
    C.WORK = Path(tempfile.mkdtemp(prefix='run-', dir=WORK))
    # Verify the dependency before using its test helpers and binary.
    subprocess.run([sys.executable, '-P', str(ROOT / 'toolchain/assay.py'),
                    'check', str(source)], check=True)
    vectors = tuple(itertools.product(tuple(NAMES), repeat=members()))
    kernel = kernel_verdicts(vectors)
    contract = contract_verdicts(source, vectors)
    wrong = mismatches(kernel, contract)
    C.require(not wrong, f'{len(wrong)} kernel and contract differences, first: {wrong[:2]}')
    print(f'DIFFERENTIAL vectors={len(vectors)} kernel=certified '
          f'codes={"".join(map(str, kernel.values()))} cast,settle model=geth=kernel OK '
          f'(logs: {C.WORK})')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'DIFFERENTIAL FAIL: {error}', file=sys.stderr)
        sys.exit(1)
