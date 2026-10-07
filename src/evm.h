#ifndef ESCROW_EVM_H
#define ESCROW_EVM_H
#include <stddef.h>
#include <stdio.h>
typedef enum { ESCROW_REGIME_IMPOSSIBILITY, ESCROW_REGIME_DEBREU } EscrowRegime;
typedef enum { ESCROW_PART_CREATION, ESCROW_PART_RUNTIME } EscrowPart;
typedef struct {
  unsigned members;            /* n >= 1 */
  EscrowRegime regime;
  const unsigned char *codes;  /* Debreu: 1 release, 2 refund, 3 hold, one per tally; NULL for impossibility */
  size_t count;                /* Debreu: (n+1)(n+2)/2, tally order r = 0..n outer, f = 0..n-r inner, h = n-r-f; 0 for impossibility */
} EscrowContract;
/* Writes lowercase hex, no 0x, one trailing newline. Returns 0, or nonzero after writing "escrowc: EVM_<CODE>: message\n" to err. */
int escrow_evm_write(const EscrowContract *contract, EscrowPart part, FILE *out, FILE *err);
#endif
