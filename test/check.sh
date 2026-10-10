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
# memberAddresses (M4): Arrow-Debreu declares it, and an Arrow-impossibility
# program with the def (a test fixture) still checks.
expect "eval memberAddresses" 0 "acons 0x1000000000000000000000000000000000000001 (acons 0x2000000000000000000000000000000000000002 (acons 0x3000000000000000000000000000000000000003 anil))" \
  eval "$programs/arrow-debreu.esc" memberAddresses
expect "check impossibility with memberAddresses" 0 "ok impossibility" \
  check "$root/test/fixtures/impossibility-addresses.esc"
# memberClasses (M6): an Arrow-Debreu program with two member classes (a test
# fixture) still checks.
expect "check debreu with two member classes" 0 "ok debreu" \
  check "$root/test/fixtures/two-classes.esc"
# The table is the product of the class rows, class 1 the outer digit (M6
# chunk 2). Above 128 rows, table refuses REFUSE_TABLE_SIZE.
expect "table debreu with two member classes" 0 "debreu 3 3 3 3 3 2 3 2 2 2 3 3 1 3 2 1 1 1 1" \
  table "$root/test/fixtures/two-classes.esc"
# prove (M9 chunk 1): Nat matches, def rec on Nat, induction proofs and the
# proof-irrelevant Tally field check.
expect "prove nat induction" 0 "ok impossibility" prove "$root/test/fixtures/prove-nat.esc"
expect "prove O1" 0 "ok impossibility" prove "$root/proofs/O1.esc"
expect "prove O14" 0 "ok impossibility" prove "$root/proofs/O14.esc"
refuse "table debreu with 14 members in two classes" REFUSE_TABLE_SIZE memberClasses "more than 128 table rows" \
  table "$root/test/fixtures/two-classes-14.esc"
refuse "table debreu with 14 classes of one member" REFUSE_TABLE_SIZE memberClasses "more than 128 table rows" \
  table "$root/test/fixtures/trivial-classes-14.esc"
# The council example (M6 chunk 4): a board of 2 members and 2 delegates.
# The board decides unless it holds, so the codes read the class split.
expect "check council" 0 "ok debreu" check "$programs/council.esc"
expect "table council" 0 "debreu 4 3 3 2 3 3 1 3 3 2 3 3 1 2 2 2 2 2 2 3 3 2 3 3 1 3 3 2 3 3 1 1 1 1 1 1 1" table "$programs/council.esc"
expect "verdicts council F" 0 "111111111133323333133323333133323333222222222133323333133323333133323333133323333" verdicts "$programs/council.esc" F

# The class-table cases (M6, before chunk 2 a C harness): H releases iff class 1
# has 2 release ballots, so source evaluation and the table read the classes.
# class_case NAME LINE...: $out/class-NAME.esc is `def members : Nat := 3`,
# the lines LINE..., and then test/fixtures/class-source.esc.
class_case() {
  name=$1
  shift
  { printf '%s\n' 'def members : Nat := 3' "$@"; cat "$root/test/fixtures/class-source.esc"; } > "$out/class-$name.esc"
}
class_case default
class_case one 'def memberClasses : Classes := kcons 3 knil'
class_case two 'def memberClasses : Classes := kcons 2 (kcons 1 knil)'
class_case three 'def memberClasses : Classes := kcons 1 (kcons 1 (kcons 1 knil))'
expect "eval class default sourceVerdict" 0 "release" eval "$out/class-default.esc" sourceVerdict
expect "eval class one sourceVerdict" 0 "release" eval "$out/class-one.esc" sourceVerdict
expect "eval class two sourceVerdict" 0 "refund" eval "$out/class-two.esc" sourceVerdict
expect "eval class three sourceVerdict" 0 "refund" eval "$out/class-three.esc" sourceVerdict
expect "table class default" 0 "debreu 3 2 2 2 2 2 2 2 1 1 2" table "$out/class-default.esc"
expect "table class one" 0 "debreu 3 2 2 2 2 2 2 2 1 1 2" table "$out/class-one.esc"
expect "table class two" 0 "debreu 3 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1" table "$out/class-two.esc"
expect "table class three" 0 "debreu 3 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2" \
  table "$out/class-three.esc"

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
def memberAddresses : Addresses := acons 0x1000000000000000000000000000000000000001 anil
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
# council.esc with member 2 moved to the delegates (classes 1,3): the board
# of x is refund alone, so the verdict release of verdictX does not check.
refuse "mutant council member 2 in class 2" TYPE_MISMATCH verdictX \
  "the types differ: expected EqDec refund release, found EqDec release release" \
  check "$root/test/mutants/council-class-move.esc"
