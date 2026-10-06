#!/bin/zsh
# usage: zsh prelude/assemble.sh PROGRAM > FILE
#        zsh prelude/assemble.sh --members N > FILE
# Writes one assay file in the order of SPEC section 8: line 1 of PROGRAM
# (`def members : Nat := N`), prelude/Prelude.asy, then the rest of
# PROGRAM.  With `--members N` the file is the members line and the prelude.
set -eu
P=${0:A:h}
members_line() {
  print -rn -- "$1" | rg -q -U '\Adef members : Nat := [0-9]+\z' || {
    print -u2 -r -- "assemble: line 1 must be 'def members : Nat := N', got: $1"
    exit 2
  }
  print -r -- "$1"
}
if [[ $1 == --members ]]; then
  members_line "def members : Nat := $2"
  print
  cat $P/Prelude.asy
  exit 0
fi
prog=$1
members_line "$(head -1 $prog)"
print
cat $P/Prelude.asy
print
tail -n +2 $prog
