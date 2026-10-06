# escrow-lang specification (draft)

Status: draft before milestone M0. `escrow-lang` is a working name.

## 1. Purpose

escrow-lang is a language for one governed escrow. Its type formers are the
type formers of ledger-lang. Its core data types and core operations are only
the types and operations of `design/DENOTATIONAL-DESIGN.md` (the design).

A program gives a membership size, a constitution and, when one exists, an
aggregation for that constitution. The compiler checks the program and writes
one assay source file. Assay compiles that file to EVM bytecode. Assay is the
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
Recursion comes only from `fold` and `unfold`. The compiler writes the
contract; a program cannot.

## 3. Type formers

The same formers as ledger-lang `SPEC.md` section 3:

| Type former | Forms |
|---|---|
| Core types | Section 4 of this file, and `Nat` |
| Product | `Prod A B`, `pair`, `first`, `second` |
| Coproduct | `Sum A B`, `inl`, `inr`, `either` |
| Universal quantification | `(x : A) -> B`, `fun (x : A) => t`, application |
| Existential quantification | `Sigma A B`, `pack`, `witness`, `payload` |
| Type equality | `Eq A x y`, `refl`, `transport`, `symm`, `trans`, `cong` |
| Universes | `Type 0`, `Type 1` |

The same structures as ledger-lang `SPEC.md` section 4, with the carriers
that the design uses:

- **Monad**: `pure`, `map`, `bind` on `Option`, `List` and `Sum E`.
- **Algebra**: `fold` and `unfold` on `Nat` and `List A`.
- **Filterable**: `filter` on `Option` and `List`.

The ledger-lang carriers `Text`, `Values`, `Attrs` and `Value` are not types
of the design, so escrow-lang does not have them. `List` is a type of the
design (`claims : List Claim`). `Option` comes with the structures: `unfold`
and `filter` need it. It is not a domain type.

One dependent form goes past the current ledger-lang build: a type that
depends on a value. `Aggregation F` depends on the constitution `F`, and
`amend` changes `F` (section 5). ledger-lang `SPEC.md` section 3 names this
form as later work. escrow-lang needs it in M0.

## 4. Core types

Each core type is in `Type 0`. The meaning column cites the design.

| Type | Meaning | Definition |
|---|---|---|
| `Nat` | the asset monoid `A` (pointwise N, section 2) and counts | primitive: `zero`, `succ`, `add` |
| `Address` | a payer or a payee | primitive, no operations |
| `Decision` | the discrete category `D` (section 2) | primitive: `release`, `refund`, `hold`, `decide r f h d` |
| `Ballot` | the vote of one member | `Decision` |
| `Config` | an object of `Obj`, one ballot per member | `Sigma (List Ballot) (fun xs => Eq Nat (length xs) members)` |
| `Tally` | an orbit of `Obj` under member relabeling | `Sigma (Prod Nat (Prod Nat Nat)) (fun t => Eq Nat (total t) members)` |
| `ChoiceRule` | `F : Obj => D` | `(x : Config) -> Decision` |
| `Aggregation F` | `Aggregation act F` at discrete `D` (section 2) | `Sigma ((t : Tally) -> Decision) (fun L => (x : Config) -> Eq Decision (F x) (L (orbit x)))` |
| `IsSelfConstituting F` | the fixed-point predicate (section 3) | `Sigma (Aggregation F) (fun L => (x : Config) -> Eq Decision (gov F L x) (F x))` |
| `AmendmentRule` | `Phi` (section 3) | `(H : (t : Tally) -> Decision) -> ChoiceRule` |
| `Claim` | the triple `(p, q, n)` | `Prod Address (Prod Address Nat)` |
| `Ledger` | `Address -> A` with finite support | primitive: `empty`, `balance`, `credit`, `debit` |
| `Escrow` | the escrow state `E` | `Prod Ledger (List Claim)` |
| `EscrowDAO F` | the governed escrow `Sigma L. E` | `Sigma (Aggregation F) (fun L => Escrow)` |

`Le n m` is the order of the monoid: `Sigma Nat (fun k => Eq Nat (add n k) m)`.
`debit l p n` takes a proof of `Le n (balance l p)`. Subtraction in a
cancellative monoid is defined only below the balance.

The prelude defines `length`, `total` and `orbit : Config -> Tally` with
`fold`. `orbit` is the orbit projection. The member relabeling group is the
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
  inhabitant: `selfConstitutes F L := pack L (fun x => symm (payload L x))`.
- `Aggregation F` has an inhabitant exactly when `F` is constant on orbits.

