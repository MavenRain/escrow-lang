#!/bin/sh
# Checker and verb tests of escrowc, run by make test after make: the gate
# fixtures of PLAN.md chunk 3, the mutants in test/mutants and the guards.
# Files go to build/test. Each run stays far under 4 GB: the arena of one run
# takes at most ESCROW_ARENA_MAX (256 MiB, src/syntax.h).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
escrowc=$root/build/escrowc
programs=$root/examples/programs
out=$root/build/test
mkdir -p "$out"
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

# expect NAME WANT_STATUS WANT_STDOUT ARGS...: exit status and stdout, with an
# empty stderr on exit 0.
expect() {
  name=$1 want_status=$2 want=$3
  shift 3
  "$escrowc" "$@" > "$out/check.out" 2> "$out/check.err"
  status=$?
  got=$(cat "$out/check.out")
  err=$(cat "$out/check.err")
  if [ "$status" -eq "$want_status" ] && [ "$got" = "$want" ] && { [ "$status" -ne 0 ] || [ -z "$err" ]; }; then
    pass "$name"
  else
    fail "$name: exit $status, stdout: $got, stderr: $err"
  fi
}

# refuse NAME CODE DEF SUFFIX ARGS...: exit 1, stderr "escrowc: CODE: DEF: ..."
# that ends in SUFFIX.
refuse() {
  name=$1 code=$2 def=$3 suffix=$4
  shift 4
  "$escrowc" "$@" > /dev/null 2> "$out/check.err"
  status=$?
  err=$(cat "$out/check.err")
  case $err in
    "escrowc: $code: $def: "*"$suffix") shape=1 ;;
    *) shape=0 ;;
  esac
  if [ "$status" -eq 1 ] && [ "$shape" -eq 1 ]; then pass "$name"; else fail "$name: exit $status, stderr: $err"; fi
}

expect "check arrow-debreu" 0 "ok debreu" check "$programs/arrow-debreu.esc"
expect "check arrow-impossibility" 0 "ok impossibility" check "$programs/arrow-impossibility.esc"
expect "table arrow-debreu" 0 "debreu 3 3 3 2 2 3 3 2 1 1 1" table "$programs/arrow-debreu.esc"
expect "table arrow-impossibility" 0 "impossibility 3" table "$programs/arrow-impossibility.esc"
expect "verdicts arrow-debreu F" 0 "111123133123222323133323333" verdicts "$programs/arrow-debreu.esc" F
expect "verdicts arrow-impossibility first" 0 "111111111222222222333333333" verdicts "$programs/arrow-impossibility.esc" first
expect "eval payeeAfterSettle" 0 "reflNat 5" eval "$programs/arrow-debreu.esc" payeeAfterSettle
expect "eval firstX" 0 "reflDec release" eval "$programs/arrow-impossibility.esc" firstX
expect "eval members" 0 "3" eval "$programs/arrow-impossibility.esc" members

# Erased Sigma fields may be constructed from erased variables and used
# in types, while the second field remains available at run time.
cat > "$out/erased-sigma.esc" <<'EOF'
def members : Nat := 3
def pack : (0 n : Nat) -> (0 x : Nat) * EqNat x n :=
  fun (0 n : Nat) => (n, reflNat n)
def unpack : (p : (0 x : Nat) * Nat) -> Nat := fun (p : (0 x : Nat) * Nat) => p.1
def proof : (p : (0 x : Nat) * EqNat x x) -> EqNat p.0 p.0 :=
  fun (p : (0 x : Nat) * EqNat x x) => p.1
def witness : EqNat (unpack (1, 2)) 2 := reflNat 2
EOF
expect "erased Sigma construction and type projection" 0 "ok impossibility" check "$out/erased-sigma.esc"

# A definitionally equal annotation must choose the same regime and
# contract, including through an alias of the Aggregation type function.
for annotation in 'Aggregation F' AggF 'AggType F'; do
  cat > "$out/aggregation-alias.esc" <<EOF
def members : Nat := 1
def F : ChoiceRule := fun (x : Config) => release
def AggF : Type 0 := Aggregation F
def AggType : (0 F : ChoiceRule) -> Type 0 := Aggregation
def agg : $annotation := mkAgg F (fun (t : Tally) => release) (fun (x : Config) => reflDec release)
EOF
  expect "check aggregation annotation $annotation" 0 "ok debreu" check "$out/aggregation-alias.esc"
  expect "table aggregation annotation $annotation" 0 "debreu 1 1 1 1" table "$out/aggregation-alias.esc"
  expect "build aggregation annotation $annotation" 0 "" build "$out/aggregation-alias.esc" -o "$out/aggregation.hex"
  if [ "$annotation" = 'Aggregation F' ]; then
    cp "$out/aggregation.hex" "$out/aggregation-direct.hex"
  elif cmp -s "$out/aggregation.hex" "$out/aggregation-direct.hex"; then
    pass "aggregation annotation $annotation preserves bytecode"
  else
    fail "aggregation annotation $annotation changes bytecode"
  fi
