# escrow-lang specification (draft)

Status: draft, milestone M4 (ballots on chain, all three chunks done; section 10).
`escrow-lang` is a working name.

## 1. Purpose

escrow-lang is a language for one governed escrow. Its type formers are the
type formers of ledger-lang. Its core data types and core operations are only
the types and operations of `design/DENOTATIONAL-DESIGN.md` (the design).

A program gives a membership size, a constitution and, when one exists, an
aggregation for that constitution. The compiler `escrowc` checks the program
and writes the EVM bytecode of one contract (section 7). `escrowc` is the
host, and it writes the target directly (section 8).

The meaning of a program is the dependent pair of design section 2. The
contract is a representation of that pair. The compiler is correct when each
contract entry denotes the operation of design section 3. Evaluation of the
prelude operations by the checker is the executable meaning.
`test/differential.py` runs each ballot vector through `escrowc verdicts`
and through the contract in geth, and compares the results. For each
vector, members submit their ballots through `vote`. The script compares
the geth storage after `settle`, apart from the ballots word, with `escrowc
eval` of source `settle` on the same claim. The Python model `settled()`
is a cross-check.

## 2. Programs

A program is one `.esc` file of definitions in the subset of assay syntax
that the prelude uses (section 8):

```
def members : Nat := N
def NAME : TYPE := TERM
```

The first definition must be `members` with a positive integer literal no
larger than C's `UINT_MAX`, otherwise `REFUSE_MEMBERS`.
It fixes the number of members. The core types `Config` and `Tally`
(section 4) read it. `escrowc` checks `members` first, then the prelude,
then the rest of the program.

To build Arrow-Debreu, a program must declare `memberAddresses : Addresses`,
otherwise `build` refuses with `REFUSE_ADDRESSES`. When declared, the list
is checked in both regimes: one address per member (`REFUSE_ADDRESS_COUNT`),
each below 2^160 (`REFUSE_ADDRESS_RANGE`), with no repeated address
(`REFUSE_ADDRESS_REPEAT`). Arrow-impossibility may omit it.

`escrowc` refuses these forms in a program: `mu` (`REFUSE_MU`), `def rec`
(`REFUSE_REC`), and `nu`, `axiom`, `contract`, `storage`, `entry`,
`payable`, `constructor`, `fallback`, `error`, `invariant`, `predicate`,
`proof`, `guard`, `sload` and `sstore` (`REFUSE_FORM`). It also refuses a
definition that uses a prelude name (`REFUSE_PRELUDE_NAME`). Thus a program
cannot add a data type, an unproved fact or general recursion. Recursion
comes only from `fold` (O9 RULED). The compiler writes the contract; a
program cannot.

A program that does not check is refused with a `TYPE_` code: `TYPE_SCOPE`,
`TYPE_DUPLICATE`, `TYPE_MISMATCH`, `TYPE_INFER`, `TYPE_SHAPE`,
`TYPE_UNIVERSE`, `TYPE_ERASED`, `TYPE_MATCH`, `TYPE_MU`, `TYPE_REC`,
`TYPE_NAT`, `TYPE_FUEL` or `TYPE_INTERNAL`. A mismatch prints both normal
forms (` expected E, found F`). The lexer and parser codes are `LEX_TOKEN`,
`LEX_NUMBER`, `PARSE_EXPECT`, `PARSE_PAREN`, `PARSE_ARITY`, `PARSE_DEPTH`
and `MEMORY`. A refusal is one line on stderr, `escrowc: CODE: DEF:
message`, and exit 1. A usage or IO error exits 2. `test/refusal.sh` and
the mutant in `test/mutants/` test the refusals.

## 3. Type formers

The formers of ledger-lang `SPEC.md` section 3, in the assay forms that the
prelude (`prelude/Prelude.esc`) uses. USER ruling 2026-10-06 (O8) fixes the
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
| `Address` | a payer or a payee | `Nat` (probe-forced: `add` and `sub` compare addresses with `natEq`) |
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
| `Ledger` | `Address -> A` with finite support | `Address -> Nat`: `empty`, `balance`, `add`, `sub` |
| `Closed` | the closed flag at each stable claim index | `Nat -> Nat`: `allOpen`, `close` |
| `Escrow` | the escrow state `E` | `prod (Ledger, prod (Ledger, prod (Claims, Closed)))`; accessors `ledger`, `credit`, `claims`, `closed` |
| `EscrowDAO F` | the governed escrow `Sigma L. E` | `(L : Aggregation F) * Escrow` |

