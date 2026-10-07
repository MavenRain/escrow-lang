#!/bin/zsh
# usage: zsh test/generator.sh [codes|zero|calculator|limits|all]
# Requires the Assay launcher used by probe/run.sh and bc.
set -euo pipefail
root=${0:A:h:h}
out=$(mktemp -d "${TMPDIR:-/tmp}/escrow-generator.XXXXXX")
case_name=${1:-all}
print -r -- "generator $case_name logs: $out"

fail() { print -u2 -r -- "$1 (logs: $out)"; exit 1; }
refuse() {
  if zsh "$root/gen/contract.sh" "$@" >"$out/refused.asy" 2>"$out/refused.err"; then
    fail "writer accepted invalid arguments: $*"
  fi
  [[ ! -s "$out/refused.asy" ]] || fail 'writer emitted a refused contract'
}

if [[ $case_name == codes || $case_name == all ]]; then
  refuse 1 debreu 12 2 3
  refuse 1 debreu 1 '' 3
  refuse 1 debreu 0 2 3
  refuse 1 debreu 1 2
  refuse 15 debreu 1
  zsh "$root/gen/contract.sh" 1 debreu 1 2 3 >"$out/one.asy"
  rg -q 'pure \(word 57\)' "$out/one.asy"
fi

if [[ $case_name == zero || $case_name == all ]]; then
  cat >"$out/zero.asy" <<'EOF'
def members : Nat := 0
def H : Tally -> Decision := fun (t : Tally) => hold
def F : ChoiceRule := fun (x : Config) => H (orbit x)
def agg : Aggregation F := mkAgg F H (fun (x : Config) => reflDec (H (orbit x)))
EOF
  codes=$(zsh "$root/gen/table.sh" "$out/zero.asy")
  [[ $codes == 3 ]] || fail "zero-member table was $codes, expected 3"
  zsh "$root/gen/contract.sh" 0 debreu "$codes" >"$out/zero-contract.asy"
  env TMPDIR="$out" zsh "$root/probe/run.sh" zero-contract check "$out/zero-contract.asy" >"$out/check.log"
  rg -q 'entry cast \(\)' "$out/zero-contract.asy"
  rg -q 'pure \(word 3\)' "$out/zero-contract.asy"
  ! rg -q 'b[0-9]+ : Word' "$out/zero-contract.asy"
  zsh "$root/gen/contract.sh" 0 impossibility >"$out/zero-impossibility.asy"
  env TMPDIR="$out" zsh "$root/probe/run.sh" zero-impossibility check "$out/zero-impossibility.asy" >"$out/impossibility.log"
fi

if [[ $case_name == calculator || $case_name == all ]]; then
  mkdir "$out/bin"
  print -rl -- '#!/bin/sh' 'exit 17' >"$out/bin/bc"
  chmod +x "$out/bin/bc"
  if env PATH="$out/bin:$PATH" zsh "$root/gen/contract.sh" 1 debreu 1 2 3 >"$out/failed.asy" 2>"$out/failed.err"; then
    fail 'writer accepted a failed table calculation'
  fi
  [[ ! -s "$out/failed.asy" ]] || fail 'writer emitted a contract after table calculation failed'
fi

if [[ $case_name == limits || $case_name == all ]]; then
  codes=()
  for (( i = 0; i < 55; i++ )); do codes+=(3); done
  refuse 9 debreu "${codes[@]}"
  codes=()
  for (( i = 0; i < 45; i++ )); do codes+=(3); done
  zsh "$root/gen/contract.sh" 8 debreu "${codes[@]}" >"$out/max.asy"
  env TMPDIR="$out" zsh "$root/probe/run.sh" max check "$out/max.asy" >"$out/max-check.log"
  env TMPDIR="$out" zsh "$root/probe/run.sh" max-emit emit "$out/max.asy" -o "$out/max-emit" >"$out/max-emit.log"
fi

case $case_name in codes|zero|calculator|limits|all) ;; *) fail "unknown case: $case_name" ;; esac
print -r -- "generator $case_name regressions passed (logs: $out)"
