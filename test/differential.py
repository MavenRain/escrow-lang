#!/usr/bin/env python3
"""Compare the escrowc checker with the contract that escrowc writes.

The checker side is `escrowc verdicts PROG F`: one digit per ballot vector,
in the order of itertools.product over the codes 1, 2 and 3, with the first
ballot outermost. The contract side deploys the creation code of `escrowc
build` in geth evm, then runs `amend`, and `cast` and `settle` on each
ballot vector, after its members submit that vector through `vote`.
Each `cast` and `settle` result must equal the checker digit,
and `amend` must return the packed `escrowc table` codes. No verdict comes
from Python. The storage side is source `settle`: for each ballot vector,
the script writes a temp program, which is PROG, the vector `Config` and
`settle` of claim 0 from the `claim()` prestate. `escrowc eval` gives both
ledger balances and credits, the claim count and fields, `closed` at 0
and the open count. The geth storage after `settle` must equal this
source state, and the Python model `settled()` must agree with both. PROG
must declare `F` and `agg`.
Run `make` first.

usage: python3 test/differential.py [--program PROG]
"""
import argparse
import itertools
import math
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
# M6 chunk 3 (R15): the runtime of 2 member classes, cast code = escrowc table code.
TWO_CLASSES = ROOT / 'test/fixtures/two-classes.esc'
CODES = (1, 2, 3)
DECISIONS = {1: 'release', 2: 'refund', 3: 'hold'}
PAYER, PAYEE, AMOUNT = 17, 34, 5
SOURCE = ('diffLedgerPayer', 'diffLedgerPayee', 'diffCreditPayee', 'diffCreditPayer',
          'diffClaimCount', 'diffClaimPayer', 'diffClaimPayee', 'diffClaimAmount',
          'diffClosed', 'diffOpen')


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


def member_classes(program, size):
    # The class sizes of memberClasses (M6), one class of size without the def.
    classes = tuple(map(int, re.findall(r'[0-9]+', escrowc('eval', program, 'memberClasses'))))
    S.require(sum(classes) == size and 0 not in classes, f'memberClasses {classes} do not sum to {size}')
    return classes


