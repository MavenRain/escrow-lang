The design below is in Conal Elliott's sense: a simple mathematical meaning is fixed first, a representation is chosen second, and every operation is required to be a homomorphism for a total meaning function \(\llbracket\cdot\rrbracket\). Assay is the representation language. The meaning is the pairing of the aggregation already fixed in `self-referential-dao` with an escrow algebra that the aggregation is allowed to settle. Correctness of any later bytecode is agreement with this denotation, not resemblance to it.

## 1. Stance

Elliott's rule is that the instance's meaning is the meaning's instance. Applied here:

- The model is not storage, ballots, gas, or an EVM trace.
- \(\llbracket\cdot\rrbracket\) is total.
- An operation `op` on the representation is admitted only when there is an `op'` on the model with \(\llbracket \mathrm{op}\, a\, b\rrbracket = \mathrm{op}'\, \llbracket a\rrbracket\, \llbracket b\rrbracket\).
- A failed homomorphism is an abstraction leak and is rejected, not patched.

This is the same stance as `DENOTATIONAL-DESIGN.md` in the self-referential DAO, extended by one acted-on algebra (the escrow). The treasury note left out of scope there is filled in as an action of the aggregation, not as a second aggregation.

## 2. Semantic domain

Two independent meanings, then their dependent pairing.

**Governance.** As already denoted:

\[
\llbracket\mathrm{DAO}\rrbracket \;=\; \mathrm{Aggregation}\,\mathrm{act}\, F \;=\; \mathrm{LeftKanExtension}\,(\mathrm{orbitProjection}\,\mathrm{act})\, F
\]

with \(F : \mathrm{ChoiceRule}\,\mathrm{Obj}\, D = \mathrm{Obj} \Rightarrow D\), anonymity enforced by the orbit projection, and legitimacy the Lan universal property (\(\mathrm{unit}\), \(\mathrm{desc}\), \(\mathrm{fac}\), \(\mathrm{uniq}\)).

The decision space used by the escrow is the discrete category

\[
D \;=\; \{\mathrm{Release},\; \mathrm{Refund},\; \mathrm{Hold}\}.
\]

Regimes are inherited, not redefined: Arrow-impossibility (empty aggregation), Arrow-Debreu (object-unique outcome), Schelling-Ising (two object-distinct legitimate outcomes).

**Escrow.** A claim is a triple \((p, q, n)\) of payer, payee, and amount in a cancellative commutative monoid \(A\) of assets (pointwise \(\mathbb{N}\), or \(\mathbb{N}\) per token). An escrow state is

\[
E \;=\; (\mathrm{ledger} : \mathrm{Address} \to A)\;\times\; (\mathrm{claims} : \mathrm{List}\,\mathrm{Claim}).
\]

No release predicate lives in \(E\). The predicate is not data.

**Governed escrow.** The meaning of the whole system is the dependent pair

\[
\llbracket\mathrm{EscrowDAO}\rrbracket \;=\; \Sigma\,(L : \mathrm{Aggregation}\,\mathrm{act}\, F).\; E
\]

Settlement reads the verdict out of the aggregation and never out of storage:

\[
\mathrm{verdict}(L, X) \;=\; (\mathrm{Gov}\, L).\mathrm{obj}\, X, \qquad \mathrm{Gov}\, L \;=\; \mathrm{orbitProjection}\,\mathrm{act} \ggg L.\mathrm{functor}.
\]

So the rule that moves funds is the rule the DAO constitutes. That is the whole coupling.

## 3. Meaning of the operations

Write \(s\) for an escrow state and \(L\) for a chosen aggregation. The four operations that earn a homomorphism:

**Deposit** does not consult governance.

\[
\llbracket\mathrm{deposit}\, p\, n\rrbracket\,(L, s) \;=\; (L,\; s\{\mathrm{ledger}\, p \mathrel{+}= n,\; \mathrm{claims} \mathrel{+\!=} (p, q, n)\}).
\]

It is the monoid action of \(A\) on the ledger, paired with the identity on \(L\).

**Cast** is a local choice of configuration, anonymized by the orbit projection. Its meaning is the unit of the Kan extension, not a write:

\[
\llbracket\mathrm{cast}\, X\rrbracket\,(L, s) \;=\; (L, s) \quad\text{with evidence}\quad \mathrm{unit}_X : F.X \to L.\mathrm{functor}(\mathrm{orbitProjection}\, X).
\]

Two ballots in the same orbit denote the same cast. That is `lan_implies_orbit_constant`, re-exported rather than re-proved.

**Settle** factors through the verdict. For a claim \(c = (p, q, n)\) at configuration \(X\),

\[
\llbracket\mathrm{settle}\, c\rrbracket\,(L, s) \;=\;
\begin{cases}
(L,\; s\{\mathrm{ledger}\, p \mathrel{-}= n,\; \mathrm{ledger}\, q \mathrel{+}= n\}) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Release}, \\
(L,\; s\{\mathrm{ledger}\, p \mathrel{-}= n\}) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Refund}, \\
(L, s) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Hold}.
\end{cases}
\]

