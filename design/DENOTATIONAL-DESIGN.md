The design below is in Conal Elliott's sense: a simple mathematical meaning is fixed first, a representation is chosen second, and every operation is required to be a homomorphism for a total meaning function \(\llbracket\cdot\rrbracket\). The representation uses assay-style notation and the TinyCC host (section 5). The core meaning is the pairing of the aggregation already fixed in `self-referential-dao` with an escrow algebra that the aggregation is allowed to settle. The stored-voting adapter additionally retains the configuration context described below. Correctness of the bytecode is agreement with this denotation, not resemblance to it.

## 1. Stance

Elliott's rule is that the instance's meaning is the meaning's instance. Applied here:

- The core model is not storage, ballots, gas, or an EVM trace. The stored-voting adapter must retain its configuration inputs (section 2).
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
E \;=\; (\mathrm{ledger} : \mathrm{Address} \to A)\;\times\; (\mathrm{credit} : \mathrm{Address} \to A)\;\times\; (\mathrm{claims} : \mathrm{List}\,\mathrm{Claim}).
\]

The credit of an address is the amount that the address can withdraw (section 3).

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

The pair above is the core meaning. The contract adapter also retains a context \(\Gamma\): the stable index-to-claim association and closed flags (O4), plus a partial configuration for each index (O13). Write \(\Gamma(c,m)\) for the decision recorded by member \(m\), or unvoted. Its full state meaning is \((L,s,\Gamma)\), with the core projection \(\pi(L,s,\Gamma)=(L,s)\); the open claims of \(s\) are the open indexed records of \(\Gamma\) in insertion order. Deposit appends a fresh open indexed record with every member unvoted. Release and refund close that record while retaining its configuration.

Core settlement takes an explicit complete configuration \(X\), as source `settle F L x c s hc ho h` does (SPEC section 5). The contract entry `settle(c)` obtains \(X_c\) from \(\Gamma\). It cannot be an operation on \((L,s)\) alone: forgetting \(\Gamma\) would forget both readiness and the configuration that selects the verdict.

## 3. Meaning of the operations

Write \(s\) for an escrow state and \(L\) for a chosen aggregation. The five operations that earn a homomorphism:

**Deposit** does not consult governance.

\[
\pi\llbracket\mathrm{deposit}\, p\, q\, n\rrbracket\,(L, s,\Gamma) \;=\; (L,\; s\{\mathrm{ledger}\, p \mathrel{+}= n,\; \mathrm{claims} \mathrel{+\!=} (p, q, n)\}).
\]

It is the monoid action of \(A\) on the ledger, paired with the identity on \(L\).

**Cast** is a local choice of configuration, anonymized by the orbit projection. Its meaning is the unit of the Kan extension, not a write:

\[
\llbracket\mathrm{cast}\, X\rrbracket\,(L, s,\Gamma) \;=\; (L, s,\Gamma) \quad\text{with evidence}\quad \mathrm{unit}_X : F.X \to L.\mathrm{functor}(\mathrm{orbitProjection}\, X).
\]

Two ballots in the same orbit denote the same cast. That is `lan_implies_orbit_constant`, re-exported rather than re-proved.

**Settle** factors through the verdict. For an open claim \(c = (p, q, n)\) and a complete configuration \(X\), with the proof \(h : n \le \mathrm{ledger}\, p\),

\[
\mathrm{settle}_{\mathrm{core}}(c,X)(L, s) \;=\;
\begin{cases}
(L,\; s\{\mathrm{ledger}\, p \mathrel{-}= n,\; \mathrm{credit}\, q \mathrel{+}= n,\; \mathrm{claims} \mathrel{-}= c\}) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Release}, \\
(L,\; s\{\mathrm{ledger}\, p \mathrel{-}= n,\; \mathrm{credit}\, p \mathrel{+}= n,\; \mathrm{claims} \mathrel{-}= c\}) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Refund}, \\
(L, s) & \text{if }\mathrm{verdict}(L, X) = \mathrm{Hold}.
\end{cases}
\]

Release and refund close the claim: \(\mathrm{claims} \mathrel{-}= c\) removes \(c\) from the open claims (SPEC O4). The contract keeps the index of \(c\) and sets its closed flag, so the indices of the other claims do not change. Hold changes nothing. The claim stays open, and a later settle can decide it.

