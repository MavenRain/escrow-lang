# escrow-lang

escrow-lang (a working name) is a restricted dialect of assay for one
governed escrow. Its type formers are the type formers of ledger-lang. Its
core types and operations are only those of the denotational design in
`design/DENOTATIONAL-DESIGN.md`. The assay kernel checks a program. The
compiler writes one `.asy` contract, and assay compiles it to EVM bytecode.

- `SPEC.md`: the language specification (draft).
- `design/DENOTATIONAL-DESIGN.md`: the design, verbatim.
- `probe/CAPABILITY.md`: what the assay host can and cannot do.
- `PIN`: the assay commit that the generator targets.

## License

MIT OR Apache-2.0.