Partiality is genuine: in the Arrow-impossibility regime \(\mathrm{Aggregation}\,\mathrm{act}\, F\) is empty, so \(\llbracket\mathrm{settle}\rrbracket\) is the empty function. Funds are stuck, and that is the denotation, not a bug.

**Amend** is the one operation-level homomorphism already proved in the DAO design, lifted unchanged across the escrow:

\[
\llbracket\mathrm{amend}\rrbracket \;=\; \mathrm{Gov}, \qquad \mathrm{GovPhi}\,(\mathrm{canonicalAmendment}\,\mathrm{act})\, L \;=\; \mathrm{Gov}\, L.
\]

Amendment rewrites the constitution the next settlement will read. It does not rewrite the ledger. A self-constituting constitution is a fixed point

\[
\mathrm{IsSelfConstituting}\, F \;:\equiv\; \exists L.\; \forall X.\; (\mathrm{Gov}\, L).\mathrm{obj}\, X = F.\mathrm{obj}\, X,
\]

exactly as in `SelfReferentialDAO.lean`. The escrow then consults a rule that equals the rule that constituted it.

Proposal sequencing is the other homomorphism, and it is functoriality:

\[
\llbracket\mathrm{propose}\, p \mathbin{;} q\rrbracket \;=\; \llbracket\mathrm{propose}\, q\rrbracket \circ \llbracket\mathrm{propose}\, p\rrbracket,
\]

because \((\mathrm{Gov}\, L).\mathrm{map}(p \gg q) = (\mathrm{Gov}\, L).\mathrm{map}\, p \gg (\mathrm{Gov}\, L).\mathrm{map}\, q\). Over a discrete configuration category this is vacuous (only identities), as the existing design already records.

## 4. What the regimes mean for the escrow

| Regime | Aggregation | Escrow denotation |
|---|---|---|
| Arrow-impossibility | empty | no legitimate settle; ledger frozen |
| Arrow-Debreu | object-unique \(L\) | unique successor state |
| Schelling-Ising | two object-distinct \(L_1, L_2\) | two legitimate successor states (object-fork of the escrow, not a double spend) |

The fork is a fork of mediators, both factoring through their own Lan. It is not two writes of the same slot. Anonymity is inherited: settlement depends on the orbit of ballots, never on a voter address, because the verdict factors through \(\mathrm{orbitProjection}\).

## 5. Assay representation

Assay is not the model. A `.asy` file is a representation whose meaning is required to be the pair above. Proof terms erase, as assay already erases them; the Lean/UAT meaning function stays outside the bytecode. Surface follows `CounterSurface.asy`.

