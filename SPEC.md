# escrow-lang specification (draft)

Status: draft before milestone M0. `escrow-lang` is a working name.

## 1. Purpose

escrow-lang is a language for one governed escrow. Its type formers are the
type formers of ledger-lang. Its core data types and core operations are only
the types and operations of `design/DENOTATIONAL-DESIGN.md` (the design).

A program gives a membership size, a constitution and, when one exists, an
aggregation for that constitution. The compiler checks the program and writes
two assay source files (section 8). Assay compiles the contract file to EVM
bytecode. Assay is the
host and the target (section 8).

The meaning of a program is the dependent pair of design section 2. The assay
file is a representation of that pair. The compiler is correct when each
entry of the assay file denotes the operation of design section 3. Kernel
evaluation of the prelude operations is the executable meaning. A test runs
one call sequence through kernel evaluation and through `assay run`, and
compares the two final states.

## 2. Programs

A program is one file of assay definitions (section 8):

```
def members : Nat := N
def NAME : TYPE := TERM
```

The first definition must be `members` with a literal. It fixes the number
of members. The core types `Config` and `Tally` (section 4) read it.

The compiler refuses these assay forms in a program: `mu`, `nu`, `axiom`,
`def rec`, `contract`, `storage`, `entry`, `payable`, `constructor`,
`fallback`, `error`, `invariant`, `predicate`, `proof`, `guard`, `sload` and
`sstore`. It also refuses a definition that uses a prelude name. Thus a
program cannot add a data type, an unproved fact or general recursion.
Recursion comes only from `fold` (O9 RULED). The compiler writes the
contract; a program cannot.

## 3. Type formers

The formers of ledger-lang `SPEC.md` section 3, in the assay forms that the
prelude (`prelude/Prelude.asy`) uses. USER ruling 2026-10-06 (O8) fixes the
equality and list rows.

| Type former | Forms |
|---|---|
| Core types | Section 4 of this file, and `Nat` |
| Product | `prod (A, B)`, `tuple (a, b)`, `t.0`, `t.1` |
| Coproduct | `Sum A B := sum (A, B)`, `inj k of 2 v`, `case` |
| Universal quantification | `(x : A) -> B`, `fun (x : A) (y : B) => t`, application |
| Existential quantification | `(x : A) * B`, `(a, b)` (built only, never projected, O10), or a `mu` record read by `match` |
| Type equality | `EqNat`, `EqDec`, `EqTally`: each a `mu` family with a fixed index type in `Type 0`, with `refl*`, `transport*`, `symm*`, `trans*`, `cong*`, and `congND` (Nat to Decision), `congTD` (Tally to Decision) |
| Universes | `Type 0` (`Type 1` only as the type of a type function) |

A constructor of a family takes its index explicitly (`reflNat 2`). A family
has no parameter: a constructor of a family with a parameter cannot appear
in a term (probe P2).

The same structures as ledger-lang `SPEC.md` section 4, with the carriers
that the design uses:

- **Monad**: `pure*`, `map*`, `bind*` on `Option`, `Sum E`, `Ballots` and
  `Claims`. `Option A := sum (prod (), A)` and `Sum A B := sum (A, B)` are
  generic type functions. Each list is one `mu` family per element type, so
  its `map` is an endomap and its `bind` stays in the family.
- **Algebra**: `foldBallots` and `foldClaims` (`def rec`, structural). There
  is no `unfold`: it has no structural measure (O9 RULED 2026-10-06). Built-in
  `Nat` has no eliminator, so there is no `fold` on `Nat` (probe-forced).
- **Filterable**: `filterOption`, `filterBallots`, `filterClaims`. A test is
  `A -> Option (prod ())`; leg 1 keeps, as leg 1 of `natEq` and `natLt` is
  true.

The ledger-lang carriers `Text`, `Values`, `Attrs` and `Value` are not types
of the design, so escrow-lang does not have them. `Claims` is the list of
the design (`claims : List Claim`). `Option` comes with the structures:
`filter` needs it. It is not a domain type.