`Le n m` is the order of the monoid: `(k : Nat) * EqNat (natAdd n k) m`.
`Lt n m` is `Le (natAdd n 1) m`.
`sub l p n h` takes an erased proof `0 h : Le n (balance l p)`.
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
the prelude names (section 4). In the settlement row, `(p, q, n)` is the
claim at index `c`, obtained by `claimAt (claims s) c`.

| Operation | Type | Meaning (design section 3) |
|---|---|---|
| `deposit p q n s` | `Address -> Address -> Nat -> Escrow -> Escrow` | `add` on the ledger, append `(p, q, n)` to the claims, preserve credit and closed flags, identity on `L` |
| `cast F L x` | `EqDec (F x) (gov F L x)` | the unit at `x`; the state does not change |
| `castOrbit F L x y e` | `EqTally (orbit x) (orbit y) -> EqDec (gov F L x) (gov F L y)` | two ballots in one orbit give one cast, by `congTD` |
| `settle F L x c s hc ho h` | `Escrow`, with `c : Nat`, erased `hc : Lt c (claimCount (claims s))`, `ho : EqNat (closed s c) 0`, `h : Le n (balance (ledger s) p)` | `decide` on `verdict F L x`: release subtracts `n` from the ledger of `p`, adds it to the credit of `q` and closes `c`; refund adds it to the credit of `p` instead; hold gives `s` |
| `withdraw a n s h` | `Escrow`, with erased `h : Le n (balance (credit s) a)` | `sub` of `n` from the credit of `a`; the ledger, the claims and the closed flags do not change; identity on `L`. The source has no wei, so the send and the recipient context of design section 3 are not modeled |
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
| Arrow-Debreu | one orbit rule | all six entries, including `vote` and `withdraw` |
| Schelling-Ising | not reachable at a discrete `D` (section 4.1; USER ruling 2026-10-06) | not applicable |

## 7. What the compiler writes

`escrowc build PROG -o OUT` writes the creation code of one contract, and
`escrowc build PROG --runtime -o OUT` writes its runtime code, each as one
line of lowercase hex with no `0x`. The writer is `src/evm.c` (interface
`src/evm.h`). Its input is the member count, the regime (section 6) and,
for Arrow-Debreu, one decision code per tally from the checker (`escrowc
table`; release 1, refund 2, hold 3; tallies in the order r = 0..n outer,
f = 0..n-r inner, h = n-r-f).
The Arrow-Debreu input also includes the checked member addresses, in
list order. The writer embeds them in `vote` and refuses absent, repeated
or out-of-range addresses with `EVM_ADDRESSES`.

The Arrow-Debreu writer accepts 1 to 14 members (`EVM_LIMIT` outside that
range). The Arrow-impossibility writer has no verdict table and no
14-member limit; it accepts the member range of section 2.

- The creation code reverts on a call value and returns the runtime. It
  writes no storage.
- Storage slot 0 is the ledger, a mapping from address to word. The claims
  are a count (slot 1) and three mappings from index to payer (slot 2),
  payee (slot 3) and amount (slot 4). Slot 5 is the credit, a mapping from
  address to the word that the address can withdraw (O7). Slot 6 maps an
  index to its closed flag: 1 is closed and 0 is open (O4). Slot 7 maps a
  claim index to its ballots word: 2 bits per member, member `m` at `4^m`,
  and 0 means no ballot (O13). A mapping slot is keccak256 of the key word
  and the base slot word.
- Each selector is keccak256 of the signature with `uint256` words, which
  `escrowc` computes when it writes the code. Short calldata and an unknown
  selector revert.
- The orbit rule `witness L` is the verdict table, data in the runtime code
  that `CODECOPY` reads. It is the constitution code of design section 5.
  Each ballot must be 1, 2 or 3, else the call reverts. The counts r of
  release and f of refund give the tally index.
- `deposit(p, q, n)` is payable. It guards `n <= callvalue` and that `p`
  and `q` are addresses, credits `n` to `p` with an overflow guard, and
  appends the claim. It returns the claim index.
- `cast(b1, ..., bn)` computes the tally and returns the verdict. It writes
  nothing.
