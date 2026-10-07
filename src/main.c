/* escrowc, the escrow-lang compiler (PLAN.md):
 *   escrowc check PROG                    ok debreu | ok impossibility
 *   escrowc table PROG                    REGIME MEMBERS [CODES...]
 *   escrowc verdicts PROG NAME            one digit per ballot vector
 *   escrowc eval PROG NAME                the normal form of NAME
 *   escrowc build PROG [--runtime] -o OUT the contract
 * Exit 0 ok, 1 refused, 2 usage or IO; errors go to stderr as
 * "escrowc: CODE: DEF: message". This front end parses the embedded prelude
 * and PROG, then refuses each verb with UNIMPLEMENTED until the checker
 * lands. */
#include "prelude.h"
#include "syntax.h"
#include <string.h>

typedef struct {
  const char *name;
  int argc;  /* argc with the verb, PROG and NAME; build adds -o OUT */
} Verb;

static const Verb VERBS[] = {
  {"check", 3}, {"table", 3}, {"verdicts", 4}, {"eval", 4}, {"build", 5}
};

static int usage(void) {
  fputs("escrowc: USAGE: -: escrowc check|table PROG, escrowc verdicts|eval PROG NAME,"
        " escrowc build PROG [--runtime] -o OUT\n", stderr);
  return ESCROW_EXIT_USAGE;
}

static const Verb *find_verb(const char *name) {
  for (size_t i = 0; i < sizeof VERBS / sizeof VERBS[0]; i++)
    if (strcmp(VERBS[i].name, name) == 0)
      return &VERBS[i];
  return NULL;
}

/* build PROG -o OUT or build PROG --runtime -o OUT */
static int build_fits(int argc, char **argv) {
  int runtime = argc == 6 && strcmp(argv[3], "--runtime") == 0;
  return (argc == 5 || runtime) && strcmp(argv[runtime ? 4 : 3], "-o") == 0;
}

static int arguments_fit(const Verb *verb, int argc, char **argv) {
  if (strcmp(verb->name, "build") == 0)
    return build_fits(argc, argv);
  return argc == verb->argc;
}

static int run(Arena *arena, const Verb *verb, const char *path, Diag *diag) {
  Program prelude;
  const char *prelude_text = (const char *)escrow_prelude_text;
  int status = escrow_parse(arena, escrow_prelude_name, prelude_text, escrow_prelude_size, &prelude, diag);
  if (status != ESCROW_EXIT_OK)
    return status;
  const char *text = NULL;
  size_t size = 0;
  status = escrow_read_source(arena, path, &text, &size, diag);
  if (status != ESCROW_EXIT_OK)
    return status;
  Program program;
  status = escrow_parse(arena, path, text, size, &program, diag);
  if (status != ESCROW_EXIT_OK)
    return status;
  diag_set(diag, "UNIMPLEMENTED", span_of("-"), "escrowc %s is not implemented yet", verb->name);
  return ESCROW_EXIT_REFUSED;
}

int main(int argc, char **argv) {
  const Verb *verb = argc < 3 ? NULL : find_verb(argv[1]);
  if (verb == NULL || !arguments_fit(verb, argc, argv))
    return usage();
  Arena arena;
  Diag diag;
  arena_init(&arena, ESCROW_ARENA_MAX);
  diag_init(&diag);
  int status = run(&arena, verb, argv[2], &diag);
  diag_print(&diag, stderr);
  arena_free(&arena);
  return status;
}
