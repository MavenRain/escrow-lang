#!/bin/zsh
# usage: zsh probe/p8-surface-le.sh
# P8 (M1, SPEC O12): can a surface entry body hold a core `le a b yes no`
# term?  Each variant is a surface contract with a mapping and one entry
# `pick`.  Variants a to e put a two-way branch in the body.  Variant z is
# the control: `guard le` and a mapping write, which the surface accepts.
# Expected result (2026-10-06): a to e refused, z ok.
set -u
P=${0:A:h}
S=${TMPDIR:-/tmp}/escrow-probe/p8
rm -rf $S
mkdir -p $S
variant() {
  print -r -- 'contract P8 where'
  print -r -- '  storage State := { cell : Word ; balances : Mapping Address Uint256 }'
  print -r -- '  entry pick (a : Word) (b : Word) : Eff Sig Word := do'
  print -r -- "    $1"
  print -r -- '  entry get () : Eff Sig Word := do c <- sload cell ; pure c'
  print -r -- '  constructor := do sstore cell (word 7) ; pure ()'
}
variant 'le a b (pure (word 1)) (pure (word 2))' >$S/a-le-pure.asy
variant 'le a b (sstore balances a (word 1) ; pure (word 1)) (sstore balances b (word 2) ; pure (word 2))' >$S/b-le-do-legs.asy
variant 'le a b (done (word 1)) (done (word 2))' >$S/c-le-core-done.asy
variant 'if le a b then pure (word 1) else pure (word 2)' >$S/d-if.asy
variant 'x <- le a b ; pure x' >$S/e-bind-le.asy
variant 'guard le a b ; sstore balances a (word 1) ; pure (word 1)' >$S/z-control.asy
for f in $S/*.asy; do
  LINES_OUT=0 zsh $P/run.sh p8-${f:t:r} check $f
done
