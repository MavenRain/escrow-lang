# Assay host capability (probe, 2026-10-06)

A read-only probe of `/Users/oobi/Documents/assay` at commit 092fa7a with 56
staged files of an in-flight build. The probe wrote nothing in the assay
tree. Citations are relative to that tree.

## Kernel (what a program can say)

- Indexed families: `mu F params : indices -> Type n := | c binders : F args`
  (SPEC.md:364-365, grammar :549-551). Elimination: `match t as x in F i
  return M with | c ys => b` (SPEC.md:352). A fibered match needs a motive
  (SPEC.md:65-72). Nested and non-strictly-positive families are refused
  (SPEC.md:55-63). Examples: `examples/m1-spine.kan:294-296` (Vec-like),
  `:383-384` (Eq-like `SpineAgreement`), `test/fixtures/mu-constructor-scopes.kan:6`
  (parameters and indices).
- Pi `(q x : A) -> B`, Sigma `(q x : A) * B`, pairs `(a, b)`, `p.1`, `p.2`
  (SPEC.md:341-349). Quantity `0` erases a binder.
- Coproducts and products: `sum(..)`, `prod(..)`, `inj k of n t`, `case`,
  `tuple(..)`, `t.k` (SPEC.md:350-358, :370-375).
- Universes: `Prop` is `Univ 0`, `Type n` is `Univ (n + 1)` (SPEC.md:359-360).
- Built in: `Nat` with literals and `natAdd`, `natSub`, `natMul`, `natEq`,
  `natLt` (SPEC.md:149, :568). Nat has no eliminator (dev/EMISSION.md:39).
- Not built in: `Eq`, `List`, `Option`, `Bool`. Each file defines its own,
  for example `def Bool := sum(prod(), prod())` (m1-spine.kan:13).
- Large elimination only for subsingleton `Prop` families (SPEC.md:622).
  A family declared in `Type 0` avoids this limit.
- Deferred: `SPar`, `SNu`/`nu`, `Auto` (instances), right formers at a mu
  shape, string types (src/kernel.bend:1961, :1964, :2845, :2538, :3321).

## Backend (what reaches EVM bytecode)

- The runtime value domain is the 256-bit word only. Runtime operations
  are done, store, load, add, sub, le and abort (dev/M1-EMISSION.md:77-85).
  `le` is the only runtime branch.
- A runtime word cannot become a `Nat` (dev/M1-EMISSION.md:103-104).
- Closed records, tags, projections and cases reduce at compile time. A
  user `case` on a user sum or on `Nat` is compile-time only.
- Refused: closures, indirect or unsaturated calls, delay and force
  (dev/EMISSION.md:72-74). There is no heap, no loop and no runtime
  recursion (dev/EMISSION.md:76-77).
- Budgets: 100,000 specialization steps, transaction depth 128, 1,024
  temporary words, 24,576 runtime bytes (dev/EMISSION.md:81-83).
- No runtime operation sends value out of the contract.

## Contracts

- Storage: `storage State := { f : T ; .. }` with `Word`, `Uint8`,
  `Uint256`, `Address`, `Bool` or `Mapping K V`, nested mappings included
  (examples/MappingStorage.asy:2-9, examples/ERC20.asy:5-7). Access:
  `sload balances a`, `sstore allowances a s v` (examples/MappingAccess.asy:13-20).
- No list or array storage. A list of claims needs a count and mappings.
- Guards: `(0 p : Le b a) <- guard Denied (a) (b) (leWord b a)`
  (examples/ProofTerms.asy:14). A failed guard reverts and rolls back writes
  (dev/M1-EQUALITY.md:11-15). A guard reads only word predicates (`leWord`,
  `lt256`, `eqWord`). `EqWord a b` is two `Le` bounds; there is no general
  `Eq` in a guard (dev/M1-EQUALITY.md:8-9, :17-20).
- An axiom witness passes the kernel. Only the emitter check
  WORD_UNBOX_RANGE stops it (dev/EMISSION.md:40-42). escrow-lang must refuse
  axioms itself.

## Modules and CLI

- No import form (SPEC.md:543-575). `check` takes one file. A program must
  be one file: prelude, program and contract together.
- No library interface. A separate front end cannot import assay modules.
  It can write `.asy` text and run the CLI.
- Verbs (src/cli.bend:410, :943-956): `check [--print|--erased] FILE`,
  `axioms FILE`, `emit FILE -o DIR`, `trace|diff FILE --calldata HEX`,
  `run FILE --calldata HEX [--storage SLOT=WORD].. [--value] [--caller]`,
  `mapping-layout FILE`, `calldata-encode`.
- Launcher trap: `_build/bin/assay` puts `NODE_COMPILE_CACHE` in the assay
  tree. Set it to a scratch directory with `env` before each run.
- Measured on examples/CounterSurface.asy: `check` 0.33 s, 84 MB; `check
  --erased` 1.17 s, 111 MB; `emit` 0.62 s, 106 MB (five files); `run` 0.57 s,
  115 MB; `trace` 0.74 s, 120 MB.

## Verdict on the host

1. A compiler written in `.asy`: not possible. Emitted code has no heap,
   no loop and no runtime recursion, and its domain is the word.
2. A restricted assay dialect checked by the assay kernel: possible. The
   kernel admits indexed mu families, Pi, Sigma, sums, products and
   universes, and it erases quantity-0 terms. Not yet run on
   `examples/m1-spine.kan`.
3. A separate front end that imports assay: not possible. A front end that
   writes `.asy` text and runs the CLI is possible.

## Consequences for the compiled contract

- The orbit rule `L : Tally -> Decision` cannot run at runtime as written,
  because a runtime word is not a `Nat`. The compiler evaluates `L` on each
  tally at compile time and writes a tree of `le` tests on the tally words.
  With `members = n` there are `(n + 1)(n + 2) / 2` tallies. The 24,576-byte
  limit bounds `n`; M1 measures it.
- `cast` and `settle` take one ballot word per member. The tally is a
  straight-line sequence of `le` tests and `add`, unrolled `n` times.
- The ledger is `Mapping Address Uint256`. The claims are a count and
  mappings from index to payer, payee and amount.
- No assay operation sends value. Design open item O7 (no outflow) is also
  a limit of the target.

## Open probe items for M0 and M1

- P1. Confirm that a runtime `le` branch can lead to two continuations that
  write different storage. `settle` needs a three-way split at runtime.
- P2. Check `examples/m1-spine.kan` and a scratch prelude with `Eq` in
  `Type 0`, `transport`, `symm`, `trans` and `cong` by fibered `match`.
- P3. Find how `check --print` shows normal forms, so the compiler can
  tabulate `L` and evaluate test scenarios with the assay kernel.
- P4. Measure the kernel step limit on `fold` over a `List` of 100 ballots.
