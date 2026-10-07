#!/bin/sh
# Front end tests of escrowc, run by make test after make. Files go to
# build/test. Each run stays far under 4 GB: the arena of one run takes at
# most ESCROW_ARENA_MAX (256 MiB, src/syntax.h).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
tool=$root/build/parsetool
escrowc=$root/build/escrowc
out=$root/build/test
mkdir -p "$out"
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

# check NAME STATUS WANT_STATUS ERRFILE WANT_PREFIX
check() {
  err=$(cat "$4")
  case $err in
    "$5"*) prefix_ok=1 ;;
    *) prefix_ok=0 ;;
  esac
  if [ "$2" -eq "$3" ] && [ "$prefix_ok" -eq 1 ]; then pass "$1"; else fail "$1: exit $2, stderr: $err"; fi
}

# Parse, print, parse the print and print again: the two prints are the same.
for file in prelude/Prelude.esc examples/programs/arrow-debreu.esc examples/programs/arrow-impossibility.esc test/parser-arms.esc; do
  name=$(basename "$file" .esc)
  "$tool" "$root/$file" > "$out/$name.1" 2> "$out/$name.err"
  first=$?
  "$tool" "$out/$name.1" > "$out/$name.2" 2>> "$out/$name.err"
  second=$?
  if [ "$first" -eq 0 ] && [ "$second" -eq 0 ] && cmp -s "$out/$name.1" "$out/$name.2"; then
    pass "parse and round trip $file ($(wc -l < "$out/$name.1" | tr -d ' ') lines)"
  else
    fail "parse and round trip $file: exit $first $second, $(cat "$out/$name.err")"
  fi
done

if "$tool" --prelude | cmp -s - "$root/prelude/Prelude.esc"; then
  pass "the embedded prelude is prelude/Prelude.esc"
else
  fail "the embedded prelude is prelude/Prelude.esc"
fi

# refuse NAME CODE DEF TEXT: parsetool exits 1 with "escrowc: CODE: DEF: ".
refuse() {
  printf '%s\n' "$4" > "$out/$1.esc"
  "$tool" "$out/$1.esc" > /dev/null 2> "$out/$1.err"
  check "$1 is $2" $? 1 "$out/$1.err" "escrowc: $2: $3: $out/$1.esc:"
}

refuse bad-token LEX_TOKEN x 'def x : Nat := natAdd 1 $ 2'
refuse big-number LEX_NUMBER x 'def x : Nat := 123456789012345678901234567890'
refuse unclosed-paren PARSE_PAREN x 'def x : Nat := natAdd (natAdd 1 2'
refuse unmatched-paren PARSE_PAREN x 'def x : Nat := natAdd 1 2)'
refuse missing-define PARSE_EXPECT x "$(printf 'def x : Nat\ndef y : Nat := 3')"
refuse missing-term PARSE_EXPECT x 'def x : Nat :='
refuse tuple-arity PARSE_ARITY x 'def x : prod (Nat, Nat) := tuple (1)'
refuse inj-arity PARSE_ARITY x 'def x : Nat := inj 2 of 2 x'
refuse case-arity PARSE_ARITY x 'def x : Nat := case s with | 1 (a : Nat) => a | 0 (b : Nat) => b'
refuse missing-match-arm PARSE_EXPECT x 'def x : Nat := case s with | 0 (a : Nat) => match a as z in F return Nat with | 1 (b : Nat) => b'
refuse deep-parens PARSE_DEPTH x "def x : Nat := $(awk 'BEGIN { for (i = 0; i < 100000; i++) printf "("; printf "0"; for (i = 0; i < 100000; i++) printf ")" }')"
refuse deep-arrows PARSE_DEPTH x "def x : $(awk 'BEGIN { for (i = 0; i < 5000; i++) printf "Nat -> " }')Nat := 0"
refuse long-spine PARSE_DEPTH x "def x : Nat := f$(awk 'BEGIN { for (i = 0; i < 5000; i++) printf " 0" }')"

# escrowc: usage and IO exit 2, a refused file exits 1, a checked program exits 0.
"$escrowc" > /dev/null 2> "$out/usage.err"
check "escrowc with no verb is usage" $? 2 "$out/usage.err" "escrowc: USAGE: -: "
"$escrowc" frob x > /dev/null 2> "$out/usage.err"
check "escrowc frob is usage" $? 2 "$out/usage.err" "escrowc: USAGE: -: "
"$escrowc" verdicts x > /dev/null 2> "$out/usage.err"
check "escrowc verdicts without NAME is usage" $? 2 "$out/usage.err" "escrowc: USAGE: -: "
"$escrowc" build x --runtime > /dev/null 2> "$out/usage.err"
check "escrowc build without -o is usage" $? 2 "$out/usage.err" "escrowc: USAGE: -: "
"$escrowc" check "$out/no-such-file.esc" > /dev/null 2> "$out/io.err"
check "escrowc check of a missing file is IO" $? 2 "$out/io.err" "escrowc: IO_READ: -: "
"$escrowc" check "$out/bad-token.esc" > /dev/null 2> "$out/refused.err"
check "escrowc check of a bad file is refused" $? 1 "$out/refused.err" "escrowc: LEX_TOKEN: x: "
for verb in check table; do
  "$escrowc" $verb "$root/examples/programs/arrow-debreu.esc" > /dev/null 2> "$out/verb.err"
  check "escrowc $verb of arrow-debreu exits 0" $? 0 "$out/verb.err" ""
done
"$escrowc" build "$root/examples/programs/arrow-impossibility.esc" --runtime -o "$out/x.hex" > /dev/null 2> "$out/verb.err"
check "escrowc build --runtime of arrow-impossibility exits 0" $? 0 "$out/verb.err" ""

if [ "$failures" -eq 0 ]; then echo "parse.sh: all passed"; exit 0; fi
echo "parse.sh: $failures failed"
exit 1
