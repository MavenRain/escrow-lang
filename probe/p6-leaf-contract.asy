-- P6 (M1): orbit-rule tabulation by a closed leaf term.  Append this file
-- to the assembled arrow-debreu program (probe/p6-run.sh).  Each entry
-- returns the code of `rule F agg t` for one literal tally `t`.  If the
-- emitter reduces the closed term at compile time, a leaf of the `le`
-- tree can be this term, and the generator needs no kernel error text.
-- The core protocol is the one of probe/p1-le-branch.asy.
mu Word : (0 bits : Nat) -> Type 0 :=
  | word : (0 bits : Nat) -> Nat -> Word bits
mu Eff : Type 0 :=
  | ret : Word 256 -> Eff
  | put : Word 256 -> Word 256 -> Eff -> Eff
  | read : Word 256 -> Eff
axiom EvmOpcodes : Prop

def ResultWord : Type 0 := sum (Word 256, prod ())
mu Tx : Type 0 :=
  | done : Word 256 -> Tx
  | store : Word 256 -> Word 256 -> Tx -> Tx
  | load : Word 256 -> (Word 256 -> Tx) -> Tx
  | add : Word 256 -> Word 256 -> (ResultWord -> Tx) -> Tx
  | sub : Word 256 -> Word 256 -> (ResultWord -> Tx) -> Tx
  | le : Word 256 -> Word 256 -> Tx -> Tx -> Tx
  | abort : Tx

def low : Type 0 := Word 256
def high : Type 0 := Word 256
def mid : Type 0 := Word 256
def Storage : Type 0 := prod (low, high, mid)
def storage : Storage := tuple (word 256 0, word 256 1, word 256 2)
def a : Type 0 := Word 256
def b : Type 0 := Word 256
def leafA : Type 0 := prod (a, b)
def leafB : Type 0 := prod (a, b)
def Entry : Type 0 := sum (leafA, leafB)

def constructor : Eff := ret (word 256 0)

-- The decision code: release 1, refund 2, hold 3.
-- A leaf takes literal counts: `natAdd` reduces only on literals, so a
-- helper over open counts cannot give `reflNat 3` (probe-forced, P6).
def decCode : Decision -> Nat := fun (d : Decision) => decide Nat 1 2 3 d

-- leafA: tally (2, 1, 0) gives release (1).  leafB: (0, 2, 1) gives refund (2).
def main : Entry -> Tx := fun (entry : Entry) =>
  case entry with
  | 0 (args : leafA) => done (word 256 (decCode (rule F agg (mkTally (tuple (2, tuple (1, 0))) (reflNat 3)))))
  | 1 (args : leafB) => done (word 256 (decCode (rule F agg (mkTally (tuple (0, tuple (2, 1))) (reflNat 3)))))
