-- P1: one runtime le branch leads to two continuations that write
-- different slots.  A nested le gives the three-way split of settle.
-- The core protocol is the one of assay examples/Counter.asy.  `emit`
-- refuses it without the marker axiom EvmOpcodes (M0_PROTOCOL).
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
def split2 : Type 0 := prod (a, b)
def split3 : Type 0 := prod (a, b)
def Entry : Type 0 := sum (split2, split3)

def constructor : Eff := ret (word 256 0)

-- split2: a <= b writes low, else high.
-- split3: a = b writes mid, a < b writes low, a > b writes high.
def main : Entry -> Tx := fun (entry : Entry) =>
  case entry with
  | 0 (args : split2) =>
    le args.0 args.1
      (store storage.0 args.0 (done (word 256 1)))
      (store storage.1 args.1 (done (word 256 2)))
  | 1 (args : split3) =>
    le args.0 args.1
      (le args.1 args.0
        (store storage.2 args.0 (done (word 256 3)))
        (store storage.0 args.0 (done (word 256 1))))
      (store storage.1 args.1 (done (word 256 2)))