```asy
-- Representation of (DAORep, EscrowState). Not the meaning.
contract EscrowDAO where
  storage Rep := {
    ledger      : Word ;   -- packing of Address -> A; meaning is the monoid
    claims      : Word ;   -- packing of List Claim
    beta        : Word ;   -- coordination pressure, a parameter of F
    constitution: Word     -- code of the choice rule F, not a verdict
  }

  -- ⟦deposit p n⟧ = monoid action on ledger, identity on Aggregation
  payable entry deposit (payer : Word) (payee : Word) (n : Word) : Eff Sig Word :=
    do amt <- callvalue ;
       guard le n amt ;
       bal <- sload ledger ;
       bal' <- add bal n ;
       sstore ledger bal' ;
       pure bal'

  -- ⟦cast X⟧ = unit of the Kan extension; orbit-constant by lan_implies_orbit_constant
  entry cast (config : Word) : Eff Sig Word :=
    do pure config

  -- ⟦amend⟧ = Gov. Guard is the erased witness of IsSelfConstituting.
  entry amend (newBeta : Word) : Eff Sig Word :=
    do guard selfConstituting ;
       sstore beta newBeta ;
       pure newBeta

  -- ⟦settle c⟧ factors through (Gov L).obj. Partial: empty in Arrow-impossibility.
  entry settle (payer : Word) (payee : Word) (n : Word) : Eff Sig Word :=
    do v <- verdict ;                 -- denotes (Gov L).obj X, not a storage read
       guard eq v release ;
       bal <- sload ledger ;
       bal' <- sub bal n ;
       sstore ledger bal' ;
       pure bal'

  constructor :=
    do sstore beta (word 1) ;         -- critical point; disordered phase self-constitutes
       sstore ledger (word 0) ;
       pure ()
```

The dictionary that makes this a denotation rather than a sketch:

| Assay form | Denotation | Homomorphism? |
|---|---|---|
| `storage Rep` | representation of \(\Sigma L.\, E\), not \(E\) itself | — |
| `deposit` | monoid action of \(A\), identity on \(L\) | yes |
| `cast` | unit of \(\mathrm{LeftKanExtension}\) | yes (orbit-constant) |
| `amend` | \(\mathrm{Gov}\) | yes (`hom_amend`, by `rfl`) |
| `settle` | case on \((\mathrm{Gov}\, L).\mathrm{obj}\) | yes, where \(L\) exists |
| `verdict` | \((\mathrm{Gov}\, L).\mathrm{obj}\, X\) | bridge, not an operation |
| `selfConstituting` | erased witness of \(\mathrm{IsSelfConstituting}\, F\) | proof, erased |
| `beta` | parameter of \(F\), not a tally | representation only |

`verdict` and `selfConstituting` are not assay primitives. They are the names of the meaning-level guards. Assay's existing erasure discipline is the right implementation story: the guard is checked, the proof is dropped, and the bytecode is correct exactly when its accepted traces agree with the case split in §3.

## 6. What is deliberately not a homomorphism

Matching the retractions already in the DAO design:

- The ledger is a commutative monoid acted on by the aggregation. It is not itself given an \(\llbracket\cdot\rrbracket\)-homomorphism into a monoid of aggregations. Making the treasury "the" DAO would collapse the dependency.
- `gov_map_comp` is content-bearing only for non-discrete configurations. A discrete ballot space makes proposal sequencing vacuous.
- Bifurcation sits in the cardinality of \(\mathrm{Aggregation}\), not in the fixed-point predicate. The constant constitution self-constitutes in the disordered phase (\(\beta \le 1\)); a genuine fork of self-constitution needs a non-constant \(F\), which this design does not supply.
- Quorum is a predicate on the orbit groupoid, not yet a homomorphism.
- No naturality square for \(F \mapsto \mathrm{Aggregation}\,\mathrm{act}\, F\) is claimed; that needs the 2-categorical structure the DAO design already declines.

The assay contract can be emitted, traced, and differentially tested against geth. None of that is the design. The design is the pair \((\mathrm{Aggregation}\,\mathrm{act}\, F,\; E)\) together with the four homomorphisms, and the contract is correct only insofar as its entries denote them.
