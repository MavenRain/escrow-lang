#!/usr/bin/env python3
"""Run the bytecode of src/evm.c in geth evm against balances computed here.

Needs tcc, geth evm 1.14.12 and foundry cast. Mapping slots come from
`cast index` and selectors from `cast sig`, not from src/keccak.c."""
import functools
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / '.gatework/settlement-tcc'
SENDER = '7e5f4552091a69125d5dfcb7b8c2659029395bdf'
RECEIVER = '0000000000000000000000007265636569766572'
GAS = 16_777_216
CONFIG = {name + 'Block': 0 for name in (
    'homestead', 'eip150', 'eip155', 'eip158', 'byzantium', 'constantinople',
    'petersburg', 'istanbul', 'berlin', 'london', 'mergeNetsplit')}
CONFIG.update(chainId=1, terminalTotalDifficulty=0, cancunTime=0, shanghaiTime=0)
GENESIS = dict(config=CONFIG, coinbase='0x' + '00' * 20, difficulty='0x0', gasLimit='0x1000000',
               nonce='0x0000000000000000', timestamp='0x0', number='0x0',
               excessBlobGas='0x0', blobGasUsed='0x0')
CODES = (3, 3, 2, 2, 3, 3, 2, 1, 1, 1)
LEDGER, COUNT, PAYER, PAYEE, AMOUNT, CREDIT, CLOSED, BALLOTS = range(8)
# M4: the members of the n = 3 build are the addresses of the private keys
# 1, 2 and 3 (SENDER is member 0). The address of key 4 is not a member.
MEMBERS = (SENDER, '2b5ad5c4795c026514f8317c7a215e218dccd6cf',
           '6813eb9362372eef6200f3b1dbc3f819671cba69')
OUTSIDER = '1eff47bc3a10a45d4b230b5d10e37751fe6aa718'
FUNDS = 10**24
REVERTING = '60006000fd'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def tool(*args):
    argv = ['tcc', 'src/evm.c', 'src/keccak.c', '-run', 'test/evmtool.c', *map(str, args)]
    return subprocess.run(argv, cwd=ROOT, text=True, capture_output=True, timeout=60)


def bytecode(*args):
    result = tool(*args)
    require(result.returncode == 0 and result.stderr == '', f'evmtool {args}: {result.stderr}')
    text = result.stdout
    require(text.endswith('\n') and text.count('\n') == 1 and text.strip() == text.strip().lower(),
            f'evmtool {args}: not one line of lowercase hex')
    return text.strip()


def checked(argv):
    result = subprocess.run(argv, text=True, capture_output=True, timeout=60)
    require(result.returncode == 0, f'{argv[:3]}: {result.stderr}')
    return result.stdout


@functools.cache
def slot(base, key):
    return int(checked(['cast', 'index', 'uint256', str(key), str(base)]).strip(), 16)


@functools.cache
def selector(name, words):
    signature = name + '(' + ','.join(['uint256'] * words) + ')'
    return checked(['cast', 'sig', signature]).strip()[2:]


def data(name, *values):
    return selector(name, len(values)) + ''.join(f'{value:064x}' for value in values)


def objects(text):
    decoder, tail, result = json.JSONDecoder(), text.lstrip(), []
    while tail:
        value, end = decoder.raw_decode(tail)
        result.append(value)
        tail = tail[end:].lstrip()
    return result


def words(slots):
    return {int(key, 16): int(value, 16) for key, value in slots.items() if int(value, 16)}


def wei(text):
    return int(text, 16) if str(text).startswith('0x') else int(text)


