#!/bin/zsh
# usage: zsh probe/p7-table.sh
# P7 (M1): tabulate the orbit rule in the kernel file with one packed code.
# code = decCode (L t0) + 4 * decCode (L t1) for t0 = (2, 1, 0) (release,
# code 1) and t1 = (0, 2, 1) (refund, code 2), so code = 9.  Run 1 checks
# a wrong candidate (0): its error must print the value.  Run 2 checks the
# printed value: it must pass.
set -u
P=${0:A:h}
R=${P:h}
S=${TMPDIR:-/tmp}/escrow-probe/p7
rm -rf $S
mkdir -p $S
table() {
  print -r -- 'def decCode : Decision -> Nat := fun (d : Decision) => decide Nat 1 2 3 d'
  print -r -- 'def code : Nat := natAdd (decCode (rule F agg (mkTally (tuple (2, tuple (1, 0))) (reflNat 3)))) (natMul 4 (decCode (rule F agg (mkTally (tuple (0, tuple (2, 1))) (reflNat 3)))))'
  print -r -- "def tableOk : EqNat code $1 := reflNat $1"
}
for guess in 0 9; do
  {
    zsh $R/prelude/assemble.sh $R/examples/programs/arrow-debreu.asy
    print
    table $guess
  } >$S/g$guess.asy
  LINES_OUT=1 zsh $P/run.sh p7-g$guess check $S/g$guess.asy
done