def table(program, size, classes):
    words = escrowc('table', program).split()
    S.require(words[:2] == ['debreu', str(size)], f'table is not debreu {size}: {words[:2]}')
    codes = tuple(map(int, words[2:]))
    rows = math.prod((k + 1) * (k + 2) // 2 for k in classes)
    S.require(len(codes) == rows and set(codes) <= set(CODES),
              f'table has {len(codes)} codes, not one code in 1..3 per row of {rows}')
    return codes


def member_addresses(program, size):
    normal = escrowc('eval', program, 'memberAddresses')
    addresses = tuple(f'{int(word, 16):040x}' for word in re.findall(r'0x[0-9a-fA-F]+', normal))
    S.require(len(addresses) == size, f'memberAddresses has {len(addresses)} addresses, need {size}')
    return addresses


def checker_verdicts(program, vectors):
    digits = escrowc('verdicts', program, 'F')
    S.require(len(digits) == len(vectors) and set(digits) <= set('123'),
              f'verdicts gave {len(digits)} digits for {len(vectors)} vectors')
    return dict(zip(vectors, map(int, digits)))


def contract(program):
    def part(name, *flags):
        out = S.WORK / f'{name}.hex'
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


def source(text, size, vector):
    # PROG, then settle of claim 0 from the claim() prestate at the vector Config.
    before = claim()
    payer, payee = before[S.slot(S.LEDGER, PAYER)], before[S.slot(S.LEDGER, PAYEE)]
    ballots = ''.join(f'(bcons {DECISIONS[code]} ' for code in vector) + 'bnil' + ')' * size
    return text + f'''
-- test/differential.py: settle claim 0 from the claim() prestate.
def diffX : Config := mkConfig {ballots} (reflNat {size})
def diffStart : Escrow := tuple (add (add empty {PAYER} {payer}) {PAYEE} {payee},
  tuple (empty, tuple (pureClaims (tuple ({PAYER}, tuple ({PAYEE}, {AMOUNT}))), allOpen)))
def diffHc : Lt 0 (claimCount (claims diffStart)) := (0, reflNat 1)
def diffHo : EqNat (closed diffStart 0) 0 := reflNat 0
def diffH : Le {AMOUNT} (balance (ledger diffStart) {PAYER}) := ({payer - AMOUNT}, reflNat {payer})
def diffAfter : Escrow := settle F agg diffX 0 diffStart diffHc diffHo diffH
def diffLedgerPayer : Nat := balance (ledger diffAfter) {PAYER}
def diffLedgerPayee : Nat := balance (ledger diffAfter) {PAYEE}
def diffCreditPayee : Nat := balance (credit diffAfter) {PAYEE}
def diffCreditPayer : Nat := balance (credit diffAfter) {PAYER}
def diffClaimCount : Nat := claimCount (claims diffAfter)
def diffClaimPayer : Nat := payer (claimAt (claims diffAfter) 0)
def diffClaimPayee : Nat := payee (claimAt (claims diffAfter) 0)
def diffClaimAmount : Nat := amount (claimAt (claims diffAfter) 0)
def diffClosed : Nat := closed diffAfter 0
def diffOpen : Nat := openCount diffAfter
'''


def source_settled(text, size, index, vector):
    # One escrowc eval per definition, because eval gives one NAME per run.
    path = S.WORK / f'source-{index}.esc'
    path.write_text(source(text, size, vector))
    (ledger_payer, ledger_payee, credit_payee, credit_payer, count,
     claim_payer, claim_payee, amount, closed, opened) = (
        int(escrowc('eval', path, name)) for name in SOURCE)
    # The contract has no open count word: it is the count word minus the closed words.
    S.require(opened == count - closed,
              f'{path}: open count {opened}, count {count}, closed {closed}')
    return {S.COUNT: count, S.slot(S.PAYER, 0): claim_payer,
            S.slot(S.PAYEE, 0): claim_payee, S.slot(S.AMOUNT, 0): amount,
            S.slot(S.LEDGER, PAYER): ledger_payer, S.slot(S.LEDGER, PAYEE): ledger_payee,
            S.slot(S.CREDIT, PAYEE): credit_payee, S.slot(S.CREDIT, PAYER): credit_payer,
            S.slot(S.CLOSED, 0): closed}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--program', type=Path, action='append')
    programs = parser.parse_args().program or [PROGRAM, TWO_CLASSES]
    S.require(shutil.which('evm') and shutil.which('cast'), 'evm and cast are required')
    S.require(ESCROWC.exists(), f'{ESCROWC} is missing: run make')
    for program in programs:
        run(program.resolve())


def run(program):
    work = WORK / program.stem
    work.mkdir(parents=True, exist_ok=True)
    S.WORK = work
    size = members(program)
    addresses = member_addresses(program, size)
    text = program.read_text()
    vectors = tuple(itertools.product(CODES, repeat=size))
    classes = member_classes(program, size)
    codes = table(program, size, classes)
    verdicts = checker_verdicts(program, vectors)
    for index, vector in enumerate(vectors):
        row = S.row_index(classes, vector)
        S.require(verdicts[vector] == codes[row],
                  f'differential-table-{index}: verdict {verdicts[vector]} != table row {row} code {codes[row]}')
    runtime = contract(program)
    packed = sum(code * 4**index for index, code in enumerate(codes))
    S.expect('differential-amend', runtime, S.data('amend'), {}, {}, packed)
    for index, (vector, code) in enumerate(verdicts.items()):
        S.expect(f'differential-cast-{index}', runtime, S.data('cast', *vector), {}, {}, code)
        after = source_settled(text, size, index, vector)
        votes = [(member, S.data('vote', 0, ballot), S.pack(vector[:m + 1]))
                 for m, (member, ballot) in enumerate(zip(addresses, vector))]
        S.chain(f'differential-settle-{index}', runtime,
                votes + [(S.SENDER, S.data('settle', 0), code)],
                claim(), S.voted(after, 0, vector))
        S.require(after == settled(code),
                  f'differential-model-{index}: source {after} != model {settled(code)}')
    print(f'DIFFERENTIAL vectors={len(vectors)} '
          f'codes={"".join(map(str, verdicts.values()))} '
          f'amend,verdicts geth=escrowc storage=escrowc-eval OK '
          f'(logs: {work})')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'DIFFERENTIAL FAIL: {error}', file=sys.stderr)
        sys.exit(1)