def run(name, code, calldata, *, before=None, value=0, create=False, balance=0, sender=None,
        caller=SENDER):
    # balance: the prestate wei of the contract; sender: runtime hex code for SENDER;
    # caller: the address that sends the call (M4: a member votes).
    state = dict(GENESIS, alloc={
        SENDER: dict(balance=hex(FUNDS), **({} if sender is None else {'code': '0x' + sender})),
        **({} if caller == SENDER else {caller: dict(balance=hex(FUNDS))}),
        RECEIVER: dict(balance=hex(balance), storage={f'0x{k:064x}': f'0x{v:064x}'
                                                      for k, v in (before or {}).items() if v})})
    genesis = WORK / (name + '-prestate.json')
    genesis.write_text(json.dumps(state))
    argv = ['evm', '--verbosity', '0', 'run', '--prestate', str(genesis), '--gas', str(GAS),
            '--sender', '0x' + caller, '--receiver', '0x' + RECEIVER, '--code', code,
            '--input', calldata, '--value', str(value), '--json', '--dump']
    text = checked(argv + (['--create'] if create else []))
    (WORK / (name + '.out')).write_text(text)
    records = objects(text)
    require(len(records) >= 2 and 'accounts' in records[-1], f'{name}: missing state dump')
    errors = [row['error'] for row in records if row.get('error')]
    require(all(error == 'execution reverted' for error in errors), f'{name}: EVM fault {errors}')
    accounts = {key.lower().removeprefix('0x'): account
                for key, account in records[-1]['accounts'].items()}
    stores = {key: words(account.get('storage', {})) for key, account in accounts.items()}
    # The status is the outermost frame: a reverted inner CALL also logs an error row.
    return dict(status='revert' if records[-2].get('error') else 'success',
                output=records[-2]['output'].lower().removeprefix('0x'),
                storage=stores.get(RECEIVER, {}),
                balances={key: wei(account.get('balance', 0)) for key, account in accounts.items()},
                created={key: value for key, value in stores.items() if value and key != RECEIVER})


def expect(name, code, calldata, before, after, result, *, value=0, balance=0, sender=None,
           balances=None, caller=SENDER):
    actual = run(name, code, calldata, before=before, value=value, balance=balance, sender=sender,
                 caller=caller)
    wanted = dict(status='revert' if result is None else 'success',
                  output='' if result is None else f'{result:064x}',
                  storage={k: v for k, v in after.items() if v})
    got = {key: actual[key] for key in wanted}
    require(got == wanted, f'{name}: EVM {got} != {wanted}')
    paid = {key: actual['balances'].get(key, 0) for key in (balances or {})}
    require(paid == (balances or {}), f'{name}: balances {paid} != {balances}')


def chain(name, code, steps, before, after):
    # M4: each step is (caller, calldata, result). The storage dump of a step
    # is the prestate of the next step; after is the storage at the end.
    storage = before
    for index, (caller, calldata, result) in enumerate(steps):
        actual = run(f'{name}-{index}', code, calldata, before=storage, caller=caller)
        wanted = ('revert', '') if result is None else ('success', f'{result:064x}')
        require((actual['status'], actual['output']) == wanted,
                f'{name} step {index}: EVM {actual["status"]} {actual["output"]} != {wanted}')
        storage = actual['storage']
    require(storage == {k: v for k, v in after.items() if v}, f'{name}: storage {storage} != {after}')


def pack(values):
    # 2 bits for each value, value i at 4^i (amend, and the slot 7 ballots word of M4 R3).
    return sum(value * 4**index for index, value in enumerate(values))


def voted(state, claim, ballots):
    return {**state, slot(BALLOTS, claim): pack(ballots)}


def addresses(members):
    # The member addresses of an n-member Debreu build (evmtool takes them after the codes).
    chosen = (MEMBERS if members == len(MEMBERS) else
              tuple(f'{m + 1:02x}' * 20 for m in range(members)))
    return ['0x' + address for address in chosen]


def tally_index(members, release, refund):
    return sum(members + 1 - r for r in range(release)) + refund


def row_index(classes, ballots):
    # The escrowc table row of ballots (M6): class 1 is the outer digit, and the
    # ballots of a class of k members give the digit tally_index(k, r, f).
    index, start = 0, 0
    for k in classes:
        part = ballots[start:start + k]
        index = index * (k + 1) * (k + 2) // 2 + tally_index(k, part.count(1), part.count(2))
        start += k
    return index


def verdict(members, codes, ballots, classes=None):
    return codes[row_index(classes or (members,), tuple(ballots))]


def deploy(name, creation, runtime):
    made = run(name, creation, '', create=True)
    require(made['status'] == 'success' and made['output'] == runtime,
            f'{name}: creation did not return the runtime')
    require(made['storage'] == {} and made['created'] == {}, f'{name}: creation wrote storage')
    paid = run(name + '-value', creation, '', value=1, create=True)
    require(paid['status'] == 'revert' and paid['output'] == '', f'{name}: creation took a value')


