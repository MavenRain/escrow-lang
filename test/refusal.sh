#!/bin/sh
# Refusal tests of escrowc, run by make test after make: one program per
# REFUSE_* code of SPEC section 2, then one per checker error. Files go to
# build/test/refusal. Each run stays far under 4 GB: the arena of one run
# takes at most ESCROW_ARENA_MAX (256 MiB, src/syntax.h).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
escrowc=$root/build/escrowc
out=$root/build/test/refusal
mkdir -p "$out"
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

# refuse NAME CODE DEF LINE...: escrowc check of the program LINE... exits 1
# with stderr "escrowc: CODE: DEF: ...".
refuse() {
  name=$1 code=$2 def=$3
  shift 3
  printf '%s\n' "$@" > "$out/$name.esc"
  "$escrowc" check "$out/$name.esc" > /dev/null 2> "$out/$name.err"
  status=$?
  err=$(cat "$out/$name.err")
  case $err in
    "escrowc: $code: $def: "*) shape=1 ;;
    *) shape=0 ;;
  esac
  if [ "$status" -eq 1 ] && [ "$shape" -eq 1 ]; then pass "$name"; else fail "$name: exit $status, stderr: $err"; fi
}

# refuse_build NAME CODE DEF FILE: escrowc build of FILE exits 1 with stderr
# "escrowc: CODE: DEF: ...". Only build reaches REFUSE_ADDRESSES.
refuse_build() {
  name=$1 code=$2 def=$3 file=$4
  "$escrowc" build "$file" -o "$out/$name.hex" > /dev/null 2> "$out/$name.err"
  status=$?
  err=$(cat "$out/$name.err")
  case $err in
    "escrowc: $code: $def: "*) shape=1 ;;
    *) shape=0 ;;
  esac
  if [ "$status" -eq 1 ] && [ "$shape" -eq 1 ]; then pass "$name"; else fail "$name: exit $status, stderr: $err"; fi
}

members='def members : Nat := 3'

refuse members-missing REFUSE_MEMBERS - 'def x : Nat := 0'
refuse members-zero REFUSE_MEMBERS - 'def members : Nat := 0'
refuse members-not-literal REFUSE_MEMBERS - 'def members : Nat := natAdd 1 2'
refuse members-empty REFUSE_MEMBERS - ''
refuse program-mu REFUSE_MU Flag "$members" 'mu Flag : Type 0 := | up : Flag'
refuse program-rec REFUSE_REC f "$members" 'def rec f : Nat -> Nat := fun (n : Nat) => n'
for form in nu axiom contract storage entry payable constructor fallback error invariant predicate proof guard sload sstore; do
  refuse "form-$form" REFUSE_FORM - "$members" "$form x : Nat := 0"
done
refuse prelude-name REFUSE_PRELUDE_NAME decide "$members" 'def decide : Nat := 0'
refuse builtin-name REFUSE_PRELUDE_NAME natAdd "$members" 'def natAdd : Nat := 0'
refuse classes-late REFUSE_PRELUDE_NAME memberClasses "$members" 'def x : Nat := 0' \
  'def memberClasses : Classes := kcons 3 knil'
refuse classes-zero REFUSE_CLASS_ZERO memberClasses "$members" \
  'def memberClasses : Classes := kcons 0 (kcons 3 knil)'
refuse classes-sum REFUSE_CLASS_SUM memberClasses "$members" \
  'def memberClasses : Classes := kcons 2 (kcons 2 knil)'
refuse classes-nil REFUSE_CLASS_SUM memberClasses "$members" 'def memberClasses : Classes := knil'
refuse classes-type REFUSE_CLASS_SUM memberClasses "$members" 'def memberClasses : Nat := 3'
# decisionFlip (M7): a wrong type, a body that is not the flip and a wrong
# position refuse REFUSE_FLIP_FORM.
refuse flip-type REFUSE_FLIP_FORM decisionFlip "$members" 'def decisionFlip : Nat := 0'
refuse flip-identity REFUSE_FLIP_FORM decisionFlip "$members" \
  'def decisionFlip : Decision -> Decision := fun (d : Decision) => d'
