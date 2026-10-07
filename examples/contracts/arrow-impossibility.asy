-- Written by escrow-lang gen/contract.sh: members 3, regime impossibility.
-- Do not edit.  The kernel file holds the program and its proofs.
contract EscrowDAO where
  storage State := {
    ledger : Mapping Address Uint256 ;
    claimCount : Word ;
    payer : Mapping Uint256 Address ;
    payee : Mapping Uint256 Address ;
    amount : Mapping Uint256 Uint256
  }
  payable entry deposit (p : Word) (q : Word) (n : Word) : Eff Sig Word := do
    v <- callvalue ; guard le n v ;
    bp <- sload ledger p ; bp1 <- add bp n ; sstore ledger p bp1 ;
    i <- sload claimCount ;
    sstore payer i p ; sstore payee i q ; sstore amount i n ;
    j <- add i (word 1) ; sstore claimCount j ; pure i