- `vote(c, b)` is nonpayable. It reverts unless the caller is a member,
  `c < claimCount`, claim `c` is open and `b` is 1, 2 or 3. It replaces
  that member's field in the ballots word of claim `c` and returns the
  new word. Votes on other claims and fields stay unchanged.
- `settle(c)` reads the stored ballots, computes the verdict and branches to the
  release, refund or hold leg of design section 3. Before the branch, it
  reverts unless `c` is less than the claim count and claim `c` is open
  (O4), and all members have voted on that claim (O13). Any caller may
  settle. Then the proof `h` becomes the guard `n <= ledger p`, including
  hold. Release moves `n` from the ledger of `p` to the credit of `q`, and
  refund moves `n` from the ledger of `p` to the credit of `p` (O7). Each
  credit add has an overflow guard. Release and refund close claim `c`.
  Hold writes nothing, so the claim stays open and a later `settle` can
  decide it. Stored ballots stay after every verdict. It returns the
  verdict. A failed guard reverts.
  The source operation still takes an explicit configuration `x` (section 5).
  The contract adapter retains the pending configurations in addition to the
  core escrow state; `vote` changes that context. See design sections 2 and 3
  for its meaning and the core projection.
- `amend()` takes no argument at the canonical `Phi`. It returns the packed
  verdict table `sum C_i * 4^i` and writes nothing (O5).
- `withdraw(n)` guards `n <= credit caller`, debits `n` from the credit of
  the caller first, then calls the caller with `n` wei and all the gas. A
  failed call reverts, so the credit does not change. It reads the credit
  of the caller again after the call and returns it (O7), so the result
  includes both withdrawals and settlement credits made during the call. A
  recipient that reverts cannot block `settle`, because `settle` sends no
  funds.
- `cast`, `vote`, `settle`, `amend` and `withdraw` revert on a call value.
  At Arrow-impossibility the contract has no verdict table or member
  addresses, and only `deposit` is present: all other calls revert and
  deposits stay in the contract (design section 4).
- Proof terms erase. Each guard is checked and its witness is dropped.

## 8. Host and target

USER rulings 2026-10-07 replace the assay host of 2026-10-06. The host
facts are in `probe/CAPABILITY.md`.

1. The host is TinyCC. `escrowc` is C99, built with tcc 0.9.28rc, and it
   does the dependent checking and evaluation that the assay kernel did.
2. The surface is the current subset of assay syntax. Both example
   programs check unchanged. The suffix is `.esc`.
3. The target is EVM bytecode that `escrowc` writes directly. The assay
   toolchain is not in the tree.

- The checker (`src/check.c`) checks by normalization: Pi, Sigma, `*`
  products, `sum` and `case`, fixed-index `mu` families with `match`,
  structural `def rec`, `Type 0` and `Type 1`, erased binders and the
  `Nat` builtins on literals. Conversion compares normal forms.
- The prelude (`prelude/Prelude.esc`, eight `-- @section` parts) defines
  the forms of section 3 and the types and operations of sections 4 and 5
  (O8 RULED 2026-10-06): `EqNat`, `EqDec`, `EqTally`, `Decision`,
  `Ballots`, `Claims`, `Config`, `Tally` and `Aggregation` as `mu`
  families in `Type 0`, and `Option` and `Sum` as type functions over
  `sum (..)`. Only the prelude uses `mu` and `def rec`. `make` embeds the
  prelude in `escrowc` (`tools/embed.c` writes `build/prelude.c`).
- The surface has no implicit arguments, so each prelude name takes its
  type arguments explicitly.
- The regime is Arrow-Debreu if and only if the program defines
  `agg : Aggregation G` for a program definition `G : ChoiceRule`.
- The command line:
  - `escrowc check PROG` prints `ok debreu` or `ok impossibility`.
  - `escrowc table PROG` prints `REGIME MEMBERS [CODES...]` on one line.
    Arrow-Debreu tables are limited to 1000 members (`TABLE_LIMIT`).
  - `escrowc verdicts PROG NAME` prints one digit per ballot vector of the
    rule NAME, in the product order of `test/differential.py` (the first
    ballot outermost), up to 10 members (`VERDICT_LIMIT`).
  - `escrowc eval PROG NAME` prints the normal form of NAME.
  - `escrowc build PROG [--runtime] -o OUT` writes the contract (section 7).