def refusals():
    rows = [(('runtime', 0, 'debreu', 3), 'EVM_LIMIT'),
            (('runtime', 15, 'debreu', *([1] * 136)), 'EVM_LIMIT'),
            (('runtime', 0, 'impossibility'), 'EVM_LIMIT'),
            (('runtime', 3, 'debreu', *CODES[:-1]), 'EVM_TABLE'),
            (('runtime', 3, 'debreu', *CODES[:-1], 4), 'EVM_TABLE'),
            (('creation', 3, 'debreu', 0, *CODES[1:]), 'EVM_TABLE'),
            (('runtime', 3, 'impossibility', 1), 'EVM_TABLE'),
            (('runtime', 3, 'debreu', *CODES), 'EVM_ADDRESSES'),
            (('creation', 3, 'debreu', *CODES, *(['0x' + SENDER] * 3)), 'EVM_ADDRESSES'),
            (('runtime', 3, 'debreu', *CODES, '0x1' + '00' * 20,
              *addresses(3)[1:]), 'EVM_ADDRESSES')]
    for args, code in rows:
        result = tool(*args)
        require(result.returncode == 1 and result.stdout == '' and
                result.stderr.startswith(f'escrowc: {code}: ') and result.stderr.count('\n') == 1,
                f'refusal {args[:3]}: {result.returncode} {result.stderr!r}')
    usage = tool('runtime', 'x', 'debreu')
    require(usage.returncode == 2, 'evmtool usage exit')
    return len(rows)


def debreu_cases(runtime):
    cases = 0
    initial = {}
    for decision, ballots in ((1, (1, 1, 3)), (2, (2, 2, 3)), (3, (3, 3, 3))):
        expect(f'cast-{decision}', runtime, data('cast', *ballots), initial, initial, decision)
        cases += 1
        for same in (False, True):
            payer, payee = 17, 17 if same else 34
            for balance in (4, 20):
                # SPEC O7: release credits the payee, refund credits the payer.
                before = {COUNT: 1, slot(PAYER, 0): payer, slot(PAYEE, 0): payee,
                          slot(AMOUNT, 0): 5, slot(LEDGER, payee): 10, slot(LEDGER, payer): balance,
                          slot(CREDIT, payer): 1, slot(CREDIT, payee): 7,
                          slot(BALLOTS, 0): pack(ballots)}
                after = dict(before)
                result = None
                if balance >= 5:
                    result = decision
                    after[slot(LEDGER, payer)] -= 5 if decision in (1, 2) else 0
                    after[slot(CREDIT, payee)] += 5 if decision == 1 else 0
                    after[slot(CREDIT, payer)] += 5 if decision == 2 else 0
                    after[slot(CLOSED, 0)] = 1 if decision in (1, 2) else 0
                expect(f'settle-{decision}-{same}-{balance}', runtime,
                       data('settle', 0), before, after, result)
                cases += 1
    before = {COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34, slot(AMOUNT, 0): 5,
              slot(LEDGER, 17): 20, slot(CREDIT, 17): 2**256 - 1, slot(CREDIT, 34): 2**256 - 1}
    for name, ballots in (('release', (1, 1, 3)), ('refund', (2, 2, 3))):
        stored = voted(before, 0, ballots)
        expect(f'credit-overflow-{name}', runtime, data('settle', 0), stored, stored, None)
    # M4 R2: vote c b refuses a ballot outside 1..3 (member 0 is SENDER).
    for ballot in (0, 4):
        expect(f'bad-ballot-{ballot}', runtime, data('vote', 0, ballot), before, before, None)
    return cases + 4


