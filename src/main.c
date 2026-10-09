/* escrowc, the escrow-lang compiler (PLAN.md):
 *   escrowc check PROG                    ok debreu | ok impossibility
 *   escrowc table PROG                    REGIME MEMBERS [CODES...]
 *   escrowc verdicts PROG NAME            one digit per ballot vector
 *   escrowc eval PROG NAME                the normal form of NAME
 *   escrowc build PROG [--runtime] -o OUT the contract
 * Exit 0 ok, 1 refused, 2 usage or IO; errors go to stderr as
 * "escrowc: CODE: DEF: message". Each verb parses the embedded prelude and
 * PROG and checks them (src/check.h) first. */
#include "check.h"
#include "prelude.h"
#include <errno.h>
#include <string.h>

typedef enum { VERB_CHECK, VERB_TABLE, VERB_VERDICTS, VERB_EVAL, VERB_BUILD } VerbKind;

typedef struct {
  const char *name;
  VerbKind kind;
  int argc;  /* argc with the verb, PROG and NAME; build adds -o OUT */
} Verb;

static const Verb VERBS[] = {
  {"check", VERB_CHECK, 3}, {"table", VERB_TABLE, 3}, {"verdicts", VERB_VERDICTS, 4},
  {"eval", VERB_EVAL, 4}, {"build", VERB_BUILD, 5}
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
  if (verb->kind == VERB_BUILD)
    return build_fits(argc, argv);
  return argc == verb->argc;
}

static const char *regime_name(const EscrowChecked *checked) {
  return escrow_regime(checked) == ESCROW_REGIME_DEBREU ? "debreu" : "impossibility";
}

static int verb_table(EscrowChecked *checked) {
  const unsigned char *codes = NULL;
  size_t count = 0;
  int status = escrow_table(checked, &codes, &count);
  if (status != ESCROW_EXIT_OK)
    return status;
  printf("%s %u", regime_name(checked), escrow_members(checked));
  for (size_t i = 0; i < count; i++)
    printf(" %u", (unsigned)codes[i]);
  putchar('\n');
  return ESCROW_EXIT_OK;
}

/* build PROG [--runtime] -o OUT: OUT is the last argument. */
static int verb_build(EscrowChecked *checked, Diag *diag, int argc, char **argv) {
  EscrowContract contract;
  int status = escrow_table(checked, &contract.codes, &contract.count);
  if (status != ESCROW_EXIT_OK)
    return status;
  status = escrow_addresses(checked, &contract.addresses);
  if (status != ESCROW_EXIT_OK)
    return status;
  contract.members = escrow_members(checked);
  contract.regime = escrow_regime(checked);
  const char *path = argv[argc - 1];
  FILE *out = fopen(path, "w");
  if (out == NULL) {
    diag_set(diag, "IO_WRITE", span_of("-"), "%s: %s", path, strerror(errno));
    return ESCROW_EXIT_USAGE;
  }
  EscrowPart part = argc == 6 ? ESCROW_PART_RUNTIME : ESCROW_PART_CREATION;
  int failed = escrow_evm_write(&contract, part, out, stderr);
  int closed = fclose(out);
  if (failed)
    return ESCROW_EXIT_REFUSED;
  if (closed != 0) {
    diag_set(diag, "IO_WRITE", span_of("-"), "%s: %s", path, strerror(errno));
    return ESCROW_EXIT_USAGE;
  }
  return ESCROW_EXIT_OK;
}

static int run_verb(EscrowChecked *checked, const Verb *verb, Diag *diag, int argc, char **argv) {
  switch (verb->kind) {
  case VERB_CHECK:
    printf("ok %s\n", regime_name(checked));
    return ESCROW_EXIT_OK;
  case VERB_TABLE: return verb_table(checked);
  case VERB_VERDICTS: return escrow_verdicts(checked, argv[3], stdout);
  case VERB_EVAL: return escrow_eval(checked, argv[3], stdout);
  case VERB_BUILD: return verb_build(checked, diag, argc, argv);
  }
  return ESCROW_EXIT_USAGE;
}

static int run(Arena *arena, const Verb *verb, Diag *diag, int argc, char **argv) {
  const char *path = argv[2];
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
  EscrowChecked *checked = NULL;
  status = escrow_check(arena, &prelude, &program, &checked, diag);
  if (status != ESCROW_EXIT_OK)
    return status;
  return run_verb(checked, verb, diag, argc, argv);
}

int main(int argc, char **argv) {
  const Verb *verb = argc < 3 ? NULL : find_verb(argv[1]);
  if (verb == NULL || !arguments_fit(verb, argc, argv))
    return usage();
  Arena arena;
  Diag diag;
  arena_init(&arena, ESCROW_ARENA_MAX);
  diag_init(&diag);
  int status = run(&arena, verb, &diag, argc, argv);
  fflush(stdout);
  diag_print(&diag, stderr);
  arena_free(&arena);
  return status;
}
