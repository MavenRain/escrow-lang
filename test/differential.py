#!/usr/bin/env python3
"""Compare the escrowc checker with the contract that escrowc writes.

The checker side is `escrowc verdicts PROG F`: one digit per ballot vector,
in the order of itertools.product over the codes 1, 2 and 3, with the first
ballot outermost. The contract side deploys the creation code of `escrowc
build` in geth evm, then runs `amend`, and `cast` and `settle` on each
ballot vector. Each `cast` and `settle` result must equal the checker digit,
and `amend` must return the packed `escrowc table` codes. No verdict comes
from Python. Storage effects, including O4 claim closing and the O7 credit
legs, are checked against a Python model, not source `settle` evaluation
(SPEC section 1).
Run `make` first.

usage: python3 test/differential.py [--program PROG]
"""
import argparse
import itertools
from pathlib import Path
import re
import shutil
import subprocess
import sys

import settlement as S

ROOT = Path(__file__).resolve().parent.parent
ESCROWC = ROOT / 'build/escrowc'
WORK = ROOT / '.gatework/differential'
PROGRAM = ROOT / 'examples/programs/arrow-debreu.esc'
CODES = (1, 2, 3)
PAYER, PAYEE, AMOUNT = 17, 34, 5


def escrowc(*args, lines=1):
    result = subprocess.run([str(ESCROWC), *map(str, args)], text=True,
                            capture_output=True, timeout=120)
    S.require(result.returncode == 0 and result.stderr == '',
              f'escrowc {args[0]}: exit {result.returncode}: {result.stderr.strip()[:400]}')
    S.require(result.stdout.count('\n') == lines and result.stdout.endswith('\n' * lines),
              f'escrowc {args[0]}: not {lines} line(s) on stdout')
    return result.stdout.strip()


def members(program):
    first = program.read_text().splitlines()[0]
    found = re.fullmatch(r'def members : Nat := ([0-9]+)', first)
    S.require(found is not None, f'line 1 of {program} must be def members : Nat := N')
    return int(found.group(1))


def table(program, size):
    words = escrowc('table', program).split()
    S.require(words[:2] == ['debreu', str(size)], f'table is not debreu {size}: {words[:2]}')
    codes = tuple(map(int, words[2:]))
    S.require(len(codes) == (size + 1) * (size + 2) // 2 and set(codes) <= set(CODES),
              f'table has {len(codes)} codes, not one code in 1..3 per tally')
    return codes


def checker_verdicts(program, vectors):
    digits = escrowc('verdicts', program, 'F')
    S.require(len(digits) == len(vectors) and set(digits) <= set('123'),
              f'verdicts gave {len(digits)} digits for {len(vectors)} vectors')
    return dict(zip(vectors, map(int, digits)))


def contract(program):
    def part(name, *flags):
        out = WORK / f'{name}.hex'
        escrowc('build', program, *flags, '-o', out, lines=0)
        return out.read_text().strip()

    creation, runtime = part('creation'), part('runtime', '--runtime')
    S.deploy('differential-deploy', creation, runtime)
    return runtime


def claim():
    return {S.COUNT: 1, S.slot(S.PAYER, 0): PAYER, S.slot(S.PAYEE, 0): PAYEE,
            S.slot(S.AMOUNT, 0): AMOUNT, S.slot(S.LEDGER, PAYER): 20,
            S.slot(S.LEDGER, PAYEE): 10}


def settled(code):
    # Design section 3: release and refund debit the payer, hold keeps the amount.
    # SPEC O7: release credits the payee, refund credits the payer.
    # SPEC O4: release and refund close the claim, hold leaves it open.
    before = claim()
    debit = AMOUNT if code in (1, 2) else 0
    closed = 1 if code in (1, 2) else 0
    return {**before, S.slot(S.LEDGER, PAYER): before[S.slot(S.LEDGER, PAYER)] - debit,
            S.slot(S.CREDIT, PAYEE): AMOUNT if code == 1 else 0,
            S.slot(S.CREDIT, PAYER): AMOUNT if code == 2 else 0,
            S.slot(S.CLOSED, 0): closed}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--program', type=Path, default=PROGRAM)
    program = parser.parse_args().program.resolve()
    S.require(shutil.which('evm') and shutil.which('cast'), 'evm and cast are required')
    S.require(ESCROWC.exists(), f'{ESCROWC} is missing: run make')
    WORK.mkdir(parents=True, exist_ok=True)
    S.WORK = WORK
    size = members(program)
    vectors = tuple(itertools.product(CODES, repeat=size))
    codes = table(program, size)
    verdicts = checker_verdicts(program, vectors)
    runtime = contract(program)
    packed = sum(code * 4**index for index, code in enumerate(codes))
    S.expect('differential-amend', runtime, S.data('amend'), {}, {}, packed)
    for index, (vector, code) in enumerate(verdicts.items()):
        S.expect(f'differential-cast-{index}', runtime, S.data('cast', *vector), {}, {}, code)
        S.expect(f'differential-settle-{index}', runtime, S.data('settle', 0, *vector),
                 claim(), settled(code), code)
    print(f'DIFFERENTIAL vectors={len(vectors)} '
          f'codes={"".join(map(str, verdicts.values()))} '
          f'amend,verdicts geth=escrowc storage=python-model OK '
          f'(logs: {WORK})')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'DIFFERENTIAL FAIL: {error}', file=sys.stderr)
        sys.exit(1)
