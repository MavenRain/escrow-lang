/* Check proof-mode declarations and keep the ordinary checker refusals. */
#include "../src/check.h"
#include "../src/prelude.h"
#include <string.h>

typedef struct {
  const char *name;
  const char *source;
  int prove;
  const char *code;
  EscrowRegime regime;
} Case;

#define MEMBERS "def members : Nat := 3\n"
#define CHOICE_BODY \
  "F : ChoiceRule := fun (x : Config) =>\n" \
  "  match x as c in Config return Decision with\n" \
  "  | mkConfig xs e => hold\n" \
  "def H : Tally -> Decision := fun (t : Tally) => hold\n" \
  "def agg : Aggregation F := mkAgg F H (fun (x : Config) =>\n" \
  "  match x as c in Config return EqDec (F c) hold with\n" \
  "  | mkConfig xs e => reflDec hold)\n"
#define NAT_REC \
  "def rec ident : Nat -> Nat := fun (n : Nat) =>\n" \
  "  match n as q in Nat return Nat with\n" \
  "  | zero => 0\n" \
  "  | succ k => natAdd (ident k) 1\n"

static int run_case(const Case *test) {
  Arena arena;
  Diag diag;
  Program prelude, program;
  EscrowChecked *checked = NULL;
  arena_init(&arena, ESCROW_ARENA_MAX);
  diag_init(&diag);
  int status = escrow_parse(&arena, escrow_prelude_name, (const char *)escrow_prelude_text,
                            escrow_prelude_size, &prelude, &diag);
  if (status == ESCROW_EXIT_OK)
    status = escrow_parse(&arena, "prove-check.esc", test->source, strlen(test->source), &program, &diag);
  if (status == ESCROW_EXIT_OK)
    status = escrow_check_as(&arena, &prelude, &program, test->prove, &checked, &diag);
  int ok = test->code == NULL
    ? status == ESCROW_EXIT_OK && diag.code == NULL && escrow_regime(checked) == test->regime
    : status == ESCROW_EXIT_REFUSED && diag.code != NULL && strcmp(diag.code, test->code) == 0;
  printf("%s prove %s\n", ok ? "ok  " : "FAIL", test->name);
  if (!ok) {
    if (diag.code != NULL)
      diag_print(&diag, stderr);
    else if (checked != NULL)
      fprintf(stderr, "expected regime %d, got %d\n", test->regime, escrow_regime(checked));
  }
  arena_free(&arena);
  return ok;
}

int main(void) {
  static const Case cases[] = {
    {"ordinary choice", MEMBERS "def " CHOICE_BODY, 1, NULL, ESCROW_REGIME_DEBREU},
    {"recursive choice", MEMBERS "def rec " CHOICE_BODY, 1, NULL, ESCROW_REGIME_DEBREU},
    {"recursive choice under check", MEMBERS "def rec " CHOICE_BODY,
     0, "REFUSE_REC", ESCROW_REGIME_IMPOSSIBILITY},
    {"Nat recursion", MEMBERS NAT_REC
     "def three : EqNat (ident 3) 3 := reflNat 3\n",
     1, NULL, ESCROW_REGIME_IMPOSSIBILITY},
    {"Nat recursion under check", MEMBERS NAT_REC,
     0, "REFUSE_REC", ESCROW_REGIME_IMPOSSIBILITY},
    {"duplicate program recursion", MEMBERS NAT_REC
     "def ident : Nat -> Nat := fun (n : Nat) => n\n",
     1, "TYPE_DUPLICATE", ESCROW_REGIME_IMPOSSIBILITY},
    {"prelude recursion name", MEMBERS
     "def foldBallots : Nat := 0\n",
     1, "REFUSE_PRELUDE_NAME", ESCROW_REGIME_IMPOSSIBILITY},
    {"nondecreasing recursion", MEMBERS
     "def rec loop : Nat -> Nat := fun (n : Nat) =>\n"
     "  match n as q in Nat return Nat with\n"
     "  | zero => 0\n"
     "  | succ k => loop n\n",
     1, "TYPE_REC", ESCROW_REGIME_IMPOSSIBILITY},
    {"successor offset conversion", MEMBERS
     "def offsets : (x : Nat) -> EqNat (natAdd (natAdd x 2) 3) (natAdd x 5) :=\n"
     "  fun (x : Nat) => reflNat (natAdd x 5)\n",
     1, NULL, ESCROW_REGIME_IMPOSSIBILITY},
    {"distinct natural numbers", MEMBERS
     "def unequal : EqNat 0 1 := reflNat 0\n",
     1, "TYPE_MISMATCH", ESCROW_REGIME_IMPOSSIBILITY},
    {"distinct tally data", MEMBERS
     "def unequal : EqTally\n"
     "  (mkTally (tcons (tuple (3, tuple (0, 0))) tnil) (reflNat 3))\n"
     "  (mkTally (tcons (tuple (0, tuple (3, 0))) tnil) (reflNat 3)) :=\n"
     "  reflTally (mkTally (tcons (tuple (3, tuple (0, 0))) tnil) (reflNat 3))\n",
     1, "TYPE_MISMATCH", ESCROW_REGIME_IMPOSSIBILITY}
  };
  int failures = 0;
  for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++)
    failures += !run_case(&cases[i]);
  if (failures == 0)
    puts("prove-check: all passed");
  return failures == 0 ? 0 : 1;
}
