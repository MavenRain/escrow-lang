#!/bin/zsh
# usage: zsh probe/p6-prefix.sh
# P6 (M1): find the first prelude section that `emit` refuses.  For k = 1
# to 8, the file is the members line, prelude sections 1 to k, and the P6
# contract with the leaf `decCode release` (section 1 names only).
set -u
P=${0:A:h}
R=${P:h}
S=${TMPDIR:-/tmp}/escrow-probe/p6p
rm -rf $S
mkdir -p $S
cut_at=$(rg -n -m1 '^-- leafA' $P/p6-leaf-contract.asy | cut -d: -f1)
marks=(${(f)"$(rg -n '^-- @section' $R/prelude/Prelude.asy | cut -d: -f1)"})
total=$(wc -l <$R/prelude/Prelude.asy | tr -d ' ')
for k in {1..${#marks}}; do
  if (( k < ${#marks} )); then end=$(( marks[k + 1] - 1 )); else end=$total; fi
  {
    print -r -- 'def members : Nat := 3'
    print
    head -n $end $R/prelude/Prelude.asy
    print
    head -n $((cut_at - 1)) $P/p6-leaf-contract.asy
    print -r -- "def main : Entry -> Tx := fun (entry : Entry) =>"
    print -r -- "  case entry with"
    print -r -- "  | 0 (args : leafA) => done (word 256 (decCode release))"
    print -r -- "  | 1 (args : leafB) => done (word 256 1)"
  } >$S/s$k.asy
  LINES_OUT=1 zsh $P/run.sh s$k-emit emit $S/s$k.asy -o $S/s$k-out | head -5
done
