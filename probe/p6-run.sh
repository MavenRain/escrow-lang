#!/bin/zsh
# usage: zsh probe/p6-run.sh
# P6 (M1): assemble examples/programs/arrow-debreu.asy, append
# probe/p6-leaf-contract.asy, then run check, axioms, emit and two runs.
# The scratch file and the emit directory go to $TMPDIR/escrow-probe/p6.
set -u
P=${0:A:h}
R=${P:h}
S=${TMPDIR:-/tmp}/escrow-probe/p6
rm -rf $S
mkdir -p $S
{
  zsh $R/prelude/assemble.sh $R/examples/programs/arrow-debreu.asy
  print
  cat $P/p6-leaf-contract.asy
} >$S/p6.asy
zsh $P/run.sh p6-check check $S/p6.asy
zsh $P/run.sh p6-axioms axioms $S/p6.asy
zsh $P/run.sh p6-emit emit $S/p6.asy -o $S/emit
ls $S/emit 2>/dev/null
zsh $P/run.sh p6-runA run $S/p6.asy --calldata $(cast calldata 'leafA(uint256,uint256)' 0 0)
zsh $P/run.sh p6-runB run $S/p6.asy --calldata $(cast calldata 'leafB(uint256,uint256)' 0 0)