- The surface has no axiom form that a program can use (section 2), so a
  checked program has no unproved fact.

## 9. Open items

- O1. Prove section 4.1 in Lean against `self-referential-dao` and UAT: at a
  discrete `D`, `Aggregation act F` is equivalent to the Sigma of section 4.
- O2. `act` is the symmetric group on members. The design and the DAO
  example (a `Z2` flip on spins) keep `act` general.
- O3. RULED 2026-10-06: `D` stays discrete and the Schelling-Ising row is
  not reachable. The DAO repository finds its fork in the indiscrete target
  `MagPhase`, not a discrete one.
- O4. RULED 2026-10-07 (USER): `settle` closes the claim on release and
  refund. `settle c` reverts unless `c < claimCount` and claim `c` is
  open. Release and refund close the claim. Hold leaves the claim open, so
  a later `settle` can decide it. Design section 3 gets `claims -= c` on
  the release and refund legs. Before the ruling, `settle` did not remove
  `c` from the claims and did not require `c` to be in the claims, so one
  claim could settle two times while the payer balance covered it. M3
  built the ruling in chunks 1 to 4 (section 10).
- O5. CLOSED 2026-10-08 by M4 chunk 3. At a discrete `D`, `gov F L` agrees
  with `F` on each configuration. The canonical `amend` therefore changes
  no verdict. The old design section 5 sketch wrote `beta` in `amend`,
  which changes `F` and is not `gov`. Now the sketch follows section 7:
  `amend` returns the packed verdict table and writes nothing.
- O6. CLOSED 2026-10-08 by M4 chunk 3. The old design section 5 sketch
  reverted `settle` unless the verdict was release. Design section 3
  debits on refund and does nothing on hold, and the compiler follows
  section 3. Now the sketch settles the claim index `c` with the release,
  refund and hold legs of section 3.
- O7. RULED 2026-10-07 (USER): pull payments. Release moves `n` from the
  ledger of `p` to a withdrawable credit of `q`. Refund moves `n` from the
  ledger of `p` to a credit of `p`. A new nonpayable entry `withdraw(n)`
  first debits `n` from the credit of the caller, then sends `n` wei to
  the caller. A failed send reverts. A recipient that reverts cannot block
  `settle`. Before the ruling, no design operation sent funds out of the
  contract: refund removed `n` from the ledger with no recipient, and
  release credited `q` with no withdrawal. M3 built the ruling in chunks 1
  to 4 (section 10).
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
- O10. Probe-forced (M0, 2026-10-06): the assay kernel refused
  `fun (s : S) => (s.1, s.2)` for `S := (n : Nat) * EqNat n 3`, and assay
  has no Sigma pattern. Thus `Config`, `Tally` and `Aggregation F` are `mu`
  records read by `match`, and the Sigma forms that stay
  (`IsSelfConstituting`, `EscrowDAO`, `Le`) are built and never projected.
  RULED 2026-10-06 (USER): keep the `mu` records. The TinyCC host keeps
  them (section 8, ruling 2: the programs check unchanged).
- O11. CLOSED 2026-10-07 by the TinyCC host (section 8). The assay target
  was two `.asy` files, a kernel file and a contract file (RULED
  2026-10-06), because `emit` checked each top-level definition. `escrowc`
  checks the program and writes the bytecode in one run, and the verdict
  table comes from the checker (`escrowc table`).
- O12. CLOSED 2026-10-07 by the TinyCC host (section 8). The assay surface
  form had no two-way branch, so O12 (b) carried a local assay patch for a
  surface branch. `src/evm.c` writes the branch of `settle` directly, as
  one entry with the case split of design section 3. The Arrow-Debreu range
  is now members 1 to 14 (section 7, `probe/CAPABILITY.md`). All commands
  refuse zero members during program checking (`REFUSE_MEMBERS`). The assay
  text of O11 and O12 is in `git show 8351635:SPEC.md`.