One dependent form goes past the current ledger-lang build: a type that
depends on a value. `Aggregation F` depends on the constitution `F`, and
`amend` changes `F` (section 5). ledger-lang `SPEC.md` section 3 names this
form as later work. escrow-lang needs it in M0.

## 4. Core types

Each core type is in `Type 0`. The meaning column cites the design.

| Type | Meaning | Definition |
|---|---|---|
| `Nat` | the asset monoid `A` (pointwise N, section 2) and counts | built-in: literals, `natAdd`, `natSub`, `natEq`, `natLt` |
| `Address` | a payer or a payee | `Nat` (probe-forced: `credit` compares addresses with `natEq`) |
| `Decision` | the discrete category `D` (section 2) | `mu`: `release`, `refund`, `hold`; `decide B r f h d` |
| `Ballot` | the vote of one member | `Decision` |
| `Ballots` | a list of ballots | `mu`: `bnil`, `bcons` |
| `T3` | the count triple (release, refund, hold) | `prod (Nat, prod (Nat, Nat))` |
| `Config` | an object of `Obj`, one ballot per member | `mu` record `mkConfig (xs : Ballots) (e : EqNat (total (tallyOf xs)) members)`; field `ballots` (probe-forced, O10) |
| `Tally` | an orbit of `Obj` under member relabeling | `mu` record `mkTally (t : T3) (e : EqNat (total t) members)`; field `counts` (probe-forced, O10) |
| `ChoiceRule` | `F : Obj => D` | `Config -> Decision` |
| `Aggregation F` | `Aggregation act F` at discrete `D` (section 2) | `mu` family indexed by `F`: `mkAgg F L p` with `L : Tally -> Decision`, `p : (x : Config) -> EqDec (F x) (L (orbit x))`; field `rule F L` (probe-forced, O10) |
| `IsSelfConstituting F` | the fixed-point predicate (section 3) | `(L : Aggregation F) * ((x : Config) -> EqDec (gov F L x) (F x))` |
| `AmendmentRule` | `Phi` (section 3) | `(Tally -> Decision) -> ChoiceRule` |
| `Claim` | the triple `(p, q, n)` | `prod (Address, prod (Address, Nat))` |
| `Claims` | the claim list | `mu`: `cnil`, `ccons` |
| `Ledger` | `Address -> A` with finite support | `Address -> Nat`: `empty`, `balance`, `credit`, `debit` |
| `Escrow` | the escrow state `E` | `prod (Ledger, Claims)` |
| `EscrowDAO F` | the governed escrow `Sigma L. E` | `(L : Aggregation F) * Escrow` |

`Le n m` is the order of the monoid: `(k : Nat) * EqNat (natAdd n k) m`.
`debit l p n h` takes an erased proof `0 h : Le n (balance l p)`.
Subtraction in a cancellative monoid is defined only below the balance.

The prelude defines `tallyOf` (by `foldBallots`), `total` and `orbit :
Config -> Tally`. `Config` states `total (tallyOf xs) = members`, so
`orbit` reuses that proof: `orbit (mkConfig xs e) = mkTally (tallyOf xs) e`. A proof of `total (tallyOf xs) = length xs` for an open `xs`
is not possible: `natAdd` reduces only on literals (probe-forced). `orbit` is the orbit projection. The member relabeling group is the
symmetric group on `members`. Its orbits are tallies. This choice of `act` is
mine; the design keeps `act` abstract (open item O2).

### 4.1 The aggregation at a discrete decision space

At a discrete `D`, each unit component `F.X -> L.functor (orbit X)` is an
identity. So `L` agrees with `F` on each configuration, and `L` is fixed on
each orbit. `desc`, `fac` and `uniq` follow from the unit and from a section
of `orbit`. They are theorems, not data. Thus `Aggregation F` is the Sigma in
the table: an orbit rule `L` and a proof that `F` factors through it.

Three facts follow, and the prelude states them:

- `Aggregation F` has at most one inhabitant up to the values of `L`.
- `IsSelfConstituting F` holds exactly when `Aggregation F` has an
  inhabitant: `selfConstitutes F L := (L, fun x => symmDec (F x) (gov F L x) (cast F L x))`.
- `Aggregation F` has an inhabitant exactly when `F` is constant on orbits.