done

refuse "mutant debreu payeeAfterSettle reflNat 4" TYPE_MISMATCH payeeAfterSettle \
  "the types differ: expected EqNat 5 5, found EqNat 4 4" check "$root/test/mutants/debreu-payee-4.esc"
# The rule `first` reads member position 0, so no aggregation of it type
# checks. (a) arrow-debreu.esc with only the constitution changed to first.
refuse "mutant debreu constitution first" TYPE_MISMATCH agg \
  "with | 0 (escrowq2x0 : prod ()) => hold | 1 (escrowq2x0 : prod ()) => release))" \
  check "$root/test/mutants/debreu-first.esc"
# (b) mkAgg first at the constant orbit rule release.
refuse "mutant mkAgg first at the constant rule" TYPE_MISMATCH agg \
  "found EqDec release release" check "$root/test/mutants/impossibility-agg-release.esc"
# (c) mkAgg first with the proof reflDec (first x).
refuse "mutant mkAgg first with proof reflDec (first x)" TYPE_MISMATCH agg \
  ", found EqDec (foldBallots Decision (fun (escrowq1x0 : Decision) (escrowq2x0 : Decision) => escrowq1x0) hold (match escrowq0x0 as escrowq1x0 in Config return Ballots with | mkConfig escrowq1x0 escrowq2x0 => escrowq1x0)) (foldBallots Decision (fun (escrowq1x0 : Decision) (escrowq2x0 : Decision) => escrowq1x0) hold (match escrowq0x0 as escrowq1x0 in Config return Ballots with | mkConfig escrowq1x0 escrowq2x0 => escrowq1x0))" \
  check "$root/test/mutants/impossibility-agg-refl.esc"
refuse "verdicts of a name that is not a ChoiceRule" VERDICT_TYPE agg "agg is not a ChoiceRule" \
  verdicts "$programs/arrow-debreu.esc" agg
refuse "eval of an unknown name" TYPE_SCOPE nothing "nothing is not declared" \
  eval "$programs/arrow-debreu.esc" nothing

# Each append of a list to itself doubles it; the evaluation of the long
# appends nests past the depth cap, and the run stops with TYPE_FUEL.
awk 'BEGIN {
  print "def members : Nat := 1"
  print "def l0 : Ballots := bcons release bnil"
  for (i = 1; i <= 16; i++) printf "def l%d : Ballots := appendBallots l%d l%d\n", i, i - 1, i - 1
}' > "$out/deep.esc"
refuse "deep evaluation is TYPE_FUEL" TYPE_FUEL l11 "evaluation nests too deep" check "$out/deep.esc"

# settle takes three erased premises. Each case below gives one false
# premise and correct proofs of the others. (i) range: index 1 of one
# claim, so Lt 1 1 needs EqNat 2 1.
{ cat "$programs/arrow-debreu.esc"; cat <<'ESC'
def bad : Escrow := settle F agg x 1 s1 (0, reflNat 1) (reflNat 0) (0, reflNat 0)
ESC
} > "$out/settle-range.esc"
refuse "settle of an index past the claims is TYPE_MISMATCH" TYPE_MISMATCH bad \
  "the types differ: expected EqNat 2 1, found EqNat 1 1" check "$out/settle-range.esc"
# (ii) closed: a second deposit keeps the ledger above the amount, so only
# the open premise of the second settle of claim 0 is false.
{ cat "$programs/arrow-debreu.esc"; cat <<'ESC'
def t1 : Escrow := deposit 1 2 5 s1
def t2 : Escrow := settle F agg x 0 t1 (1, reflNat 2) (reflNat 0) (5, reflNat 10)
def bad : Escrow := settle F agg x 0 t2 (1, reflNat 2) (reflNat 0) (0, reflNat 5)
ESC
} > "$out/settle-closed.esc"
refuse "settle of a closed claim is TYPE_MISMATCH" TYPE_MISMATCH bad \
  "the types differ: expected EqNat 1 0, found EqNat 0 0" check "$out/settle-closed.esc"
# (iv) withdraw takes one erased premise. The credit of address 2 is 5 after
# the settle, so a withdraw of 6 needs Le 6 5, that is EqNat 6 5.
{ cat "$programs/arrow-debreu.esc"; cat <<'ESC'
def bad : Escrow := withdraw 2 6 s2 (0, reflNat 5)
ESC
} > "$out/withdraw-over.esc"
refuse "withdraw of more than the credit is TYPE_MISMATCH" TYPE_MISMATCH bad \
  "the types differ: expected EqNat 6 5, found EqNat 5 5" check "$out/withdraw-over.esc"

if [ "$failures" -eq 0 ]; then echo "check.sh: all passed"; exit 0; fi
echo "check.sh: $failures failed"
exit 1