def closing_cases(runtime):
    # SPEC O4: settle c reverts unless c < claimCount and claim c is open.
    # Release and refund close claim c, hold leaves it open.
    release, refund, hold = (1, 1, 3), (2, 2, 3), (3, 3, 3)
    claim = {COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34, slot(AMOUNT, 0): 5,
             slot(LEDGER, 17): 20, slot(LEDGER, 34): 10}
    rows = [('bound-count', 1, claim), ('bound-max', 2**256 - 1, claim),
            ('bound-empty', 0, {slot(LEDGER, 17): 20})]
    for label, index, before in rows:
        stored = voted(before, index, release)
        expect(f'settle-{label}', runtime, data('settle', index), stored, stored, None)
    released = {**claim, slot(LEDGER, 17): 15, slot(CREDIT, 34): 5, slot(CLOSED, 0): 1}
    refunded = {**claim, slot(LEDGER, 17): 15, slot(CREDIT, 17): 5, slot(CLOSED, 0): 1}
    # M4 R5: settle c reads the ballots from slot 7 and writes none, so they stay.
    expect('hold-open', runtime, data('settle', 0), voted(claim, 0, hold), voted(claim, 0, hold), 3)
    expect('hold-then-release', runtime, data('settle', 0), voted(claim, 0, release),
           voted(released, 0, release), 1)
    expect('close-refund', runtime, data('settle', 0), voted(claim, 0, refund),
           voted(refunded, 0, refund), 2)
    again = 0
    for label, closed in (('release', released), ('refund', refunded)):
        for name, ballots in (('release', release), ('refund', refund), ('hold', hold)):
            stored = voted(closed, 0, ballots)
            expect(f'settle-after-{label}-{name}', runtime, data('settle', 0), stored, stored, None)
            again += 1
    two = {**claim, COUNT: 2, slot(PAYER, 1): 34, slot(PAYEE, 1): 17, slot(AMOUNT, 1): 3}
    first = voted({**two, slot(LEDGER, 34): 7, slot(CREDIT, 17): 3, slot(CLOSED, 1): 1}, 1, release)
    both = voted({**first, slot(LEDGER, 17): 15, slot(CREDIT, 34): 5, slot(CLOSED, 0): 1}, 0, release)
    expect('close-index-1', runtime, data('settle', 1), voted(two, 1, release), first, 1)
    expect('open-index-0', runtime, data('settle', 0), voted(first, 0, release), both, 1)
    return len(rows) + 3 + again + 2


