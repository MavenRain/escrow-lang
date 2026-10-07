#!/bin/zsh
# usage: zsh gen/contract.sh N impossibility
#        zsh gen/contract.sh N debreu C_0 .. C_{T-1}
# Writes the contract file of a program with N members to stdout, in assay
# surface syntax (SPEC sections 7 and 8, O12).  C_i is the decision code of
# tally i in the order of gen/table.sh: release 1, refund 2, hold 3.
#
# The constructor writes two lookup mappings.  `weight` maps the
# ballot codes 1, 2 and 3 to 1, N + 1 and 0, so the sum of the weights of
# the ballots is r + (N + 1) f, one key per tally.  `verdict` maps that key
# to the decision code.  `settle` branches on the certified decision.  No
# entry writes `weight` or `verdict`.
set -euo pipefail
usage() {
  print -u2 -r -- 'usage: zsh gen/contract.sh N impossibility | zsh gen/contract.sh N debreu C_0 .. C_{T-1}'
  exit 2
}
(( $# >= 2 )) || usage
n=$1 regime=$2
shift 2
[[ $n =~ '^(0|[1-9][0-9]*)$' ]] || usage
case $regime in
  impossibility) (( $# == 0 )) || usage ;;
  debreu)
    # The supported emission range is validated through N = 8.
    # Larger inputs remain refused; amend's table fits within one word.
    [[ $n == [0-8] ]] || { print -u2 -r -- "contract: debreu needs N <= 8 (validated emission range), got $n"; exit 2 }
    (( $# == (n + 1) * (n + 2) / 2 )) || {
      print -u2 -r -- "contract: $(( (n + 1) * (n + 2) / 2 )) codes needed for N = $n, got $#"
      exit 2
    }
    for code in "$@"; do
      [[ $code == [123] ]] || { print -u2 -r -- "contract: each code must be 1, 2 or 3"; exit 2 }
    done ;;
  *) usage ;;
esac
codes=("$@")

# Calculate amend before emitting any source. A failed calculator must not
# leave a successful-looking contract with an empty word literal.
if [[ $regime == debreu ]]; then
  horner=${codes[-1]}
  for (( i = ${#codes} - 1; i >= 1; i-- )); do
    horner="$codes[$i] + 4 * ($horner)"
  done
  packed=$(print -r -- "$horner" | BC_LINE_LENGTH=0 bc)
  [[ $packed =~ '^[0-9]+$' ]] || { print -u2 -r -- 'contract: invalid packed table'; exit 1 }
fi

print -r -- "-- Written by escrow-lang gen/contract.sh: members $n, regime $regime."
print -r -- '-- Do not edit.  The kernel file holds the program and its proofs.'
print -r -- 'contract EscrowDAO where'
print -r -- '  storage State := {'
print -r -- '    ledger : Mapping Address Uint256 ;'
print -r -- '    claimCount : Word ;'
print -r -- '    payer : Mapping Uint256 Address ;'
print -r -- '    payee : Mapping Uint256 Address ;'
[[ $regime == debreu ]] && {
  print -r -- '    amount : Mapping Uint256 Uint256 ;'
  print -r -- '    weight : Mapping Uint256 Uint256 ;'
  print -r -- '    verdict : Mapping Uint256 Uint256'
} || print -r -- '    amount : Mapping Uint256 Uint256'
print -r -- '  }'

# deposit p q n: guard n <= callvalue, credit p, append the claim (p, q, n).
# It returns the index of the new claim.
print -r -- '  payable entry deposit (p : Word) (q : Word) (n : Word) : Eff Sig Word := do'
print -r -- '    v <- callvalue ; guard le n v ;'
print -r -- '    bp <- sload ledger p ; bp1 <- add bp n ; sstore ledger p bp1 ;'
print -r -- '    i <- sload claimCount ;'
print -r -- '    sstore payer i p ; sstore payee i q ; sstore amount i n ;'
print -r -- '    j <- add i (word 1) ; sstore claimCount j ; pure i'

[[ $regime == debreu ]] || exit 0

ballots=''
for (( m = 0; m < n; m++ )); do ballots+=" (b$m : Word)"; done
# The tally key of the ballots b0 .. b(N-1), bound to k$n.
tally() {
  print -r -- '    let k0 : Word := word 0 ;'
  for (( m = 0; m < n; m++ )); do
    print -r -- "    guard le (word 1) b$m ; guard le b$m (word 3) ; w$m <- sload weight b$m ; k$((m + 1)) <- add k$m w$m ;"
  done
  print -r -- "    d <- sload verdict k$n ;"
}

# cast x: the verdict of the ballots.  It writes nothing.
cast_args=$ballots
[[ -n $cast_args ]] || cast_args=' ()'
print -r -- "  entry cast$cast_args : Eff Sig Word := do"
tally
print -r -- '    pure d'

# settle c x: the claim with index c and the ballots x (design section 3).
# The guard a <= bp is the proof h of SPEC section 5.
print -r -- "  entry settle (c : Word)$ballots : Eff Sig Word := do"
tally
print -r -- '    p <- sload payer c ; a <- sload amount c ;'
print -r -- '    bp <- sload ledger p ; guard le a bp ;'
print -r -- '    if le d (word 1) then'
print -r -- '      bp1 <- sub bp a ; sstore ledger p bp1 ;'
print -r -- '      q <- sload payee c ; bq <- sload ledger q ; bq1 <- add bq a ; sstore ledger q bq1 ;'
print -r -- '      pure d'
print -r -- '    else if le d (word 2) then'
print -r -- '      bp1 <- sub bp a ; sstore ledger p bp1 ;'
print -r -- '      pure d'
print -r -- '    else pure d'

# amend at the canonical Phi: the packed table sum C_i * 4^i (SPEC O5).
print -r -- "  entry amend () : Eff Sig Word := do pure (word $packed)"

# The lookup tables.  Tally i = (r, f, h) has the key r + (N + 1) f.
print -r -- '  constructor := do'
print -r -- "    sstore weight (word 1) (word 1) ; sstore weight (word 2) (word $((n + 1))) ;"
i=1
for r in {0..$n}; do
  for f in {0..$((n - r))}; do
    print -r -- "    sstore verdict (word $((r + (n + 1) * f))) (word $codes[$i]) ;"
    i=$((i + 1))
  done
done
print -r -- '    pure ()'
