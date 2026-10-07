#!/bin/zsh
# usage: zsh probe/p6-variants.sh
# P6 (M1): find which closed leaf terms `emit` reduces.  Each variant
# replaces `main` of probe/p6-leaf-contract.asy with one leaf for tally
# (2, 1, 0) and runs `emit`; when `emit` passes, it also runs the entry.
set -u
P=${0:A:h}
R=${P:h}
S=${TMPDIR:-/tmp}/escrow-probe/p6v
rm -rf $S
mkdir -p $S
cut_at=$(rg -n -m1 '^-- leafA' $P/p6-leaf-contract.asy | cut -d: -f1)
variant() {
  local label=$1 leaf=$2
  {
    zsh $R/prelude/assemble.sh $R/examples/programs/arrow-debreu.asy
    print
    head -n $((cut_at - 1)) $P/p6-leaf-contract.asy
    print -r -- "def main : Entry -> Tx := fun (entry : Entry) =>"
    print -r -- "  case entry with"
    print -r -- "  | 0 (args : leafA) => done (word 256 ($leaf))"
    print -r -- "  | 1 (args : leafB) => done (word 256 1)"
  } >$S/$label.asy
  if zsh $P/run.sh $label-emit emit $S/$label.asy -o $S/$label-out; then
    zsh $P/run.sh $label-run run $S/$label.asy --calldata $(cast calldata 'leafA(uint256,uint256)' 0 0)
  fi
}
variant v1-ctor 'decCode release'
variant v2-plural 'decCode (plural (tuple (2, tuple (1, 0))))'
variant v3-H 'decCode (H (mkTally (tuple (2, tuple (1, 0))) (reflNat 3)))'
variant v4-rule 'decCode (rule F agg (mkTally (tuple (2, tuple (1, 0))) (reflNat 3)))'
