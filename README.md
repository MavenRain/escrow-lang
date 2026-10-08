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
under the ignored `.gatework/`.

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
contract has these entries:

- `deposit(p, q, n)`: payable. It adds `n` to the ledger of `p` and
  appends the claim `(p, q, n)`. It returns the claim index.
- `cast(b1, ..., bn)`: it returns the verdict of the ballots (1 release,
  2 refund, 3 hold) and writes nothing.
- `settle(c, b1, ..., bn)`: it decides the open claim `c` with the
  verdict. Release moves `n` from the ledger of `p` to the credit of `q`.
  Refund moves `n` from the ledger of `p` to the credit of `p`. Release
  and refund close the claim. Hold writes nothing, and the claim stays
  open.
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

Pull payments: `settle` sends no funds. The payee of a release or the
payer of a refund calls `withdraw` to get the funds. Thus a recipient
whose code reverts cannot block `settle`. `withdraw` debits the credit
before it sends, and a failed send reverts the call, so the credit does
not change. The recipient code can call `withdraw`, `deposit` or `settle`
during the send. Each withdrawal checks and debits the current credit
first. Total withdrawals by an address are bounded by its initial credit
plus any credit added by settlements during recipient execution. The
returned credit includes reentrant withdrawals and new settlement credits.

## License

MIT OR Apache-2.0.