refuse flip-hold REFUSE_FLIP_FORM decisionFlip "$members" \
  'def decisionFlip : Decision -> Decision := decide Decision refund release release'
refuse flip-late REFUSE_FLIP_FORM decisionFlip "$members" 'def x : Nat := 0' \
  'def decisionFlip : Decision -> Decision := flipDecision'
# memberClasses (M6): above 128 table rows, a build with 2 or more classes
# refuses REFUSE_TABLE_SIZE.
refuse_build classes-size-two REFUSE_TABLE_SIZE memberClasses "$root/test/fixtures/two-classes-14.esc"
refuse_build classes-size-trivial REFUSE_TABLE_SIZE memberClasses "$root/test/fixtures/trivial-classes-14.esc"

refuse duplicate TYPE_DUPLICATE x "$members" 'def x : Nat := 0' 'def x : Nat := 1'
refuse scope TYPE_SCOPE x "$members" 'def x : Nat := y'
refuse mismatch TYPE_MISMATCH x "$members" 'def x : Nat := release'
refuse shape TYPE_SHAPE x "$members" 'def x : Nat := 0 1'
refuse infer TYPE_INFER x "$members" 'def x : Nat := (fun (n : Nat) => n) 0'
refuse universe TYPE_UNIVERSE x "$members" 'def x : Type 1 := Type 1'
refuse erased TYPE_ERASED f "$members" 'def f : (0 n : Nat) -> Nat := fun (0 n : Nat) => n'
refuse erased-flag TYPE_ERASED f "$members" 'def f : (0 n : Nat) -> Nat := fun (n : Nat) => 0'
refuse erased-projection TYPE_ERASED f "$members" \
  'def f : (p : (0 n : Nat) * Nat) -> Nat := fun (p : (0 n : Nat) * Nat) => p.0'
refuse match-family TYPE_MATCH x "$members" 'def x : Nat := match release as d in Ballots return Nat with | bnil => 0 | bcons h t => 1'
refuse match-arms TYPE_MATCH x "$members" 'def x : Nat := match release as d in Decision return Nat with | release => 0 | refund => 1'
# M9 chunk 1: the prove fixtures under check keep the old refusals.
refuse prove-nat-check REFUSE_REC dbl "$(cat "$root/test/fixtures/prove-nat.esc")"
refuse nat-match-check TYPE_MATCH predNat "$(cat "$root/test/fixtures/nat-match.esc")"
refuse nat-overflow TYPE_NAT x "$members" 'def x : Nat := natAdd 18446744073709551615 1'

# memberAddresses (M4): the length must be members, each address below
# 2^160, no address twice; a 0x literal has 1 to 64 hex digits.
a1=0x1000000000000000000000000000000000000001
a2=0x2000000000000000000000000000000000000002
refuse address-count REFUSE_ADDRESS_COUNT memberAddresses "$members" \
  "def memberAddresses : Addresses := acons $a1 (acons $a2 anil)"
refuse address-range REFUSE_ADDRESS_RANGE memberAddresses "$members" \
  "def memberAddresses : Addresses := acons $a1 (acons $a2 (acons 0x10000000000000000000000000000000000000000 anil))"
refuse address-repeat REFUSE_ADDRESS_REPEAT memberAddresses "$members" \
  "def memberAddresses : Addresses := acons $a1 (acons $a2 (acons $a1 anil))"
# An Arrow-Debreu program without memberAddresses passes check. build refuses it.
refuse_build addresses-missing REFUSE_ADDRESSES memberAddresses "$root/test/mutants/debreu-no-addresses.esc"
# A program that states decisionFlip with a table that does not commute with
# the flip passes check. build refuses it before it writes the output (M7).
refuse_build flip-table REFUSE_FLIP_TABLE decisionFlip "$root/test/mutants/debreu-flip-table.esc"
refuse lex-hex-65 LEX_HEX a "$members" 'def a : Nat := 0x10000000000000000000000000000000000000000000000000000000000000000'

if [ "$failures" -eq 0 ]; then echo "refusal.sh: all passed"; exit 0; fi
echo "refusal.sh: $failures failed"
exit 1
