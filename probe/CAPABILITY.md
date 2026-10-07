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
   universes, and it erases quantity-0 terms. It checks
   `examples/m1-spine.kan` (P2). Generic families are limited (P2).
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

## M0 probe results (2026-10-06)

Build: assay HEAD = PIN 092fa7a, but `_build/bend/assay.js` was built
2026-10-05 23:36, after three staged src edits (frontend.bend 1 line,
return_abi.bend 1 line, tests.bend +9 -3). The results are for PIN plus
those edits, not PIN exactly. The assay staged count stayed 56.

Runner: `zsh probe/run.sh LABEL VERB ARGS..`. It sets `NODE_COMPILE_CACHE`
to `$TMPDIR/escrow-probe`, caps the V8 heap at 3 GB, kills the run above
4 GB RSS and prints the wall time and the peak RSS (measured inside node).

### P1. A runtime `le` branch with writing continuations: PASS

`probe/p1-le-branch.asy`: `split2` is one `le` with two writing branches.
`split3` is a nested `le` with three slots.

| Command | Result | Wall s | RSS MB |
|---|---|---|---|
| `check probe/p1-le-branch.asy` | ok | 0.23 | 83 |
| `axioms probe/p1-le-branch.asy` | `EvmOpcodes` | 0.67 | 81 |
| `emit probe/p1-le-branch.asy -o NEWDIR` | abi.json, axioms.txt, init.hex, layout.json, runtime.hex | 0.32 | 123 |
| `axioms examples/CounterSurface.asy` | `EvmOpcodes` | 0.25 | 87 |
| `run` split2(2,5) | output 1, storage {0: 2} | 0.37 | 116 |
| `run` split2(5,2) | output 2, storage {1: 2} | 0.35 | 125 |
| `run` split3(3,3) | output 3, storage {2: 3} | 0.71 | 94 |
| `run` split3(2,5) | output 1, storage {0: 2} | 1.95 | 114 |
| `run` split3(5,2) | output 2, storage {1: 2} | 0.57 | 120 |

Calldata: `cast calldata 'split2(uint256,uint256)' 2 5` (and so on). `run`
prints the storage, so `trace` is not necessary. `trace` on the five paths:
exit 0, 0.48 to 1.02 s, 123 to 132 MB, one SSTORE at the expected slot.
`emit` refuses a directory that exists ("use a new directory under an
existing parent"). The assay example CounterSurface also reports
`EvmOpcodes`: the marker is part of the assay core protocol.

### P2. Equality by fibered match: PASS only with a fixed index type

- `check examples/m1-spine.kan`: ok, 0.58 s, 113 MB. Its families have no
  parameters (lines 259 to 326).
- A constructor of a family with a parameter cannot appear in a term.
  `box 3`, `(box 3 : Box Nat)`, `id (Box Nat) (box 3)` and a bare `refl`
  against `Eq Nat 2 2` give "cannot infer: the constructor box needs an
  expected type". `box Nat 3` gives "box takes 1 arguments and the term
  gives 2". A bare `box` against `A -> Box A` gives "takes 1 arguments and
  the term gives 0". A `match` on such a family checks (`in Box`, pattern
  `box a`).