# decisionFlip (M7): the declaration checks at decl 1, and at decl 2 after
# memberClasses. The mutant is arrow-debreu.esc with the identity at decl 1.
printf '%s\n' 'def members : Nat := 3' 'def decisionFlip : Decision -> Decision := flipDecision' > "$out/flip.esc"
printf '%s\n' 'def members : Nat := 3' 'def memberClasses : Classes := kcons 2 (kcons 1 knil)' \
  'def decisionFlip : Decision -> Decision := fun (d : Decision) => decide Decision refund release hold d' \
  > "$out/flip-classes.esc"
expect "check decisionFlip" 0 "ok impossibility" check "$out/flip.esc"
expect "check decisionFlip after memberClasses" 0 "ok impossibility" check "$out/flip-classes.esc"
refuse "mutant debreu decisionFlip identity" REFUSE_FLIP_FORM decisionFlip \
  "must map release to refund, refund to release and hold to hold" check "$root/test/mutants/debreu-flip-identity.esc"
# A stated decisionFlip keeps a table that commutes with the flip. The three
# programs state it (M7 chunk 4), so the check and table rows above use the
# flip. A copy without the declaration gives the same table. The identity in
# its place is REFUSE_FLIP_FORM, so each program states the declaration that
# the checker reads. The mutant gives release at the tie (1, 1, 1), and the
# flip sends row 5 to row 5.
awk '!/^def decisionFlip /' "$programs/arrow-debreu.esc" > "$out/noflip-debreu.esc"
awk '!/^def decisionFlip /' "$root/test/fixtures/two-classes.esc" > "$out/noflip-classes.esc"
awk '!/^def decisionFlip /' "$programs/council.esc" > "$out/noflip-council.esc"
expect "table arrow-debreu without decisionFlip" 0 "debreu 3 3 3 2 2 3 3 2 1 1 1" table "$out/noflip-debreu.esc"
expect "table two-classes without decisionFlip" 0 "debreu 3 3 3 3 3 2 3 2 2 2 3 3 1 3 2 1 1 1 1" \
  table "$out/noflip-classes.esc"
expect "table council without decisionFlip" 0 \
  "debreu 4 3 3 2 3 3 1 3 3 2 3 3 1 2 2 2 2 2 2 3 3 2 3 3 1 3 3 2 3 3 1 1 1 1 1 1 1" table "$out/noflip-council.esc"
idflip='/^def decisionFlip /{$0 = "def decisionFlip : Decision -> Decision := fun (d : Decision) => d"} {print}'
awk "$idflip" "$programs/arrow-debreu.esc" > "$out/idflip-debreu.esc"
awk "$idflip" "$root/test/fixtures/two-classes.esc" > "$out/idflip-classes.esc"
awk "$idflip" "$programs/council.esc" > "$out/idflip-council.esc"
refuse "arrow-debreu with the identity as decisionFlip" REFUSE_FLIP_FORM decisionFlip \
  "must map release to refund, refund to release and hold to hold" check "$out/idflip-debreu.esc"
refuse "two-classes with the identity as decisionFlip" REFUSE_FLIP_FORM decisionFlip \
  "must map release to refund, refund to release and hold to hold" check "$out/idflip-classes.esc"
refuse "council with the identity as decisionFlip" REFUSE_FLIP_FORM decisionFlip \
  "must map release to refund, refund to release and hold to hold" check "$out/idflip-council.esc"
refuse "mutant debreu flip table" REFUSE_FLIP_TABLE decisionFlip "does not commute with table row 5" \
  table "$root/test/mutants/debreu-flip-table.esc"
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
