-- P3 fallback: refl-candidate checks on the definitions of p3-print.asy.
mu EqNat : (0 a : Nat) -> (0 b : Nat) -> Type 0 :=
  | reflNat : (0 x : Nat) -> EqNat x x
def f : Nat -> Nat := fun (x : Nat) => natAdd x 1
def y : Nat := f 41
def two : Nat := natAdd 1 1
def sel : Nat := case natLt 2 3 with
  | 0 (u : prod ()) => 10
  | 1 (u : prod ()) => 20
def T : Type 0 := prod (Nat, Nat)
def t : T := tuple (natAdd 2 3, natMul 2 3)
def u : Nat := t.1
def cy : EqNat y 42 := reflNat 42
def ctwo : EqNat two 2 := reflNat 2
def csel : EqNat sel 20 := reflNat 20
def cu : EqNat u 6 := reflNat 6
