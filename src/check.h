/* The escrowc checker (PLAN.md chunk 3; SPEC sections 2 to 6).
 *
 * escrow_check checks the program's `def members : Nat := N` first, then
 * the embedded prelude, then the rest of the program. The regime is Debreu
 * when the program defines `agg : Aggregation G` for a program definition
 * `G : ChoiceRule`, and impossibility otherwise. Errors go to the Diag of
 * the run as "escrowc: CODE: DEF: message":
 *
 *   REFUSE_MEMBERS, REFUSE_MU, REFUSE_REC, REFUSE_FORM, REFUSE_PRELUDE_NAME
 *     the refusal list of SPEC section 2;
 *   REFUSE_ADDRESS_COUNT, REFUSE_ADDRESS_RANGE, REFUSE_ADDRESS_REPEAT
 *     the def memberAddresses of a program (M4, both regimes);
 *   REFUSE_ADDRESSES
 *     a Debreu program without def memberAddresses at build (M4);
 *   REFUSE_CLASS_ZERO, REFUSE_CLASS_SUM
 *     invalid member class sizes (M6);
 *   REFUSE_CLASS_TABLE
 *     a Debreu build with multiple member classes (M6; chunk 3 lifts it);
 *   REFUSE_TABLE_SIZE
 *     a Debreu table with multiple member classes and more than 128 rows (M6);
 *   TYPE_SCOPE, TYPE_DUPLICATE, TYPE_MISMATCH (with both normal forms),
 *   TYPE_SHAPE, TYPE_INFER, TYPE_UNIVERSE, TYPE_ERASED, TYPE_MATCH, TYPE_MU,
 *   TYPE_REC, TYPE_NAT, TYPE_FUEL, TYPE_INTERNAL, MEMORY
 *     the checker;
 *   VERDICT_TYPE, VERDICT_LIMIT, TABLE_STUCK
 *     the verbs. */
#ifndef ESCROW_CHECK_H
#define ESCROW_CHECK_H
#include "evm.h"
#include "syntax.h"

typedef struct EscrowChecked EscrowChecked;

/* Returns ESCROW_EXIT_OK and the checked program in *CHECKED, or
 * ESCROW_EXIT_REFUSED with the first error in DIAG. DIAG must stay alive
 * while *CHECKED is used. */
int escrow_check(Arena *arena, const Program *prelude, const Program *program,
                 EscrowChecked **checked, Diag *diag);
EscrowRegime escrow_regime(const EscrowChecked *checked);
unsigned escrow_members(const EscrowChecked *checked);

/* Debreu: one decision code (1 release, 2 refund, 3 hold) per tally, in the
 * order of src/evm.h. With multiple member classes, the rows are class blocks
 * in a mixed radix, class 1 the outer digit (M6). Impossibility: no codes. */
int escrow_table(EscrowChecked *checked, const unsigned char **codes, size_t *count);
/* Debreu with multiple member classes: REFUSE_CLASS_TABLE until the runtime
 * indexes the class blocks (M6 chunk 3). Otherwise ESCROW_EXIT_OK. */
int escrow_build_classes(EscrowChecked *checked);
/* Debreu: the addresses of def memberAddresses, one word of 32 bytes for
 * each member, in the order of src/evm.h; REFUSE_ADDRESSES without the def.
 * Impossibility: NULL (the build writes nothing for them). */
int escrow_addresses(EscrowChecked *checked, const unsigned char **addresses);
/* One digit per ballot vector of the ChoiceRule NAME, in the product order
 * of test/differential.py, then a newline. */
int escrow_verdicts(EscrowChecked *checked, const char *name, FILE *out);
/* The normal form of NAME, then a newline. */
int escrow_eval(EscrowChecked *checked, const char *name, FILE *out);
#endif
