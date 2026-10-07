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
 * order of src/evm.h. Impossibility: no codes. */
int escrow_table(EscrowChecked *checked, const unsigned char **codes, size_t *count);
/* One digit per ballot vector of the ChoiceRule NAME, in the product order
 * of test/differential.py, then a newline. */
int escrow_verdicts(EscrowChecked *checked, const char *name, FILE *out);
/* The normal form of NAME, then a newline. */
int escrow_eval(EscrowChecked *checked, const char *name, FILE *out);
#endif
