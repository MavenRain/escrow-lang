# escrow-lang

escrow-lang (a working name) is a language for one governed escrow. Its
type formers are the type formers of ledger-lang. Its core types and
operations are only those of the denotational design in
`design/DENOTATIONAL-DESIGN.md`. The compiler `escrowc` is C99 built with
TinyCC. It checks the dependent types of a program and writes the EVM
bytecode of the escrow contract directly.

- `SPEC.md`: the language specification (draft).
- `design/DENOTATIONAL-DESIGN.md`: the design. Section 3 has the settle
  legs and `withdraw` as the contract does them.
- `probe/CAPABILITY.md`: what the TinyCC host can and cannot do.
- `prelude/Prelude.esc`: the prelude that `escrowc` embeds.
- `examples/programs/`: the Arrow-Debreu and Arrow-impossibility programs.
  The Arrow-Debreu program deposits 5 from payer 1 to payee 2, settles
  claim 0 by release, then withdraws the credit of the payee.
  `payerAfterSettle`, `payeeAfterSettle`, `openAfterSettle` and
  `creditAfterWithdraw` prove the state after each step.

## Build and test

```sh
make
make check-clang
make test
python3 test/settlement.py
python3 test/differential.py
```

`make` needs `tcc` (0.9.28rc) and writes `build/escrowc`. `make
check-clang` needs a clang `cc`. The settlement and differential tests
need geth's `evm` (1.14.12) and foundry's `cast`. They write their logs
under the ignored `.gatework/`. `test/differential.py` compares the
`escrowc verdicts` result of each ballot vector with `cast` and `settle`
in geth. It also compares the geth storage after `settle` with `escrowc
eval` of source `settle` (summary `storage=escrowc-eval`). The Python
model `settled()` is a cross-check.

## Use

```sh
build/escrowc check examples/programs/arrow-debreu.esc
build/escrowc table examples/programs/arrow-debreu.esc
build/escrowc verdicts examples/programs/arrow-debreu.esc F
build/escrowc eval examples/programs/arrow-debreu.esc NAME
build/escrowc build examples/programs/arrow-debreu.esc -o creation.hex
build/escrowc build examples/programs/arrow-debreu.esc --runtime -o runtime.hex
```

Exit 0 is ok, 1 is a refused program and 2 is a usage or IO error. Each
error is one line on stderr, `escrowc: CODE: DEF: message` (SPEC section 2).

## Contract

`escrowc build` writes one contract (SPEC section 7). An Arrow-Debreu
build requires `def memberAddresses : Addresses`, with one distinct address
below 2^160 per member. The addresses are embedded in the runtime code.
The contract has these entries:

- `deposit(p, q, n)`: payable. It adds `n` to the ledger of `p` and
  appends the claim `(p, q, n)`. It returns the claim index.
- `cast(b1, ..., bn)`: it returns the verdict of the ballots (1 release,
  2 refund, 3 hold) and writes nothing.
- `vote(c, b)`: a member records ballot `b` (1, 2 or 3) on open claim `c`.
  A new vote replaces that member's previous ballot. It returns the packed
  ballots word. A caller outside `memberAddresses` is refused.
- `settle(c)`: any caller can settle the open claim `c` once every member
  has voted. It reads the stored ballots and returns their verdict.
  Release moves `n` from the ledger of `p` to the credit of `q`.
  Refund moves `n` from the ledger of `p` to the credit of `p`. Release
  and refund close the claim. Hold writes nothing, and the claim stays
  open. The stored ballots stay after every verdict.
- `amend()`: it returns the packed verdict table and writes nothing.
- `withdraw(n)`: it debits `n` from the credit of the caller, then sends
  `n` wei to the caller. It returns the credit that remains after the
  send.

Only `deposit` accepts a call value. A failed guard reverts the call. An
Arrow-impossibility contract has only `deposit`. Each other call reverts,
so the deposits stay in the contract (design section 4).

Storage slots (a mapping slot is keccak256 of the key word and the base
slot word):

| Slot | Content |
|---|---|
| 0 | ledger: address to word |
| 1 | claim count |
| 2 | claim payer: index to address |
| 3 | claim payee: index to address |
| 4 | claim amount: index to word |
| 5 | credit: address to the word that the address can withdraw |
| 6 | closed flag: index to word, 1 closed and 0 open |
| 7 | ballots: claim index to packed word, member `m` at `4^m`, 0 means no vote |

Pull payments: `settle` sends no funds. The payee of a release or the
payer of a refund calls `withdraw` to get the funds. Thus a recipient
whose code reverts cannot block `settle`. `withdraw` debits the credit
before it sends, and a failed send reverts the call, so the credit does
not change. The recipient code can call `withdraw`, `deposit` or `settle`
during the send. Each withdrawal checks and debits the current credit
first. Total withdrawals by an address are bounded by its initial credit
plus any credit added by settlements during recipient execution. The
returned credit includes reentrant withdrawals and new settlement credits.

Source settle: the prelude `settle` decides the claim at a stable index
with the same legs on the source `Escrow`. Release and refund close the
claim in the closed map. The prelude `withdraw` only takes `n` from the
credit, because the source has no wei (SPEC section 5).

## License

MIT OR Apache-2.0.