A constitution of the form `fun x => H (orbit x)` has the aggregation
`pack H (fun x => refl)`. A constitution that reads a member position has no
aggregation that a program can write. That program is in the
Arrow-impossibility regime.

The claim of section 4.1 is a design fact that the Lean side must prove. It
is not proved here (open item O1).

## 5. Core operations

Each operation has its design meaning and its homomorphism. `gov F L x` is
`witness L (orbit x)`. `verdict F L x` is `gov F L x`.

| Operation | Type | Meaning (design section 3) |
|---|---|---|
| `deposit p q n s` | `Address -> Address -> Nat -> Escrow -> Escrow` | `credit` on the ledger, append `(p, q, n)` to the claims, identity on `L` |
| `cast F L x` | `Eq Decision (F x) (gov F L x)` | the unit at `x`; the state does not change |
| `castOrbit F L x y e` | `Eq Tally (orbit x) (orbit y) -> Eq Decision (gov F L x) (gov F L y)` | two ballots in one orbit give one cast, by `cong` |
| `settle F L x c s h` | `Escrow`, with `h : Le n (balance (ledger s) p)` | `decide` on `verdict F L x`: release debits `p` and credits `q`; refund debits `p`; hold gives `s` |
| `amend Phi F L` | `ChoiceRule` | `Phi (witness L)` |
| `canonical` | `AmendmentRule` | `fun H x => H (orbit x)` |
| `homAmend F L x` | `Eq Decision (amend canonical F L x) (gov F L x)` | `refl` |
| `reconstitute F L` | `Aggregation (gov F L)` | `pack (witness L) (fun x => refl)` |

`settle` has a function type with `L` as an argument. When `Aggregation F`
has no inhabitant, no program can apply `settle`. This is the empty function
of design section 3.

`propose` has no form in M0. The configuration category is discrete, so the
only proposals are identities and `propose p ; q` is vacuous (design section
6).

## 6. Regimes

| Regime | `Aggregation F` | Compiled contract |
|---|---|---|
| Arrow-impossibility | no inhabitant | `deposit` and `cast` only; no `settle`, no `amend` |
| Arrow-Debreu | one orbit rule | all four entries |
| Schelling-Ising | not reachable at a discrete `D` (section 4.1; USER ruling 2026-10-06) | not applicable |

## 7. What the compiler writes

The compiler writes one contract `EscrowDAO` in assay surface syntax.

- `storage` holds the ledger as a mapping from address to word and the
  claims as a count and a mapping from index to a packed claim.
- The orbit rule `witness L` compiles to an assay function from three tally
  words to a decision word. It is the constitution code of design section 5.
- `deposit` is payable. It guards `n <= callvalue`, credits `p` and appends
  the claim.
- `cast` takes the ballots, computes the tally and returns the verdict. It
  writes nothing.
- `settle` takes a claim and the ballots. It computes the verdict, then does
  the case split of design section 3. The proof `h` becomes the guard
  `n <= balance p`. A failed guard reverts.
- `amend` takes no argument at the canonical `Phi`. It returns the verdict
  table and writes nothing (open item O5).
- Proof terms erase. Each guard is checked and its witness is dropped.

## 8. Host and target

USER ruling 2026-10-06: escrow-lang is a restricted assay dialect. The facts
behind the ruling are in `probe/CAPABILITY.md`.

- The host is the assay kernel. It checks the dependent types of a program
  and evaluates its closed terms. escrow-lang has no checker of its own.
- The target is one `.asy` file. Assay has no import form, so the file
  holds the prelude, the program and the contract, in that order.
- The prelude (`prelude/Prelude.asy`) defines the ledger-lang names of
  section 3 over the assay forms: `Prod` over `prod(..)`, `Sum` over
  `sum(..)`, `Sigma` over `(x : A) * B`, Pi as assay Pi, and `Eq`, `List`,
  `Option` and `Decision` as `mu` families in `Type 0`. Only the prelude
  uses `mu` and `def rec`.
- The generator is a Bend 2 program, pinned to the assay commit in `PIN`.
  It reads a program, applies the refusal list of section 2, tabulates the
  orbit rule with the assay kernel, writes the `.asy` file and runs
  `assay check`, `assay axioms` and `assay emit`.
- `assay axioms` must report no axiom. The assay kernel accepts an axiom
  witness, so this check is the generator's job.

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

## 10. Milestones

- M0: probe items P1 to P4; the prelude with the formers, core types and
  the four operations; the refusal list; example programs for the
  Arrow-impossibility and Arrow-Debreu regimes, checked by `assay check`.
- M1: the generator and the contract writer (section 7); differential
  tests of kernel evaluation against `assay run` traces.
- M2: open items O4 and O7, after a ruling.