- A family with a type index (`Eq : (0 A : Type 0) -> (0 a : A) -> (0 b :
  A) -> ..`) is refused in `Type 0` ("index above universe: the index A of
  Eq lives at 2 and Eq is declared at 1") and accepted in `Type 1`. Its
  constructors take the type: `refl Nat 2`, `cons Nat 1 (nil Nat)`. A
  `match` binds the type index again (`in Eq B i j`, pattern `refl 0 C 0
  z`), so a branch cannot apply a function on the outer `A` to a
  pattern-bound value. `symm` and `length` check; `transport`, `cong`,
  `map` and `fold` cannot be written.
- `probe/p2-eq.asy`: `EqNat` and `EqDec`, each with a fixed index type in
  `Type 0`; `transportNat`, `symmNat`, `transNat` (by transport),
  `congNat`, `congND` (Nat to Decision) and six uses through `natAdd`,
  `natSub`, `natLt` and beta. `check`: ok, 0.19 s, 87 MB. `axioms`: none,
  0.61 s, 88 MB.
- Other syntax facts: `fun (x : A) (y : B) => t` takes several binders;
  `def` takes no parameters (`def NAME :`, `def rec NAME :`, `axiom`, `mu`,
  `mutual`); `prod`/`tuple` projections count from 0 (`t.0`, `t.1.0`);
  Sigma projections are `s.1` and `s.2`; `inj 1 of 2 5` checks against
  `sum (Nat, Nat)`; a nullary constructor of a family without parameters
  checks bare.

### P3. Normal forms: `--print` and `--erased` do not show them

- `check --print probe/p3-print.asy` (0.16 s, 78 MB) prints the elaborated
  core term: `def y : Nat := (Out SPi w _ Nat (APt w 41) f)`.
- `check --erased probe/p3-print.asy` (0.14 s, 78 MB) prints the erased
  code: `fun y () : union nat := KTail (KGlobal f) [KLit 41]`.
- Fallback, `probe/p3-refl.asy`: `def cy : EqNat y 42 := reflNat 42` and
  three more correct candidates. `check`: ok, 0.15 s, 78 MB. A wrong
  candidate (`reflNat 41`) fails in 0.70 s, 78 MB, with "mismatch: the
  constructor reflNat of EqNat gives the index 41 and the type asks for
  42". The message prints the normal form. Thus one check with a sentinel
  candidate reads one value, and one check of all candidates confirms a
  table.

### P4. Fold over a list of N ballots: no step limit hit

`zsh probe/p4-gen.sh N > FILE` writes `Decision`, a `Ballots` list family,
`def rec foldBallots`, a tally `bump`, a chain of N list definitions and a
`reflT3` candidate for the tally. `probe/p4-fold-100.asy` is N = 100.

| N | `check` wall s | RSS MB |
|---|---|---|
| 100 | 0.41 | 121 |
| 1000 | 23.82 | 165 |
| 4000 | 121.86 | 393 |

`axioms` on N = 100: none, 1.39 s, 115 MB. The time grows faster than N
(N times 10 gives time times 58).

### Consequence for the prelude (SPEC open item O8)

`Eq A x y`, `List A` and `Option A` cannot be `mu` families with a type
argument that the operations can use. Proposal: one equality family per
index type (`EqNat`, `EqDec`, `EqTally`), one list family per element type
(`Ballots`, `Claims`), and `Option A` and `Sum A B` as type functions over
the built-in `sum`, which stay generic.

## M0 prelude and examples (2026-10-06)

Gate: `zsh prelude/assemble.sh --members 3` plus a check of each prefix of
`prelude/Prelude.asy` (one prefix per `-- @section`, stop at the first
failure), then `axioms`, then each example by `zsh prelude/assemble.sh
examples/programs/NAME.asy > examples/NAME.asy`. Wall times are on a loaded
box. The assay staged count was 56 before and after.

| Command | Result | Wall s | RSS MB |
|---|---|---|---|
| `check` prefixes 1 to 8 (members 3) | ok, each | 0.96 to 15.12 | 73 to 118 |
| `axioms` full prelude | no output (no axiom) | 2.36 | 112 |
| `check examples/arrow-impossibility.asy` | ok | 10.95 | 99 |
| `axioms examples/arrow-impossibility.asy` | no output | 4.19 | 110 |
| `check examples/arrow-debreu.asy` | ok | 36.45 | 118 |
| `axioms examples/arrow-debreu.asy` | no output | 7.86 | 149 |
| mutant: `payeeAfterSettle` claims 4 | refused: "the constructor reflNat of EqNat gives the index 4 and the type asks for 5" | 10.18 | 140 |

Scenario checks (refl candidates in the examples):
- arrow-impossibility: after `deposit 1 2 5`, balance 1 = 5, balance 2 = 0,
  one claim. `x` and `y` are in one orbit (`reflTally`), and `first x =
  release`, `first y = refund`: the constitution is not orbit-constant.
- arrow-debreu: verdict of `x` = release, `castOrbit` on `x` and `y`,
  `homAmend`, `reconstitute`, `selfConstitutes`; after `deposit 1 2 5`
  then `settle`, balance 1 = 0, balance 2 = 5, and one claim stays (O4).

Probe-forced changes found in M0:
- P5, `probe/p5-sigma-eta.asy`: `fun (s : S) => (s.1, s.2)` with `S := (n
  : Nat) * EqNat n 3` fails: "the term has type (EqNat [(Elim SPi w n Nat s
  with ..); 3]) and the expected type is (EqNat [(Elim SPi w n Nat s as self
  return Nat with ..); 3])". The type of `s.2` holds a projection without
  the return annotation. A written `s.1` holds one with it. Conversion does
  not identify them. Forms tried for a Sigma pattern: `match x as q in
  Config return Tally with | (xs, e) => ..`, `match x as q return ..`,
  `match x with ..`, `case x with | (xs, e) => ..` ("expected a leg number
  or a constructor name after '|'"), `let (xs, e) := x in ..` ("expected a
  name and ':' after 'let'"), `let (xs, e) = x in ..`. A literal Sigma
  binder type, a curried helper `orbitOf x.1 x.2` and an ascription
  `(x.2 : ..)` give the same mismatch. Consequence: `Config`, `Tally` and
  `Aggregation F` are `mu` records read by `match` (SPEC O10).
- A `mu` family with an index of a function type (`Aggregation : (0 F :
  ChoiceRule) -> Type 0`) checks in `Type 0`; `mkAgg F L p` takes `F`
  explicitly, and `match L as q in Aggregation G return .. with | mkAgg 0 G
  l p => ..` reads it.
- `tuple ()` is the value of `prod ()`; `inj 0 of 2 (tuple ())` checks
  against `Option A`.
- `unfold` is not written: no structural measure, no `Nat` fuel (SPEC O9).

## M1 probe results (2026-10-06)

This is a hand build in the main loop. The Fable builder died on a 429
(req_011CfmiAvXiC4A1F7w64B2zu). The opus fallback died on
`reasoning_extraction` (req_011CfmiEopkq9GNUGUk3fRi7). Neither agent wrote
a file.

### P6. `emit` checks each top-level definition

`probe/p6-leaf-contract.asy` is the P1 protocol with two entries. Each entry
returns the code of `rule F agg t` for one literal tally. `probe/p6-run.sh`
appends it to the assembled arrow-debreu program.

| Command | Result |
|---|---|
| `check` | ok (20.6 s, 120 MB) |
| `axioms` | `EvmOpcodes` only |
| `emit`, `run` | refused: "a projection needs a right former" |

`probe/p6-variants.sh`: the leaf `decCode release` uses no prelude
operation, and it gets the same refusal. Thus the leaf is not the cause.

`probe/p6-prefix.sh`: the file is the members line, prelude sections 1 to
k, and the P6 contract with the leaf `decCode release`.

| k | `emit` |
|---|---|
| 1 to 6 | ok (0.85 to 3.96 s, 85 to 121 MB) |
| 7, 8 | refused: `M0_PROTOCOL: M1 wordNat` |

Probe-forced: `emit` applies its checks to each top-level definition, not
only to the definitions that `main` reaches. Prelude section 7 (`Ledger :=
Address -> Nat` and its operations) fails them. The program scenario
(projections of an open `Escrow`) fails them too. Thus the contract file
cannot hold the prelude or the program (SPEC O11).

Probe-forced: a leaf helper over open counts cannot give `reflNat members`,
because `natAdd` reduces only on literals. Each table entry takes literal
counts.

### P7. One packed code tabulates the orbit rule: PASS

`probe/p7-table.sh` appends this to the assembled arrow-debreu program:
`code := decCode (L t0) + 4 * decCode (L t1)`, with `decCode` release 1,
refund 2, hold 3, `t0 = (2, 1, 0)` and `t1 = (0, 2, 1)`.

| Candidate | `check` |
|---|---|
| `EqNat code 0 := reflNat 0` | refused: "gives the index 0 and the type asks for 9" (15.7 s) |
| `EqNat code 9 := reflNat 9` | ok (7.7 s, 118 MB) |

Method (SPEC O11, RULED 2026-10-06): run 1 checks a wrong candidate, and the
generator reads the packed value from the error text. Run 2 checks it with
`reflNat`. Run 2 is the certificate: the kernel accepts the table only when
the value is the normal form of `code`. The error text is a hint, not a
trust base. Base-4 digit i is the code of tally i. With `members = n` there
are (n + 1)(n + 2) / 2 digits. The time for a large n is not measured.

The wall times in this section are 10 to 50 s for files that took less than
1 s in M0. The machine had other loads. Do not use these times as a
benchmark.

## M1 contract form: no form has a branch and a mapping (2026-10-06)

This is a read of the assay documents, not a probe run. The Fable builder
died on a 429 (req_011Cfn3kFoDtugMaL9frsSRQ). The opus fallback died on
`reasoning_extraction` (req_011Cfn3p85F47BTV6Hb77kmj). Neither agent wrote
a file.

- The surface `contract` form has `Mapping K V` storage with runtime keys,
  `payable`, `callvalue` and `guard` (assay examples MappingAccess.asy,
  Payable.asy, CallValue.asy). Its statements are `sload`, `caller`,
  `callvalue`, `calldatasize`, `calldataload`, `add`, `sub`, `sstore`,
  `guard le a b`, `let`, `pure` and `revert` (assay dev/M1-SURFACE.md:52-64).
  No statement has two continuations. A `guard` only reverts.
- The core `Tx` protocol has `le a b yes no` (assay dev/M1-EMISSION.md:84).
  Its storage slots must be compile-time constants within the declared
  layout (dev/M1-EMISSION.md:102-103). Mapping slots come from the surface
  source adapter (dev/M2-MAPPING-RUNTIME.md:20).
- The contract of SPEC section 7 needs both: the ledger is keyed by a
  runtime address, and `cast` and `settle` branch on ballot words.

P8 (next probe): can a surface entry body hold a core `le a b yes no`
term? dev/M1-SURFACE.md says "The core syntax remains available for
programs that recover from an arithmetic error". It does not say that a
core term can appear in a surface body. SPEC O12 lists the options.

### P8. A core `le` term in a surface body: FAIL

`probe/p8-surface-le.sh` writes six surface contracts with a mapping and
runs `check` on each (2026-10-06).

| Variant | Body of `pick` | `check` |
|---|---|---|
| a | `le a b (pure (word 1)) (pure (word 2))` | `SURFACE_NAME: expected an unreserved identifier` |
| b | `le a b` with two `sstore ; pure` legs | same as a |
| c | `le a b (done (word 1)) (done (word 2))` | same as a |
| d | `if le a b then .. else ..` | `SURFACE_SYNTAX: expected <-` |
| e | `x <- le a b ; pure x` | `SURFACE_EFFECT: expected sload, caller, callvalue, calldatasize, calldataload, address, add or sub` |
| z (control) | `guard le a b ; sstore balances a (word 1) ; pure (word 1)` | ok |

Probe-forced: a surface body cannot hold a core term and has no two-way
branch. For a surface contract, `axioms` reports only `EvmOpcodes`.

## M1 contract writer (2026-10-06)

`gen/contract.sh` writes a surface contract with no branch (SPEC O12 and
section 7). `gen/table.sh` gives its table by the P7 method over all
tallies.

| Step | Result |
|---|---|
| `gen/table.sh examples/programs/arrow-debreu.asy` | `3 3 2 2 3 3 2 1 1 1` (13.6 s). It agrees with P7 at (2, 1, 0) and (0, 2, 1). |
| impossibility, members 3: `check`, `axioms`, `emit` | ok, `EvmOpcodes` only, ok (5 files) |
| debreu, members 3 (72 lines): `check`, `axioms`, `emit` | ok (5.2 s), `EvmOpcodes` only, ok (5 files) |
| `run` with `amend()` | `0x56faf` = 356271 = the packed table |
| `run` with `cast(1, 1, 2)` | `0`. `run` starts from empty storage (`"storage":{}`) and does not apply the constructor. |

Probe-forced: a `run` test of `cast` or `settle` must give the table slots
with `--storage SLOT=WORD`. `assay mapping-slot` gives the slots.