- O13. RULED 2026-10-08 (USER): ballots on chain. An Arrow-Debreu program
  declares `def memberAddresses : Addresses := ...` in its source. An
  Arrow-impossibility program may omit this declaration; when
  present, it is checked the same way and writes no contract data. The
  checker refuses a declaration unless there is one address per member,
  each address is below 2^160 and no address repeats. A new nonpayable entry
  `vote(c, b)`
  records the ballot `b` of the caller on claim `c`. It reverts unless the
  caller is a member, `c < claimCount`, claim `c` is open (O4) and `b` is
  1, 2 or 3. A member can change its ballot while the claim is open. Slot 7
  maps a claim index
  to a packed word with 2 bits per member (member `m` at `4^m`), and 0 is no
  ballot. `settle(c)` takes no ballots. It keeps the checks on claim index,
  open status and payer balance of section 7 and also reverts unless all
  `n` ballots of claim `c` are present. Any caller can settle.
  `cast(b1, ..., bn)` stays the pure
  tally of design section 3. The Arrow-impossibility contract gets no
  `vote`. The prelude has no model of the votes: on chain, the `Config` of
  source `settle` is the stored ballots. Before M4, `cast` and `settle`
  read the ballots from calldata and the contract had no member addresses.
  Thus any caller of `settle` could pick the verdict, for example a payee
  sending `n` release ballots. M4 built the ruling in chunks 1 to 3
  (section 10).


## 10. Milestones

- M0 (2026-10-06): probe items P1 to P4; the prelude with the formers, core
  types and the four operations; the refusal list; the example programs
  for the Arrow-impossibility and Arrow-Debreu regimes, checked then by the
  assay kernel.
- M1 (2026-10-06 to 2026-10-07): the assay contract writer and the
  differential test against `assay run` (O11, O12). M2 replaces it.
- M2 (2026-10-07): the TinyCC host (section 8) in four chunks. (1) The EVM
  back end `src/evm.c` and `test/settlement.py` (60 cases in geth). (2)
  The lexer, the parser and the embedded prelude, with `test/parse.sh`.
  (3) The checker and the `check`, `table`, `verdicts`, `eval` and `build`
  verbs, with `test/check.sh`, `test/refusal.sh`, `test/normal-forms.py`
  and the mutant `test/mutants/debreu-payee-4.esc`. (4)
  `test/differential.py`: `escrowc verdicts PROG F` on all 27 ballot
  vectors at members 3 against `cast` and `settle` in geth, and `escrowc
  table` against `amend`. The assay toolchain, generator and probes leave
  the tree. Gates: `make`, `make check-clang`, `make test`, `python3
  test/settlement.py` and `python3 test/differential.py`.
- M3: O4 and O7 as RULED 2026-10-07 (section 9), in four chunks. All four
  are done (2026-10-07 to 2026-10-08). (1) O4: `settle` checks the claim
  index and closes the claim. (2) O7: the credit and `withdraw`, with
  `test/settlement.py` at 87 cases in geth. (3) Design section 3 and the
  documents. Chunks 1 to 3 change only the EVM writer, its tests and the
  documents. (4) The source prelude and the example programs model O4
  and O7: `settle` by stable claim index with the erased premises `hc`,
  `ho` and `h` (section 5), source `withdraw` on the credit, and
  `test/differential.py` compares the geth storage after `settle` with
  `escrowc eval` of source `settle`. Chunk 4 changes no EVM code. `make
  test` gives 97 ok.
- M4: O13 as RULED 2026-10-08 (section 9), ballots on chain, in three
  chunks. All three are done (2026-10-08). The ruling comes with the three
  refusal mutants `test/mutants/debreu-first.esc`,
  `impossibility-agg-release.esc` and `impossibility-agg-refl.esc` (a
  constitution or `mkAgg` built on the rule `first`), so `make test` gives
  100 ok before chunk 1. (1) The checker validates `memberAddresses`
  (`REFUSE_ADDRESS_COUNT`, `REFUSE_ADDRESS_RANGE`,
  `REFUSE_ADDRESS_REPEAT`), and `build` requires them for Arrow-Debreu
  (`REFUSE_ADDRESSES`). (2) The EVM writer embeds the addresses
  (`EVM_ADDRESSES`), adds `vote` and makes `settle(c)` read the ballots of
  claim `c` from slot 7. `test/settlement.py` runs 131 cases in geth,
  including 1 and 14 members. `test/differential.py` sends one `vote` from
  each member and then `settle(0)`, and compares all 27 default vectors
  against source `settle`. Chunk 2 also updated section 7. (3) The
  documents: this section, design sections 3 and 5 (O5 and O6 CLOSED) and
  `probe/CAPABILITY.md`.
  `make test` gives 106 ok.
