-- Written by escrow-lang gen/contract.sh: members 3, regime debreu.
-- Do not edit.  The kernel file holds the program and its proofs.
contract EscrowDAO where
  storage State := {
    ledger : Mapping Address Uint256 ;
    claimCount : Word ;
    payer : Mapping Uint256 Address ;
    payee : Mapping Uint256 Address ;
    amount : Mapping Uint256 Uint256 ;
    weight : Mapping Uint256 Uint256 ;
    verdict : Mapping Uint256 Uint256
  }
  payable entry deposit (p : Word) (q : Word) (n : Word) : Eff Sig Word := do
    v <- callvalue ; guard le n v ;
    bp <- sload ledger p ; bp1 <- add bp n ; sstore ledger p bp1 ;
    i <- sload claimCount ;
    sstore payer i p ; sstore payee i q ; sstore amount i n ;
    j <- add i (word 1) ; sstore claimCount j ; pure i
  entry cast (b0 : Word) (b1 : Word) (b2 : Word) : Eff Sig Word := do
    let k0 : Word := word 0 ;
    guard le (word 1) b0 ; guard le b0 (word 3) ; w0 <- sload weight b0 ; k1 <- add k0 w0 ;
    guard le (word 1) b1 ; guard le b1 (word 3) ; w1 <- sload weight b1 ; k2 <- add k1 w1 ;
    guard le (word 1) b2 ; guard le b2 (word 3) ; w2 <- sload weight b2 ; k3 <- add k2 w2 ;
    d <- sload verdict k3 ;
    pure d
  entry settleRelease (c : Word) (b0 : Word) (b1 : Word) (b2 : Word) : Eff Sig Word := do
    let k0 : Word := word 0 ;
    guard le (word 1) b0 ; guard le b0 (word 3) ; w0 <- sload weight b0 ; k1 <- add k0 w0 ;
    guard le (word 1) b1 ; guard le b1 (word 3) ; w1 <- sload weight b1 ; k2 <- add k1 w1 ;
    guard le (word 1) b2 ; guard le b2 (word 3) ; w2 <- sload weight b2 ; k3 <- add k2 w2 ;
    d <- sload verdict k3 ;
    guard le d (word 1) ; guard le (word 1) d ;
    p <- sload payer c ; a <- sload amount c ;
    bp <- sload ledger p ; guard le a bp ;
    bp1 <- sub bp a ; sstore ledger p bp1 ;
    q <- sload payee c ; bq <- sload ledger q ; bq1 <- add bq a ; sstore ledger q bq1 ;
    pure d
  entry settleRefund (c : Word) (b0 : Word) (b1 : Word) (b2 : Word) : Eff Sig Word := do
    let k0 : Word := word 0 ;
    guard le (word 1) b0 ; guard le b0 (word 3) ; w0 <- sload weight b0 ; k1 <- add k0 w0 ;
    guard le (word 1) b1 ; guard le b1 (word 3) ; w1 <- sload weight b1 ; k2 <- add k1 w1 ;
    guard le (word 1) b2 ; guard le b2 (word 3) ; w2 <- sload weight b2 ; k3 <- add k2 w2 ;
    d <- sload verdict k3 ;
    guard le d (word 2) ; guard le (word 2) d ;
    p <- sload payer c ; a <- sload amount c ;
    bp <- sload ledger p ; guard le a bp ;
    bp1 <- sub bp a ; sstore ledger p bp1 ;
    pure d
  entry settleHold (c : Word) (b0 : Word) (b1 : Word) (b2 : Word) : Eff Sig Word := do
    let k0 : Word := word 0 ;
    guard le (word 1) b0 ; guard le b0 (word 3) ; w0 <- sload weight b0 ; k1 <- add k0 w0 ;
    guard le (word 1) b1 ; guard le b1 (word 3) ; w1 <- sload weight b1 ; k2 <- add k1 w1 ;
    guard le (word 1) b2 ; guard le b2 (word 3) ; w2 <- sload weight b2 ; k3 <- add k2 w2 ;
    d <- sload verdict k3 ;
    guard le d (word 3) ; guard le (word 3) d ;
    p <- sload payer c ; a <- sload amount c ;
    bp <- sload ledger p ; guard le a bp ;
    pure d
  entry amend () : Eff Sig Word := do pure (word 356271)
  constructor := do
    sstore weight (word 1) (word 1) ; sstore weight (word 2) (word 4) ;
    sstore verdict (word 0) (word 3) ;
    sstore verdict (word 4) (word 3) ;
    sstore verdict (word 8) (word 2) ;
    sstore verdict (word 12) (word 2) ;
    sstore verdict (word 1) (word 3) ;
    sstore verdict (word 5) (word 3) ;
    sstore verdict (word 9) (word 2) ;
    sstore verdict (word 2) (word 1) ;
    sstore verdict (word 6) (word 1) ;
    sstore verdict (word 3) (word 1) ;
    pure ()