A constitution of the form `fun x => H (orbit x)` has the aggregation
`mkAgg F H (fun x => reflDec (H (orbit x)))`. A constitution that reads a member position has no
aggregation that a program can write. That program is in the
Arrow-impossibility regime.

The claim of section 4.1 is a design fact that the Lean side must prove. It
is not proved here (open item O1).

## 5. Core operations

Each operation has its design meaning and its homomorphism. `gov F L x` is
`rule F L (orbit x)`. `verdict F L x` is `gov F L x`. The types below use
the prelude names (section 4).

| Operation | Type | Meaning (design section 3) |
|---|---|---|
| `deposit p q n s` | `Address -> Address -> Nat -> Escrow -> Escrow` | `credit` on the ledger, append `(p, q, n)` to the claims, identity on `L` |
| `cast F L x` | `EqDec (F x) (gov F L x)` | the unit at `x`; the state does not change |
| `castOrbit F L x y e` | `EqTally (orbit x) (orbit y) -> EqDec (gov F L x) (gov F L y)` | two ballots in one orbit give one cast, by `congTD` |
| `settle F L x c s h` | `Escrow`, with `h : Le n (balance (ledger s) p)` | `decide` on `verdict F L x`: release debits `p` and credits `q`; refund debits `p`; hold gives `s` |
| `amend Phi F L` | `ChoiceRule` | `Phi (rule F L)` |
| `canonical` | `AmendmentRule` | `fun H x => H (orbit x)` |
| `homAmend F L x` | `EqDec (amend canonical F L x) (gov F L x)` | `reflDec` |
| `reconstitute F L` | `Aggregation (gov F L)` | `mkAgg (gov F L) (rule F L) (fun x => reflDec ..)` |

`settle` has a function type with `L` as an argument. When `Aggregation F`
has no inhabitant, no program can apply `settle`. This is the empty function
of design section 3.

`propose` has no form in M0. The configuration category is discrete, so the
only proposals are identities and `propose p ; q` is vacuous (design section
6).

## 6. Regimes

| Regime | `Aggregation F` | Compiled contract |
|---|---|---|
| Arrow-impossibility | no inhabitant | `deposit` only; `cast`, `settle` and `amend` each need `L` |
| Arrow-Debreu | one orbit rule | all four entries |
| Schelling-Ising | not reachable at a discrete `D` (section 4.1; USER ruling 2026-10-06) | not applicable |

## 7. What the compiler writes

The compiler writes one contract `EscrowDAO` in assay surface syntax.

The writer is `gen/contract.sh`. It implements O12 (b) using the local
Assay dependency in `toolchain/`: the base in `PIN` plus the recorded
surface-branch patch. Its input is the member count, the regime and, for
Arrow-Debreu, one decision code per tally from `gen/table.sh` (release 1,
refund 2, hold 3).

- `storage` holds the ledger as a mapping from address to word and the
  claims as a count and three mappings from index to payer, payee and
  amount.
- The orbit rule `witness L` compiles to two lookup mappings that only the
  constructor writes. It is the constitution code of design section 5.
  `weight` maps the ballot codes 1, 2 and 3 to 1, `members + 1` and 0, so
  the sum of the ballot weights is `r + (members + 1) f`, one key per
  tally. `verdict` maps the key to the decision code. Each ballot is
  guarded to be 1, 2 or 3.
- `deposit` is payable. It guards `n <= callvalue`, credits `p` and appends
  the claim. It returns the claim index.
- `cast` takes the ballots, computes the tally and returns the verdict. It
  writes nothing.
- `settle` takes a claim index and the ballots, computes the verdict, and
  branches to the release, refund or hold leg of design section 3. The
  proof `h` becomes the guard `n <= balance p` before the branch, including
  hold. A failed guard reverts.
- `amend` takes no argument at the canonical `Phi`. It returns the packed
  verdict table `sum C_i * 4^i` and writes nothing (open item O5).
- Proof terms erase. Each guard is checked and its witness is dropped.

## 8. Host and target

USER ruling 2026-10-06: escrow-lang is a restricted assay dialect. The facts
behind the ruling are in `probe/CAPABILITY.md`.