The contract adapter reads \(X_c\) from storage and takes no ballots, so any caller can settle. Until every member has voted on \(c\), this entry is not defined and the call reverts. On a successful call it applies the core case split to the claim associated with index \(c\) and \(X_c\). Release and refund also close that indexed record in \(\Gamma\); hold leaves it open. The stored ballots stay after every verdict.

Settle sends no funds. Release and refund move \(n\) from the ledger into the credit, which is the monoid action of \(A\) on the credit (SPEC O7). The payee or the payer then gets the funds with withdraw.

Partiality is genuine: in the Arrow-impossibility regime \(\mathrm{Aggregation}\,\mathrm{act}\, F\) is empty, so \(\llbracket\mathrm{settle}\rrbracket\) is the empty function. Funds are stuck, and that is the denotation, not a bug.

**Vote** supplies the adapter's configuration input. It is not one of the five core operations. On its valid domain (an open claim, a registered member and a valid decision), its full meaning updates \(\Gamma\), while its core projection is unchanged:

\[
\llbracket\mathrm{vote}\, c\, b\rrbracket_m\,(L, s,\Gamma)
\;=\; (L,s,\Gamma[(c,m)\mapsto b]),
\qquad \pi\circ\llbracket\mathrm{vote}\, c\, b\rrbracket_m=\pi.
\]

Member \(m\) records the ballot \(b\) on the open claim \(c\) in the representation (slot 7, section 5). A later vote of \(m\) on \(c\) replaces it. The member addresses decide which callers are members. The verdict still depends only on the orbit of the ballots, never on a voter address (section 4). In the Arrow-impossibility regime the contract has no member addresses and no vote.

For example, with the three-member Arrow-Debreu example, an open claim \((p,q,5)\), \(p\ne q\), and payer balance 20, three release votes and three refund votes leave the same core state. The next `settle(c)` credits 5 to \(q\) in the first case and to \(p\) in the second. Thus vote is not the identity on the full state, and contract settlement does not factor through \(\pi\) alone.

**Withdraw** does not consult governance. For the caller \(a\) and an amount \(n \le \mathrm{credit}\, a\), it first debits the credit. For a fixed EVM environment and initial configuration context \(\Gamma\), write \(C^{\Gamma}_{a,n}\) for the core projection of sending \(n\) to \(a\) and running the recipient, including its reentrant calls on the full adapter state. On a successful send,

\[
\pi\llbracket\mathrm{withdraw}\, n\rrbracket_{C}\,(L, s,\Gamma) \;=\; (L,\; C^{\Gamma}_{a,n}(s\{\mathrm{credit}\, a \mathrel{-}= n\})).
\]

The debit is a partial inverse of the monoid action of \(A\) on the credit, paired with the identity on \(L\). \(A\) is cancellative, so \(\mathrm{credit}\, a \mathrel{-}= n\) has one value when \(n \le \mathrm{credit}\, a\). For a larger \(n\), withdraw is not defined, and the call reverts. The full withdrawal composes the debit with recipient execution on \((L,s,\Gamma)\); its core effect is \(C^{\Gamma}_{a,n}\). This execution is the identity only when it leaves the full state unchanged. The credit guard alone does not guarantee that the send succeeds.

The contract debits the credit first, then it sends \(n\) wei to \(a\). If the send fails, the call reverts and the state stays \((L, s,\Gamma)\), including rollback of reentrant changes. The recipient can call withdraw, deposit, vote or settle during the send. Each withdrawal checks and debits the current credit before its send. For a fixed address, cumulative withdrawals are bounded by its initial credit plus credit added by settlements during recipient execution. Withdraw reads the credit of \(a\) again after the send and returns it, so the result includes both debits and new settlement credits. For example, credit 30 followed by withdraw 12 and a reentrant settlement adding 5 returns 23; a further reentrant withdrawal of 23 makes the total sent 35.

In the Arrow-impossibility regime no settle occurs, so each credit stays empty, and withdraw reverts. The escrow is deposit-only, and the funds stay in the contract (section 4).

**Amend** is the one operation-level homomorphism already proved in the DAO design, lifted unchanged across the escrow:

\[
\llbracket\mathrm{amend}\rrbracket \;=\; \mathrm{Gov}, \qquad \mathrm{GovPhi}\,(\mathrm{canonicalAmendment}\,\mathrm{act})\, L \;=\; \mathrm{Gov}\, L.
\]

