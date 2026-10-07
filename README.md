# escrow-lang

escrow-lang (a working name) is a restricted dialect of assay for one
governed escrow. Its type formers are the type formers of ledger-lang. Its
core types and operations are only those of the denotational design in
`design/DENOTATIONAL-DESIGN.md`. The assay kernel checks a program. The
compiler writes one `.asy` contract, and assay compiles it to EVM bytecode.

- `SPEC.md`: the language specification (draft).
- `design/DENOTATIONAL-DESIGN.md`: the design, verbatim.
- `probe/CAPABILITY.md`: what the assay host can and cannot do.
- `PIN`: the Assay base commit used with the patch in `toolchain/`.

## Local compiler and generator

All compiler changes needed by escrow-lang live in
`toolchain/assay-surface-branch.patch`. Setup clones the base in `PIN`,
applies that patch, and builds under this repository's ignored `.tools/`.
It does not edit an existing Assay checkout.

```sh
python3 toolchain/assay.py setup
python3 toolchain/assay.py check examples/contracts/arrow-debreu.asy
zsh test/generator.sh
python3 test/settlement.py
```

Setup requires Git, Python 3, Node.js 22 or newer, and the pinned Bend
compiler. Without `BEND`, Assay's bootstrap installs Bend inside `.tools/`.
For offline setup, pass `--source /path/to/assay` and set `BEND` to an
existing pinned Bend checkout's `bin/bend`. The source is read only.
The generator also uses zsh, ripgrep and bc; settlement tests use geth's
`evm` executable.

The wrapper verifies the base and patch before every run. Rebuild with
`setup` after changing the patch. An unexpected checkout is refused rather
than reset. See [toolchain notes](toolchain/README.md) for provenance and
validation scope.

## License

MIT OR Apache-2.0.