- The host is the assay kernel. It checks the dependent types of a program
  and evaluates its closed terms. escrow-lang has no checker of its own.
- The target is two `.asy` files (O11 RULED 2026-10-06; probe-forced by
  P6: `emit` checks each top-level definition). Assay has no import form,
  so the kernel file holds `def members : Nat := N`, the prelude, the
  program and the orbit table, in that order (probe-forced: the prelude
  reads `members`). The contract file is one assay surface `contract`
  with the storage, the entries and literal words only (P8 and O12).
- Assay has no implicit arguments, so each prelude name takes its type
  arguments explicitly (probe-forced).
- The prelude (`prelude/Prelude.asy`, eight `-- @section` parts) defines
  the forms of section 3 and the types and operations of sections 4 and 5
  (O8 RULED 2026-10-06): `EqNat`, `EqDec`, `EqTally`, `Decision`,
  `Ballots`, `Claims`, `Config`, `Tally` and `Aggregation` as `mu`
  families in `Type 0`, and `Option` and `Sum` as type functions over
  `sum (..)`. Only the prelude uses `mu` and `def rec`.
  `zsh prelude/assemble.sh PROGRAM` writes the target file in the order
  above. M0 results: `probe/CAPABILITY.md`, "M0 prelude and examples".
- The generator is a Bend 2 program, pinned to the assay commit in `PIN`.
  It reads a program, applies the refusal list of section 2, tabulates the
  orbit rule with the assay kernel (the packed code of P7), and writes the
  kernel file and the contract file. It runs `assay check` and `assay
  axioms` on both files and `assay emit` on the contract file.
- USER ruling 2026-10-06: `assay axioms` reports no axiom for the prelude
  and the program. For the contract file it reports only `EvmOpcodes`, the
  marker of the assay core protocol that `emit` requires (`M0_PROTOCOL`;
  `probe/CAPABILITY.md`, P1). The assay kernel accepts an axiom witness, so
  this check is the generator's job.

## 9. Open items

- O1. Prove section 4.1 in Lean against `self-referential-dao` and UAT: at a
  discrete `D`, `Aggregation act F` is equivalent to the Sigma of section 4.
- O2. `act` is the symmetric group on members. The design and the DAO
  example (a `Z2` flip on spins) keep `act` general.
- O3. RULED 2026-10-06: `D` stays discrete and the Schelling-Ising row is
  not reachable. The DAO repository finds its fork in the indiscrete target
  `MagPhase`, not a discrete one.
- O4. `settle` does not remove `c` from the claims and does not require `c`
  to be in the claims. One claim can settle two times while the payer
  balance covers it.
- O5. At a discrete `D`, `gov F L` agrees with `F` on each configuration.
  The canonical `amend` therefore changes no verdict. The design section 5
  sketch writes `beta` in `amend`, which changes `F` and is not `gov`.
- O6. The design section 5 sketch reverts `settle` unless the verdict is
  release. Design section 3 debits on refund and does nothing on hold. The
  compiler follows section 3.
- O7. No design operation sends funds out of the contract. Refund removes
  `n` from the ledger with no recipient, and release credits `q` with no
  withdrawal.
- O8. RULED 2026-10-06: the USER accepted the proposal below. Probe P2: a
  constructor of a `mu` family with a parameter cannot
  appear in a term, and a family with a type index lives in `Type 1` and
  its `match` cannot use a function on the outer type. Thus `Eq A x y`,
  `List A` and `Option A` of section 3 cannot be written as planned.
  Proposal: `EqNat`, `EqDec` and `EqTally` (one family per index type),
  `Ballots` and `Claims` (one list family per element type), and `Option A`
  and `Sum A B` over the built-in `sum`. The generic `Monad`, `fold`,
  `unfold` and `filter` on `List` become one set per list family.
- O9. `unfold` has no structural measure. Built-in `Nat` has no
  eliminator, so fuel cannot be a `Nat`, and the prelude invents no fuel.
  The prelude has no `unfold`. RULED 2026-10-06 (USER): drop `unfold`.
  Recursion comes only from `fold` (section 2).
