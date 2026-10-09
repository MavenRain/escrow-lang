/* Class-sensitive source evaluation and the single-class table boundary. */
#include "../src/check.h"
#include "../src/prelude.h"
#include <string.h>

static int run_case(const char *name, const char *classes, int multi) {
  static const char *const format =
    "def members : Nat := 3\n%s"
    "def firstCounts : Tallies -> T3 := fun (ts : Tallies) =>\n"
    "  match ts as w in Tallies return T3 with\n"
    "  | tnil => tuple (0, tuple (0, 0))\n"
    "  | tcons t rest => t\n"
    "def H : Tally -> Decision := fun (t : Tally) =>\n"
    "  case natEq (firstCounts (classCounts t)).0 2 with\n"
    "  | 0 (u : prod ()) => refund\n"
    "  | 1 (u : prod ()) => release\n"
    "def F : ChoiceRule := fun (x : Config) => H (orbit x)\n"
    "def agg : Aggregation F := mkAgg F H (fun (x : Config) => reflDec (H (orbit x)))\n"
    "def x : Config := mkConfig (bcons release (bcons refund (bcons release bnil))) (reflNat 3)\n"
    "def sourceVerdict : Decision := gov F agg x\n";
  char source[2048];
  int length = snprintf(source, sizeof source, format, classes);
  if (length < 0 || (size_t)length >= sizeof source)
    return 1;
  Arena arena;
  Diag diag;
  Program prelude, program;
  EscrowChecked *checked = NULL;
  arena_init(&arena, ESCROW_ARENA_MAX);
  diag_init(&diag);
  int status = escrow_parse(&arena, "prelude/Prelude.esc", (const char *)escrow_prelude_text, escrow_prelude_size,
                            &prelude, &diag);
  if (status == ESCROW_EXIT_OK)
    status = escrow_parse(&arena, name, source, (size_t)length, &program, &diag);
  if (status == ESCROW_EXIT_OK)
    status = escrow_check(&arena, &prelude, &program, &checked, &diag);
  int failed = status != ESCROW_EXIT_OK;
  FILE *out = failed ? NULL : tmpfile();
  if (out == NULL) {
    failed = 1;
  } else {
    status = escrow_eval(checked, "sourceVerdict", out);
    rewind(out);
    char verdict[32];
    if (status != ESCROW_EXIT_OK || fgets(verdict, sizeof verdict, out) == NULL ||
        strcmp(verdict, multi ? "refund\n" : "release\n") != 0)
      failed = 1;
    fclose(out);
  }
  if (!failed) {
    const unsigned char *codes = NULL;
    size_t count = 0;
    status = escrow_table(checked, &codes, &count);
    if (multi) {
      if (status != ESCROW_EXIT_REFUSED || codes != NULL || count != 0 || diag.code == NULL ||
          strcmp(diag.code, "REFUSE_CLASS_TABLE") != 0 || strcmp(diag.def, "memberClasses") != 0)
        failed = 1;
    } else if (status != ESCROW_EXIT_OK || codes == NULL || count != 10 || codes[8] != 1) {
      failed = 1;
    }
  }
  if (failed) {
    fprintf(stderr, "FAIL class table %s\n", name);
    diag_print(&diag, stderr);
  } else {
    printf("ok   class table %s\n", name);
  }
  arena_free(&arena);
  return failed;
}

int main(void) {
  int failures = 0;
  failures += run_case("default", "", 0);
  failures += run_case("one", "def memberClasses : Classes := kcons 3 knil\n", 0);
  failures += run_case("two", "def memberClasses : Classes := kcons 2 (kcons 1 knil)\n", 1);
  failures += run_case("three", "def memberClasses : Classes := kcons 1 (kcons 1 (kcons 1 knil))\n", 1);
  return failures != 0;
}
