-- P2: equality in Type 0 with transport, symm, trans and cong by fibered
-- match.  Results of 2026-10-06 (probe/CAPABILITY.md, P2):
-- 1. A constructor of a family with a parameter cannot appear in a term:
--    "cannot infer: the constructor refl needs an expected type", bare,
--    applied, annotated and as an argument.
-- 2. A family with a type index, `Eq : (0 A : Type 0) -> A -> A -> ..`,
--    must live in Type 1.  Its motive binds the type index again, so
--    `transport` and `cong` cannot apply a function on the outer `A`.
-- 3. Thus each equality is a family with a fixed index type, in Type 0.
mu EqNat : (0 a : Nat) -> (0 b : Nat) -> Type 0 :=
  | reflNat : (0 x : Nat) -> EqNat x x

def transportNat : (0 P : Nat -> Type 0) -> (0 x : Nat) -> (0 y : Nat) -> EqNat x y -> P x -> P y :=
  fun (0 P : Nat -> Type 0) (0 x : Nat) (0 y : Nat) (e : EqNat x y) =>
    match e as q in EqNat i j return P i -> P j with
    | reflNat 0 z => fun (p : P z) => p

def symmNat : (0 x : Nat) -> (0 y : Nat) -> EqNat x y -> EqNat y x :=
  fun (0 x : Nat) (0 y : Nat) (e : EqNat x y) =>
    match e as q in EqNat i j return EqNat j i with
    | reflNat 0 z => reflNat z

def transNat : (0 x : Nat) -> (0 y : Nat) -> (0 z : Nat) -> EqNat x y -> EqNat y z -> EqNat x z :=
  fun (0 x : Nat) (0 y : Nat) (0 z : Nat) (e1 : EqNat x y) (e2 : EqNat y z) =>
    transportNat (fun (w : Nat) => EqNat x w) y z e2 e1

def congNat : (f : Nat -> Nat) -> (0 x : Nat) -> (0 y : Nat) -> EqNat x y -> EqNat (f x) (f y) :=
  fun (f : Nat -> Nat) (0 x : Nat) (0 y : Nat) (e : EqNat x y) =>
    match e as q in EqNat i j return EqNat (f i) (f j) with
    | reflNat 0 z => reflNat (f z)

mu Decision : Type 0 :=
  | release : Decision
  | refund : Decision
  | hold : Decision
mu EqDec : (0 a : Decision) -> (0 b : Decision) -> Type 0 :=
  | reflDec : (0 d : Decision) -> EqDec d d

def congND : (f : Nat -> Decision) -> (0 x : Nat) -> (0 y : Nat) -> EqNat x y -> EqDec (f x) (f y) :=
  fun (f : Nat -> Decision) (0 x : Nat) (0 y : Nat) (e : EqNat x y) =>
    match e as q in EqNat i j return EqDec (f i) (f j) with
    | reflNat 0 z => reflDec (f z)

-- Uses.  Each one needs conversion through natAdd, natSub, natLt or beta.
def two : Nat := natAdd 1 1
def e2 : EqNat two 2 := reflNat 2
def e2s : EqNat 2 two := symmNat two 2 e2
def e3 : EqNat (natAdd two 1) 3 := congNat (fun (n : Nat) => natAdd n 1) two 2 e2
def e4 : EqNat two (natSub 3 1) := transNat two 2 (natSub 3 1) e2 (reflNat 2)
def P : Nat -> Type 0 := fun (n : Nat) => EqNat n 2
def e5 : EqNat 2 2 := transportNat P two 2 e2 e2
def pick : Nat -> Decision := fun (n : Nat) => case natLt n 2 with
  | 0 (u : prod ()) => hold
  | 1 (u : prod ()) => release
def e6 : EqDec (pick 1) release := congND pick 1 1 (reflNat 1)
