/* Check the decisionFlip annotation before its body, including annotations
 * whose bodies would otherwise fail with a general type mismatch. */
#include "../src/check.h"
#include "../src/prelude.h"
#include <string.h>

typedef struct {
  const char *name;
  const char *source;
  const char *code;
} Case;

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
    status = escrow_parse(&arena, "flip-form.esc", test->source, strlen(test->source), &program, &diag);
  if (status == ESCROW_EXIT_OK)
    status = escrow_check(&arena, &prelude, &program, &checked, &diag);
  int ok = test->code == NULL
    ? status == ESCROW_EXIT_OK && diag.code == NULL
    : status == ESCROW_EXIT_REFUSED && diag.code != NULL && strcmp(diag.code, test->code) == 0 &&
      strcmp(diag.def, "decisionFlip") == 0;
  printf("%s decisionFlip %s\n", ok ? "ok  " : "FAIL", test->name);
  if (!ok)
    diag_print(&diag, stderr);
  arena_free(&arena);
  return ok;
}

int main(void) {
  static const Case cases[] = {
    {"wrong arrow before body mismatch",
     "def members : Nat := 3\n"
     "def decisionFlip : Nat -> Nat := flipDecision\n", "REFUSE_FLIP_FORM"},
    {"erased domain before body mismatch",
     "def members : Nat := 3\n"
     "def decisionFlip : (0 d : Decision) -> Decision := flipDecision\n", "REFUSE_FLIP_FORM"},
    {"wrong arrow after memberClasses",
     "def members : Nat := 3\n"
     "def memberClasses : Classes := kcons 2 (kcons 1 knil)\n"
     "def decisionFlip : Nat -> Nat := flipDecision\n", "REFUSE_FLIP_FORM"},
    {"valid alias",
     "def members : Nat := 3\n"
     "def decisionFlip : Decision -> Decision := flipDecision\n", NULL},
    {"body mismatch with valid annotation",
     "def members : Nat := 3\n"
     "def decisionFlip : Decision -> Decision := 0\n", "TYPE_MISMATCH"}
  };
  int failures = 0;
  for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++)
    failures += !run_case(&cases[i]);
  if (failures == 0)
    puts("flip-form: all passed");
  return failures == 0 ? 0 : 1;
}
