-- P3: does `check --print` or `check --erased` show normal forms?
-- Built-in forms only.  Each closed definition below has a known normal
-- form: y = 42, two = 2, sel = 20 (natLt leg 1 = true), u = 6.
def f : Nat -> Nat := fun (x : Nat) => natAdd x 1
def y : Nat := f 41
def two : Nat := natAdd 1 1
def sel : Nat := case natLt 2 3 with
  | 0 (u : prod ()) => 10
  | 1 (u : prod ()) => 20
def T : Type 0 := prod (Nat, Nat)
def t : T := tuple (natAdd 2 3, natMul 2 3)
def u : Nat := t.1
