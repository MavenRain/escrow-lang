# escrow-lang

escrow-lang (a working name) is a language for one governed escrow. Its
type formers are the type formers of ledger-lang. Its core types and
operations are only those of the denotational design in
`design/DENOTATIONAL-DESIGN.md`. The compiler `escrowc` is C99 built with
TinyCC. It checks the dependent types of a program and writes the EVM
bytecode of the escrow contract directly.

- `SPEC.md`: the language specification (draft).
- `design/DENOTATIONAL-DESIGN.md`: the design, verbatim.
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

## License

MIT OR Apache-2.0.