- O10. Probe-forced (M0, 2026-10-06): the assay kernel refuses
  `fun (s : S) => (s.1, s.2)` for `S := (n : Nat) * EqNat n 3`. The type
  of `s.2` holds `s.1` without a return annotation, a written `s.1` holds
  it with `as self return Nat`, and conversion does not identify the two.
  Assay has no Sigma pattern (`match`, `case` and `let` on a pair do not
  parse). Thus `Config`, `Tally` and `Aggregation F` are `mu` records read
  by `match`, and the Sigma forms that stay (`IsSelfConstituting`,
  `EscrowDAO`, `Le`) are built and never projected. RULED 2026-10-06
  (USER): keep the `mu` records. Assay does not change.
- O11. Probe-forced (M1, P6 in `probe/CAPABILITY.md`): `emit` checks each
  top-level definition, and it refuses prelude section 7 and the program
  scenario. Thus the target is two files, not the one file of section 8: a
  kernel file (members line, prelude, program and orbit table) for `check`
  and `axioms`, and a contract file (protocol, storage, entries and literal
  words only) for `check`, `axioms` and `emit`. RULED 2026-10-06 (USER):
  two files. The table comes from the kernel file by the packed code of
  P7. The second `reflNat` check certifies it.
- O12. Found in M1 (2026-10-06, document read, not ruled;
  `probe/CAPABILITY.md`, "M1 contract form"): the assay surface form has
  mappings with runtime keys and no two-way branch. The core `Tx` protocol
  has the `le` branch and only constant slots. Section 7 needs both.
  Options: (a) probe P8 first: a core `le` term in a surface body; (b) an
  assay change that adds a surface branch (the assay tree has work in
  flight); (c) a ledger of constant slots, one per address in a fixed
  address set, in the core protocol. P8 FAILED (2026-10-06,
  `probe/CAPABILITY.md`, P8): a surface body has no core term and no
  branch. The staged writer uses (d), a surface contract with no branch
  (section 7): the constructor writes two lookup mappings for the tally,
  and `settle` is three entries, one per decision, each guarding its
  decision. RULED 2026-10-06 (USER): (b). Assay gets a surface branch
  statement that lowers to the core `le a b yes no`, and `settle` becomes
  one entry with the case split of design section 3. The (d) writer is
  the interim form until the assay branch lands. The implementation now
  carries the surface branch as an escrow-local dependency patch, builds
  only in `.tools/assay`, and emits one `settle` entry. No sibling checkout
  is modified. The tally lookups need no
  branch and can stay. The validated Arrow-Debreu range is `members <= 8`.
  In the interim writer, 9 members hit the closed-specialization budget; at 10,
  the mapping writes also exceed the 128-step constructor limit. This
  bound keeps the packed `amend` table within one word. Zero members is
  valid: its only tally is `(0, 0, 0)` and `cast` has no arguments.

## 10. Milestones

- M0: probe items P1 to P4; the prelude with the formers, core types and
  the four operations; the refusal list; example programs for the
  Arrow-impossibility and Arrow-Debreu regimes, checked by `assay check`.
- M1: the generator and the contract writer (section 7); differential
  tests of kernel evaluation against `assay run` traces. Status
  2026-10-06: probes P6, P7 and P8 are done (`probe/CAPABILITY.md`, O11,
  O12). The contract writer (`gen/contract.sh`) and the table step
  (`gen/table.sh`) are written. Both regimes pass `check`, `axioms` and
  `emit` at members 3. O12 (b) is now carried as a local compiler patch
  and `settle` is one entry. `test/settlement.py` checks model and emitted
  EVM behavior against independent expectations. Status 2026-10-07:
  `test/differential.py` compares dependent kernel evaluation with the
  contract. The kernel evaluates the rule `F` of the Arrow-Debreu example
  on all 27 ballot vectors at members 3. Three runs with a wrong candidate
  give the values as hints, and one kernel file checks all 27 values with
  `reflNat`. The contract takes its tables from its own constructor run.
  Then `cast` and `settle` run in the Assay model and in geth, and each
  result must equal the kernel value. A contract with one wrong table code
  fails the test. The Bend 2 generator and the refusal test are not
  started.
- M2: open items O4 and O7, after a ruling.