def reentrant_sender(calldata, *, fail_after=False):
    # Call the escrow once from the recipient fallback. The storage flag
    # stops recursion when the nested withdrawal calls this recipient again.
    code = bytearray.fromhex('5f546100005760015f55')
    for offset in range(0, len(calldata) // 2, 32):
        word = calldata[2 * offset:2 * (offset + 32)].ljust(64, '0')
        code.extend(bytes.fromhex('7f' + word + f'60{offset:02x}52'))
    # CALL(gas, escrow, 0, 0, calldata size, 0, 0); retain success in slot 1.
    code.extend(bytes.fromhex(f'5f5f60{len(calldata) // 2:02x}5f5f73' + RECEIVER + '5af1600155'))
    if fail_after:
        code.extend(bytes.fromhex(REVERTING))
    code[3:5] = len(code).to_bytes(2, 'big')
    code.extend(bytes.fromhex('5b00'))  # JUMPDEST; STOP
    return code.hex()


def withdraw_reentry_cases(runtime):
    mine = slot(CREDIT, int(SENDER, 16))
    before = {mine: 30}
    for label, nested, result, paid in (('within', 7, 11, 19), ('full', 18, 0, 30),
                                       ('above', 19, 18, 12)):
        actual = run(f'withdraw-reentry-{label}', runtime, data('withdraw', 12),
                     before=before, balance=100, sender=reentrant_sender(data('withdraw', nested)))
        require(actual['status'] == 'success', f'reentry-{label}: outer withdrawal failed')
        require(actual['storage'] == ({mine: result} if result else {}),
                f'reentry-{label}: wrong credit {actual["storage"]}')
        require(actual['balances'][RECEIVER] == 100 - paid and
                actual['balances'][SENDER] == FUNDS + paid, f'reentry-{label}: wrong transfer')
        require(actual['created'].get(SENDER) == {0: 1, **({1: 1} if nested <= 18 else {})},
                f'reentry-{label}: callback did not exercise the nested call')
        require(int(actual['output'], 16) == result,
                f'reentry-{label}: returned {int(actual["output"], 16)}, remaining credit {result}')
    expect('withdraw-reentry-revert', runtime, data('withdraw', 12), before, before, None,
           balance=100, sender=reentrant_sender(data('withdraw', 7), fail_after=True),
           balances={RECEIVER: 100, SENDER: FUNDS})
    return 4


def withdraw_cases(runtime):
    # SPEC O7: withdraw n guards n <= credit caller, debits the credit, then
    # sends n wei to the caller. A failed send reverts with the credit kept.
    mine = slot(CREDIT, int(SENDER, 16))
    before = {mine: 30}
    unchanged = {RECEIVER: 100, SENDER: FUNDS}
    for label, amount in (('within', 12), ('full', 30)):
        expect(f'withdraw-{label}', runtime, data('withdraw', amount), before, {mine: 30 - amount},
               30 - amount, balance=100,
               balances={RECEIVER: 100 - amount, SENDER: FUNDS + amount})
    rows = [('above', data('withdraw', 31), 0, None, 100),
            ('value', data('withdraw', 12), 1, None, 100),
            ('short', data('withdraw', 12)[:-2], 0, None, 100),
            ('sender-reverts', data('withdraw', 12), 0, REVERTING, 100),
            ('no-funds', data('withdraw', 12), 0, None, 5)]
    for label, calldata, value, sender, balance in rows:
        expect(f'withdraw-{label}', runtime, calldata, before, before, None, value=value,
               balance=balance, sender=sender, balances={RECEIVER: balance, SENDER: FUNDS})
    return 2 + len(rows) + withdraw_reentry_cases(runtime)


def vote_cases(runtime):
    # M4 R2 to R5: vote c b writes b into the field at 4^m of the slot 7 word of
    # claim c for member m (a new ballot replaces the old one). settle c reverts
    # unless all n fields are present, and any caller can settle.
    claim = {COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34, slot(AMOUNT, 0): 5,
             slot(LEDGER, 17): 20, slot(LEDGER, 34): 10}
    mark = slot(BALLOTS, 0)
    for m, member in enumerate(MEMBERS):
        others = pack((3, 3, 3)) - 3 * 4**m
        new = others + (m + 1) * 4**m
        expect(f'vote-member-{m}', runtime, data('vote', 0, m + 1), {**claim, mark: others},
               {**claim, mark: new}, new, caller=member)
    chain('vote-replace', runtime, [(MEMBERS[1], data('vote', 0, 1), 4),
                                    (MEMBERS[1], data('vote', 0, 2), 8)], claim, {**claim, mark: 8})
    rows = [('non-member', data('vote', 0, 1), 0, claim, OUTSIDER),
            ('closed', data('vote', 0, 1), 0, {**claim, slot(CLOSED, 0): 1}, SENDER),
            ('unknown', data('vote', 1, 1), 0, claim, SENDER),
            ('value', data('vote', 0, 1), 1, claim, SENDER),
            ('short', data('vote', 0, 1)[:-2], 0, claim, SENDER)]
    for label, calldata, value, before, caller in rows:
        expect(f'vote-{label}', runtime, calldata, before, before, None, value=value, caller=caller)
    # A vote on claim 1 leaves the claim 0 word, so settle(0) still has no ballot of member 2.
    two = voted({**claim, COUNT: 2, slot(PAYER, 1): 34, slot(PAYEE, 1): 17, slot(AMOUNT, 1): 3},
                0, (1, 1, 0))
    chain('vote-claim-binding', runtime, [(MEMBERS[2], data('vote', 1, 1), 16),
                                          (SENDER, data('settle', 0), None)],
          two, {**two, slot(BALLOTS, 1): 16})
    for m in range(len(MEMBERS)):
        missing = {**claim, mark: pack((1, 1, 1)) - 4**m}
        expect(f'settle-missing-{m}', runtime, data('settle', 0), missing, missing, None)
    released = {**claim, slot(LEDGER, 17): 15, slot(CREDIT, 34): 5, slot(CLOSED, 0): 1,
                mark: pack((1, 1, 3))}
    expect('settle-any-caller', runtime, data('settle', 0), {**claim, mark: pack((1, 1, 3))},
           released, 1, caller=OUTSIDER)
    votes = [(member, data('vote', 0, b), pack((1, 1, 3)[:m + 1]))
             for m, (member, b) in enumerate(zip(MEMBERS, (1, 1, 3)))]
    chain('chained', runtime, votes + [(OUTSIDER, data('settle', 0), 1)], claim, released)
    return 3 + 1 + len(rows) + 1 + len(MEMBERS) + 2


def entry_cases(runtime, regime):
    claim = {slot(LEDGER, 17): 3}
    after = {slot(LEDGER, 17): 8, COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34, slot(AMOUNT, 0): 5}
    expect(f'{regime}-deposit', runtime, data('deposit', 17, 34, 5), claim, after, 0, value=7)
    second = {**after, slot(LEDGER, 34): 1, COUNT: 2, slot(PAYER, 1): 34, slot(PAYEE, 1): 17,
              slot(AMOUNT, 1): 1}
    expect(f'{regime}-deposit-next', runtime, data('deposit', 34, 17, 1), after, second, 1, value=1)
    rows = [('short-value', data('deposit', 17, 34, 5), 4, claim),
            ('payer-range', data('deposit', 2**160, 34, 0), 0, claim),
            ('payee-range', data('deposit', 17, 2**160, 0), 0, claim),
            ('overflow', data('deposit', 17, 34, 5), 5, {slot(LEDGER, 17): 2**256 - 3}),
            ('short-data', data('deposit', 17, 34, 5)[:-2], 5, claim),
            ('no-selector', 'aabbcc', 0, claim),
            ('unknown', 'ffffffff', 0, claim)]
    for label, calldata, value, before in rows:
        expect(f'{regime}-{label}', runtime, calldata, before, before, None, value=value)
    return 2 + len(rows)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    require(bytecode('keccak', '') ==
            'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470', 'keccak256("")')
    require(bytecode('keccak', 'transfer(address,uint256)')[:8] == 'a9059cbb', 'transfer selector')
    cases = refusals()
    runtime = bytecode('runtime', 3, 'debreu', *CODES, *addresses(3))
    deploy('debreu-deploy', bytecode('creation', 3, 'debreu', *CODES, *addresses(3)), runtime)
    cases += (debreu_cases(runtime) + closing_cases(runtime) + withdraw_cases(runtime) +
              entry_cases(runtime, 'debreu') + vote_cases(runtime))
    expect('amend', runtime, data('amend'), {}, {}, pack(CODES))
    expect('amend-value', runtime, data('amend'), {}, {}, None, value=1)
    expect('cast-value', runtime, data('cast', 1, 1, 3), {}, {}, None, value=1)
    ready = voted({COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34, slot(AMOUNT, 0): 5,
                   slot(LEDGER, 17): 20}, 0, (1, 1, 3))
    expect('settle-short', runtime, data('settle', 0)[:-2], ready, ready, None)
    cases += 4
    impossible = bytecode('runtime', 3, 'impossibility')
    deploy('impossibility-deploy', bytecode('creation', 3, 'impossibility'), impossible)
    cases += entry_cases(impossible, 'impossibility')
    expect('impossibility-cast', impossible, data('cast', 1, 1, 3), {}, {}, None)
    # Arrow-impossibility is deposit-only: no withdraw entry (design section 4).
    credit = {slot(CREDIT, int(SENDER, 16)): 30}
    expect('impossibility-withdraw', impossible, data('withdraw', 12), credit, credit, None,
           balance=100, balances={RECEIVER: 100, SENDER: FUNDS})
    # M4 R6: Arrow-impossibility has no vote entry.
    expect('impossibility-vote', impossible, data('vote', 0, 1), ready, ready, None)
    cases += 3
    for members, codes, vectors in (
            (1, (3, 2, 1), [(1,), (2,), (3,)]),
            (14, tuple(i % 3 + 1 for i in range(120)),
             [tuple((m * k) % 3 + 1 for m in range(14)) for k in range(5)] + [(1,) * 14, (2,) * 14])):
        code = bytecode('runtime', members, 'debreu', *codes, *addresses(members))
        for k, ballots in enumerate(vectors):
            decision = verdict(members, codes, ballots)
            expect(f'cast-n{members}-{k}', code, data('cast', *ballots), {}, {},
                   decision)
            before = voted({COUNT: 1, slot(PAYER, 0): 17, slot(PAYEE, 0): 34,
                            slot(AMOUNT, 0): 5, slot(LEDGER, 17): 20}, 0, ballots)
            after = dict(before)
            if decision in (1, 2):
                after[slot(LEDGER, 17)] = 15
                after[slot(CREDIT, 34 if decision == 1 else 17)] = 5
                after[slot(CLOSED, 0)] = 1
            expect(f'settle-n{members}-{k}', code, data('settle', 0), before, after, decision)
            cases += 2
        for m, member in enumerate(addresses(members)):
            mark = slot(BALLOTS, 0)
            others = pack((3,) * members) - 3 * 4**m
            new = others + (m % 3 + 1) * 4**m
            expect(f'vote-n{members}-{m}', code, data('vote', 0, m % 3 + 1),
                   {COUNT: 1, mark: others}, {COUNT: 1, mark: new}, new, caller=member[2:])
            cases += 1
        expect(f'amend-n{members}', code, data('amend'), {}, {}, pack(codes))
        cases += 1
    print(f'SETTLEMENT cases={cases} deploy=2 geth=expected OK (logs: {WORK})')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'SETTLEMENT FAIL: {error}', file=sys.stderr)
        sys.exit(1)
