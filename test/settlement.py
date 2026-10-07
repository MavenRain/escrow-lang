#!/usr/bin/env python3
"""Compare generated settlement in Assay and geth with independent balances."""
import functools
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ASSAY = ROOT / '.tools/assay'
WORK = ROOT / '.gatework/settlement'
sys.path.insert(0, str(ASSAY / 'dev'))
spec = importlib.util.spec_from_file_location('escrow_context', ASSAY / 'dev/context-test.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
C.WORK = WORK


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


def storage(words):
    return {str(key): hex(value) for key, value in words.items() if value}


def outcome(name, path, runtime, calldata, before, after, result=None):
    arguments = [C.BINARY, 'run', path, '--calldata', calldata]
    for key, value in before.items():
        arguments += ['--storage', f'{key}={value}']
    model = json.loads(C.checked('model-' + name, arguments, timeout=90))
    actual, _ = C.evm_run(name, runtime, calldata, C.SENDER,
                          slots={hex(k): hex(v) for k, v in before.items() if v})
    wanted = dict(status='revert' if result is None else 'success',
                  output='0x' if result is None else f'0x{result:064x}',
                  storage=storage(after))
    C.require(model == wanted, f'{name}: model {model} != {wanted}')
    C.require(actual == wanted, f'{name}: EVM {actual} != {wanted}')


def main():
    C.require(shutil.which('evm') and shutil.which('cast'), 'evm and cast are required')
    WORK.mkdir(parents=True, exist_ok=True)
    C.WORK = Path(tempfile.mkdtemp(prefix='run-', dir=WORK))
    source = ROOT / 'examples/contracts/arrow-debreu.asy'
    # Verify the dependency before using its test helpers and binary.
    subprocess.run([sys.executable, '-P', str(ROOT / 'toolchain/assay.py'),
                    'check', str(source)], check=True)
    path, output, runtime = C.emit('escrow', source.read_text())
    abi = json.loads((output / 'abi.json').read_text())
    names = {row['name'] for row in abi if row['type'] == 'function'}
    C.require(names == {'deposit', 'cast', 'settle', 'amend'}, f'unexpected ABI: {names}')
    layout = json.loads((output / 'layout.json').read_text())
    C.require([(row['label'], int(row['slot'])) for row in layout['storage']] ==
              list(zip(('ledger', 'claimCount', 'payer', 'payee', 'amount', 'weight', 'verdict'), range(7))),
              'unexpected storage layout')
    codes = (3, 3, 2, 2, 3, 3, 2, 1, 1, 1)
    initial = {slot(5, 1): 1, slot(5, 2): 4}
    index = 0
    for release in range(4):
        for refund in range(4 - release):
            initial[slot(6, release + 4 * refund)] = codes[index]
            index += 1
    created, raw = C.evm_run('constructor', (output / 'init.hex').read_text().strip(),
                             '', C.SENDER, create=True)
    # CREATE stores at the newly derived address, not the call receiver.
    deployed = [words for words in raw['storage'].values() if words]
    C.require(created['status'] == 'success' and deployed == [storage(initial)],
              f'constructor tables differ: {deployed}')
    C.require(created['output'].removeprefix('0x') == runtime.removeprefix('0x'),
              'constructor returned different runtime bytecode')
    cases = 0
    for decision, ballots in ((1, (1, 1, 3)), (2, (2, 2, 3)), (3, (3, 3, 3))):
        outcome(f'cast-{decision}', path, runtime, data('cast', *ballots),
                initial, initial, decision)
        cases += 1
        for same in (False, True):
            payer, payee = 17, 17 if same else 34
            for balance in (4, 20):
                before = {**initial, 1: 1, slot(2, 0): payer, slot(3, 0): payee,
                          slot(4, 0): 5, slot(0, payee): 10, slot(0, payer): balance}
                after = dict(before)
                result = None
                if balance >= 5:
                    result = decision
                    if decision in (1, 2):
                        after[slot(0, payer)] -= 5
                    if decision == 1:
                        after[slot(0, payee)] += 5
                outcome(f'settle-{decision}-{same}-{balance}', path, runtime,
                        data('settle', 0, *ballots), before, after, result)
                cases += 1
    before = {**initial, 1: 1, slot(2, 0): 17, slot(3, 0): 34, slot(4, 0): 5,
              slot(0, 17): 20, slot(0, 34): 2**256 - 1}
    outcome('release-overflow', path, runtime, data('settle', 0, 1, 1, 3), before, before)
    for ballot in (0, 4):
        outcome(f'bad-ballot-{ballot}', path, runtime, data('settle', 0, ballot, 1, 3), before, before)
    print(f'SETTLEMENT cases={cases + 3} constructor=1 ABI=1 model=geth=expected OK (logs: {C.WORK})')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'SETTLEMENT FAIL: {error}', file=sys.stderr)
        sys.exit(1)