Canonical amendment yields the constitution the next settlement will read. At the discrete decision category used here it agrees with \(F\) on every configuration, so the contract returns the packed verdict table and changes neither the rule nor storage (SPEC O5). A self-constituting constitution is a fixed point

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
| Arrow-Debreu | object-unique \(L\) | unique successor state at a fixed complete configuration |
| Schelling-Ising | two object-distinct \(L_1, L_2\) | two legitimate successor states (object-fork of the escrow, not a double spend) |

The fork is a fork of mediators, both factoring through their own Lan. It is not two writes of the same slot. Anonymity is inherited: settlement depends on the orbit of ballots, never on a voter address, because the verdict factors through \(\mathrm{orbitProjection}\).

## 5. Assay-style representation sketch

The sketch below uses assay-style notation, not executable `.asy` source. The TinyCC host writes the bytecode in `src/evm.c` and uses no assay (SPEC section 8). Proof terms erase, and the Lean/UAT meaning function stays outside the bytecode. The sketch follows SPEC section 7: storage slots 0 to 7 and the six entries `deposit`, `cast`, `vote`, `settle`, `amend` and `withdraw`. Storage represents the full adapter state \((L,s,\Gamma)\) of section 2. The constitution is the verdict table in the runtime code, not storage. The `match` in `settle` is not assay surface (SPEC O12). Selector, calldata-length and nonpayable guards are implicit in the entry declarations; arithmetic uses checked addition.

```asy
-- Representation of (DAORep, EscrowState, adapter context). Not the meaning.
contract EscrowDAO where
  storage Rep := {
    ledger  : Word ;   -- slot 0: Address -> A; meaning is the monoid
    count   : Word ;   -- slot 1: the claim count
    payer   : Word ;   -- slot 2: claim index -> payer
    payee   : Word ;   -- slot 3: claim index -> payee
    amount  : Word ;   -- slot 4: claim index -> amount
    credit  : Word ;   -- slot 5: Address -> A, the withdrawable credit (O7)
    closed  : Word ;   -- slot 6: claim index -> 1 closed, 0 open (O4)
    ballots : Word     -- slot 7: claim index -> X_c, member m at 4^m, 0 no ballot (O13)
  }

  -- ⟦deposit p q n⟧ = monoid action on ledger, identity on Aggregation
  payable entry deposit (p : Word) (q : Word) (n : Word) : Eff Sig Word :=
    do guard addressWord p ;          -- p < 2^160
       guard addressWord q ;          -- q < 2^160
       amt <- callvalue ;
       guard le n amt ;
       bal <- sload (ledger p) ;
       bal' <- checkedAdd bal n ;
       sstore (ledger p) bal' ;
       c <- sload count ;
       sstore (payer c) p ;
       sstore (payee c) q ;
       sstore (amount c) n ;
       k <- checkedAdd c 1 ;
       sstore count k ;
       pure c

  -- ⟦cast X⟧ = unit of the Kan extension; orbit-constant by lan_implies_orbit_constant
  entry cast (config : Word) : Eff Sig Word :=
    do v <- verdict config ;          -- config = b1 .. bn; writes nothing
       pure v

  -- ⟦vote c b⟧ updates Gamma; its projection to (L, s) stays unchanged
  entry vote (c : Word) (b : Word) : Eff Sig Word :=
    do a <- caller ;
       m <- member a ;                -- reverts unless a is in memberAddresses
       k <- sload count ;
       guard lt c k ;
       f <- sload (closed c) ;
       guard eq f 0 ;                 -- O4
       guard ballot b ;               -- b is 1, 2 or 3
       x <- sload (ballots c) ;
       x' <- setBallot x m b ;        -- replaces field m, at 4^m
       sstore (ballots c) x' ;
       pure x'

  -- ⟦settle c⟧ factors through (Gov L).obj at X_c. Partial: empty in Arrow-impossibility.
  entry settle (c : Word) : Eff Sig Word :=
    do k <- sload count ;
       guard lt c k ;
       f <- sload (closed c) ;
       guard eq f 0 ;                 -- O4
       x <- sload (ballots c) ;
       guard allVoted x ;             -- O13: no field is 0
       v <- verdict x ;               -- denotes (Gov L).obj X_c
       p <- sload (payer c) ;
       q <- sload (payee c) ;
       n <- sload (amount c) ;
       bal <- sload (ledger p) ;
       guard le n bal ;               -- the proof h, also on hold
       match v with
       | release => do sstore (ledger p) (sub bal n) ; addCredit q n ; sstore (closed c) 1
       | refund  => do sstore (ledger p) (sub bal n) ; addCredit p n ; sstore (closed c) 1
       | hold    => pure () ;
       pure v

  -- ⟦amend⟧ = Gov. At a discrete D, Gov L agrees with F, so amend writes nothing (O5).
  entry amend : Eff Sig Word :=
    do guard selfConstituting ;       -- erased witness of IsSelfConstituting
       t <- table ;                   -- the packed verdict table, sum C_i * 4^i
       pure t

  -- ⟦withdraw n⟧ = credit debit, then the send C_{a,n}; identity on Aggregation
  entry withdraw (n : Word) : Eff Sig Word :=
    do a <- caller ;
       cr <- sload (credit a) ;
       guard le n cr ;
       sstore (credit a) (sub cr n) ; -- debit first
       send a n ;                     -- all the gas; a failed send reverts
       cr' <- sload (credit a) ;      -- read again after the send
       pure cr'

  constructor :=
    do pure ()                        -- writes no storage
```

