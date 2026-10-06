-- P5: re-pairing a dependent Sigma from its projections fails (2026-10-06,
-- probe/CAPABILITY.md, "M0 prelude and examples").  Expected: check refuses
-- `f` with a mismatch between `s.1` with and without `as self return Nat`.
mu EqNat : (0 a : Nat) -> (0 b : Nat) -> Type 0 :=
  | reflNat : (0 x : Nat) -> EqNat x x
def S : Type 0 := (n : Nat) * EqNat n 3
def f : S -> S := fun (s : S) => (s.1, s.2)
