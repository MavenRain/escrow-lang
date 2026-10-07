#!/bin/zsh
# usage: zsh gen/table.sh PROGRAM
# Tabulates the orbit rule of an Arrow-Debreu PROGRAM with the assay
# kernel (SPEC O11, probe P7).  Prints one decision code per tally on one
# line: release 1, refund 2, hold 3.  Tally i runs over r = 0..n and then
# f = 0..n-r, with h = n - r - f and n = members (line 1 of PROGRAM).
# The kernel file is the assembled PROGRAM and
# `code := sum decCode (rule F agg t_i) * 4^i`.  Run 1 checks a wrong
# candidate, and the value comes from its error text.  Run 2 checks that
# value with reflNat.  Run 2 is the certificate.  The error text is only a
# hint.
set -u
G=${0:A:h}
R=${G:h}
prog=${1:?usage: zsh gen/table.sh PROGRAM}
n=$(head -1 $prog | rg -o -r '$1' '^def members : Nat := ([0-9]+)$') || {
  print -u2 -r -- "table: line 1 of $prog must be 'def members : Nat := N'"
  exit 2
}
W=$(mktemp -d ${TMPDIR:-/tmp}/escrow-table.XXXXXX)
tally() {
  print -r -- "decCode (rule F agg (mkTally (tuple ($1, tuple ($2, $3))) (reflNat $n)))"
}
terms=()
for r in {0..$n}; do
  for f in {0..$((n - r))}; do
    terms+=("$(tally $r $f $((n - r - f)))")
  done
done
code=${terms[-1]}
for (( i = ${#terms} - 1; i >= 1; i-- )); do
  code="natAdd ($terms[$i]) (natMul 4 ($code))"
done
kernel() {
  zsh $R/prelude/assemble.sh $prog
  print
  print -r -- 'def decCode : Decision -> Nat := fun (d : Decision) => decide Nat 1 2 3 d'
  print -r -- "def code : Nat := $code"
  print -r -- "def tableOk : EqNat code $1 := reflNat $1"
}
kernel 0 >$W/hint.asy
env TMPDIR=$W zsh $R/probe/run.sh hint check $W/hint.asy >/dev/null && {
  print -u2 -r -- "table: the kernel accepted the wrong candidate 0 ($W)"
  exit 1
}
value=$(rg -o -r '$1' 'the type asks for ([0-9]+)' $W/escrow-probe/logs/hint.err | head -1)
[[ -n $value ]] || {
  print -u2 -r -- "table: no value in the run 1 error ($W/escrow-probe/logs/hint.err)"
  exit 1
}
kernel $value >$W/certificate.asy
env TMPDIR=$W zsh $R/probe/run.sh certificate check $W/certificate.asy >/dev/null || {
  print -u2 -r -- "table: run 2 refused the value $value ($W)"
  exit 1
}
digits=$(print -r -- "obase=4; $value" | BC_LINE_LENGTH=0 bc)
codes=(${(Oa)${(s::)digits}})
(( ${#codes} == ${#terms} )) && [[ $digits =~ '^[123]+$' ]] || {
  print -u2 -r -- "table: value $value has base-4 digits $digits, not ${#terms} codes in 1..3"
  exit 1
}
rm -rf $W
print -r -- ${codes}