The dictionary that makes this a denotation rather than a sketch:

| Assay form | Denotation | Homomorphism? |
|---|---|---|
| `storage Rep` | representation of \((L,s,\Gamma)\), with core projection \(\Sigma L.\, E\); slots 0 to 7 of SPEC section 7 | not an operation |
| `deposit` | monoid action of \(A\), identity on \(L\) | yes |
| `cast` | unit of \(\mathrm{LeftKanExtension}\) | yes (orbit-constant) |
| `vote` | updates \(\Gamma(c,m)\); its core projection stays \((L,s)\) | adapter operation, not one of the five core operations (section 3) |
| `amend` | \(\mathrm{Gov}\); returns the packed verdict table and writes nothing | yes (`hom_amend`, by `rfl`) |
| `settle` | core case on \((\mathrm{Gov}\, L).\mathrm{obj}\,X\); the adapter obtains \(X_c\) from \(\Gamma\) | at an explicit complete \(X\), where \(L\) exists; not through the core state alone |
| `credit` | a second `Ledger`, packing of \(\mathrm{Address} \to A\); settle applies `add` to it, withdraw applies `sub` to it | not an operation |
| `closed` | the closed flag at each stable claim index (`Closed`); settle applies `close` on release and refund, the representation of \(\mathrm{claims} \mathrel{-}= c\) | not an operation |
| `ballots` | representation of the partial configurations \(\Gamma\), 2 bits per member; vote writes it, settle reads it | not an operation |
| `withdraw` | partial credit debit composed with recipient execution on \((L,s,\Gamma)\), identity on \(L\) | relative to the recipient context \(C^{\Gamma}_{a,n}\) in section 3 |
| `verdict` | \((\mathrm{Gov}\, L).\mathrm{obj}\, X\) | bridge, not an operation |
| `selfConstituting` | erased witness of \(\mathrm{IsSelfConstituting}\, F\) | proof, erased |

`verdict` and `selfConstituting` are not assay primitives. They are the names of the meaning-level guards. `addressWord`, `checkedAdd`, `member`, `ballot`, `setBallot`, `allVoted`, `table`, `addCredit` and `send` are also not assay primitives: they name short code sequences in `src/evm.c`. `addCredit` checks addition overflow too. The host checks the guards and drops their proof witnesses. Correct bytecode must agree with the case split in §3 at the configuration read by the adapter, including its readiness and authorization guards.

## 6. What is deliberately not a homomorphism

Matching the retractions already in the DAO design:

- The ledger is a commutative monoid acted on by the aggregation. It is not itself given an \(\llbracket\cdot\rrbracket\)-homomorphism into a monoid of aggregations. Making the treasury "the" DAO would collapse the dependency.
- `gov_map_comp` is content-bearing only for non-discrete configurations. A discrete ballot space makes proposal sequencing vacuous.
- Bifurcation sits in the cardinality of \(\mathrm{Aggregation}\), not in the fixed-point predicate. The constant constitution self-constitutes in the disordered phase (\(\beta \le 1\)); a genuine fork of self-constitution needs a non-constant \(F\), which this design does not supply.
- Quorum is a predicate on the orbit groupoid, not yet a homomorphism.
- No naturality square for \(F \mapsto \mathrm{Aggregation}\,\mathrm{act}\, F\) is claimed; that needs the 2-categorical structure the DAO design already declines.

The assay contract can be emitted, traced, and differentially tested against geth. None of that is the design. The design is the pair \((\mathrm{Aggregation}\,\mathrm{act}\, F,\; E)\) together with the operations in section 3, and the contract is correct only insofar as its entries denote them, including the recipient context for withdraw.
