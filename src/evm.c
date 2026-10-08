/* The EVM back end of escrowc. It writes the creation or the runtime
 * bytecode of the contract EscrowDAO (SPEC section 7) directly.
 *
 * Storage: ledger (slot 0, address -> word), claimCount (slot 1), payer,
 * payee and amount (slots 2, 3 and 4, index -> word), and closed (slot 6,
 * index -> word, 1 = closed, SPEC O4). Slot 5 is kept for the credit of
 * SPEC O7. A mapping entry lives at keccak256(key . slot), as in Solidity.
 *
 * Arrow-Debreu: the orbit rule is a byte table at the end of the runtime
 * code, read with CODECOPY, so no entry can write it. Ballot codes 1, 2
 * and 3 weigh 1, members + 1 and 0, and the sum of the weights,
 * r + (members + 1) f, indexes the table of decision codes.
 *
 * Every failure is REVERT with empty output: a short calldata, an unknown
 * selector, a call value sent to an entry that is not payable, a failed
 * guard and an overflow of add. */
#include "evm.h"
#include "keccak.h"
#include <stdarg.h>
#include <string.h>

enum {
  EVM_CAPACITY = 8192,
  EVM_FIXUPS = 512,
  EVM_RUNTIME_MAX = 24576,  /* EIP-170 */
  EVM_DEBREU_MAX = 14,      /* amend packs 2 bits per tally into one word */
  EVM_TABLE_MAX = EVM_DEBREU_MAX * (EVM_DEBREU_MAX + 1) + 1,
  EVM_SIGNATURE = 256
};

enum {
  SLOT_LEDGER = 0, SLOT_COUNT = 1, SLOT_PAYER = 2, SLOT_PAYEE = 3, SLOT_AMOUNT = 4,
  SLOT_CLOSED = 6
};

/* Memory: 0x00 to 0x3f is scratch for keccak256 and the table read. */
enum { MEM_DECISION = 0x80, MEM_PAYER = 0xa0, MEM_AMOUNT = 0xc0, MEM_BALANCE = 0xe0 };

typedef enum {
  OP_ADD = 0x01, OP_MUL = 0x02, OP_SUB = 0x03, OP_LT = 0x10, OP_GT = 0x11,
  OP_EQ = 0x14, OP_ISZERO = 0x15, OP_SHR = 0x1c, OP_SHA3 = 0x20, OP_CALLVALUE = 0x34,
  OP_CALLDATALOAD = 0x35, OP_CALLDATASIZE = 0x36, OP_CODECOPY = 0x39,
  OP_POP = 0x50, OP_MLOAD = 0x51, OP_MSTORE = 0x52, OP_SLOAD = 0x54,
  OP_SSTORE = 0x55, OP_JUMP = 0x56, OP_JUMPI = 0x57, OP_JUMPDEST = 0x5b,
  OP_PUSH0 = 0x5f, OP_PUSH1 = 0x60, OP_PUSH2 = 0x61, OP_PUSH4 = 0x63,
  OP_DUP1 = 0x80, OP_DUP2 = 0x81, OP_SWAP1 = 0x90, OP_SWAP2 = 0x91,
  OP_RETURN = 0xf3, OP_REVERT = 0xfd
} Op;

typedef enum {
  LABEL_REVERT, LABEL_DEPOSIT, LABEL_CAST, LABEL_SETTLE, LABEL_AMEND,
  LABEL_RELEASE, LABEL_REFUND, LABEL_DONE, LABEL_TABLE, LABEL_RUNTIME,
  LABEL_COUNT
} Label;

typedef enum { ENTRY_PAYABLE, ENTRY_NONPAYABLE } Payment;

/* Pass 1 appends code and records each PUSH2 label site; pass 2 (resolve)
 * writes the label offsets into those sites. */
typedef struct {
  unsigned char code[EVM_CAPACITY];
  size_t size;
  size_t at[LABEL_COUNT];
  int bound[LABEL_COUNT];
  size_t site[EVM_FIXUPS];
  Label target[EVM_FIXUPS];
  size_t sites;
  int full;
} Asm;

static int fail(FILE *err, const char *code, const char *format, ...) {
  va_list args;
  va_start(args, format);
  fprintf(err, "escrowc: %s: ", code);
  vfprintf(err, format, args);
  fputc('\n', err);
  va_end(args);
  return 1;
}

static void put(Asm *a, unsigned value) {
  a->full = a->full || a->size >= EVM_CAPACITY;
  if (a->full)
    return;
  a->code[a->size] = (unsigned char)value;
  a->size++;
}

static void op(Asm *a, Op code) { put(a, (unsigned)code); }

/* The shortest PUSH of a big-endian word: PUSH0 for zero. */
static void push_word(Asm *a, const unsigned char word[32]) {
  size_t lead = 0;
  while (lead < 32 && word[lead] == 0)
    lead++;
  put(a, (unsigned)OP_PUSH0 + (unsigned)(32 - lead));
  for (size_t i = lead; i < 32; i++)
    put(a, word[i]);
}

static void push(Asm *a, unsigned long value) {
  unsigned char word[32] = {0};
  for (size_t i = 0; i < sizeof value && i < 32; i++)
    word[31 - i] = (unsigned char)(value >> (8 * i));
  push_word(a, word);
}

static void push_label(Asm *a, Label label) {
  a->full = a->full || a->sites >= EVM_FIXUPS;
  if (a->full)
    return;
  op(a, OP_PUSH2);
  a->site[a->sites] = a->size;
  a->target[a->sites] = label;
  a->sites++;
  put(a, 0);
  put(a, 0);
}

static void bind(Asm *a, Label label) {
  a->at[label] = a->size;
  a->bound[label] = 1;
}

static void jumpdest(Asm *a, Label label) {
  bind(a, label);
  op(a, OP_JUMPDEST);
}

static void jump(Asm *a, Label label) {
  push_label(a, label);
  op(a, OP_JUMP);
}

static void jump_if(Asm *a, Label label) {
  push_label(a, label);
  op(a, OP_JUMPI);
}

static void revert_if(Asm *a) { jump_if(a, LABEL_REVERT); }

static int resolve(Asm *a) {
  int ok = !a->full;
  for (size_t i = 0; ok && i < a->sites; i++) {
    Label label = a->target[i];
    ok = a->bound[label] && a->at[label] <= 0xffff;
    a->code[a->site[i]] = (unsigned char)(a->at[label] >> 8);
    a->code[a->site[i] + 1] = (unsigned char)a->at[label];
  }
  return ok;
}

/* Calldata word j of the arguments, at byte 4 + 32 j. */
static void argument(Asm *a, unsigned j) {
  push(a, 4ul + 32ul * j);
  op(a, OP_CALLDATALOAD);
}

/* key -> keccak256(key . base), the slot of a mapping entry. */
static void slot(Asm *a, unsigned base) {
  op(a, OP_PUSH0);
  op(a, OP_MSTORE);
  push(a, base);
  push(a, 0x20);
  op(a, OP_MSTORE);
  push(a, 0x40);
  op(a, OP_PUSH0);
  op(a, OP_SHA3);
}

/* x y -> x + y; reverts when the sum wraps (then it is below y). */
static void checked_add(Asm *a) {
  op(a, OP_DUP2);
  op(a, OP_ADD);
  op(a, OP_DUP1);
  op(a, OP_SWAP2);
  op(a, OP_GT);
  revert_if(a);
}

static void return_top(Asm *a) {
  op(a, OP_PUSH0);
  op(a, OP_MSTORE);
  push(a, 0x20);
  op(a, OP_PUSH0);
  op(a, OP_RETURN);
}

static void load(Asm *a, unsigned address) {
  push(a, address);
  op(a, OP_MLOAD);
}

static void store(Asm *a, unsigned address) {
  push(a, address);
  op(a, OP_MSTORE);
}

static int signature(char *text, const char *name, unsigned words) {
  size_t size = strlen(name);
  int ok = size + 2 + 8ul * words < EVM_SIGNATURE;
  if (!ok)
    return 0;
  memcpy(text, name, size);
  text[size] = '(';
  size++;
  for (unsigned i = 0; i < words; i++) {
    memcpy(text + size, i == 0 ? "uint256" : ",uint256", i == 0 ? 7 : 8);
    size += i == 0 ? 7 : 8;
  }
  text[size] = ')';
  text[size + 1] = '\0';
  return 1;
}

/* With the selector on the stack: jump to label on name(uint256 x words). */
static void dispatch(Asm *a, const char *name, unsigned words, Label label) {
  char text[EVM_SIGNATURE];
  unsigned char digest[32] = {0};
  a->full = a->full || !signature(text, name, words);
  if (a->full)
    return;
  escrow_keccak256((const unsigned char *)text, strlen(text), digest);
  op(a, OP_DUP1);
  op(a, OP_PUSH4);
  for (size_t i = 0; i < 4; i++)
    put(a, digest[i]);
  op(a, OP_EQ);
  jump_if(a, label);
}

static void dispatch_head(Asm *a) {
  push(a, 4);
  op(a, OP_CALLDATASIZE);
  op(a, OP_LT);
  revert_if(a);
  op(a, OP_PUSH0);
  op(a, OP_CALLDATALOAD);
  push(a, 0xe0);
  op(a, OP_SHR);
}

static void revert_block(Asm *a) {
  jumpdest(a, LABEL_REVERT);
  op(a, OP_PUSH0);
  op(a, OP_PUSH0);
  op(a, OP_REVERT);
}

static void entry(Asm *a, Label label, unsigned words, Payment payment) {
  jumpdest(a, label);
  op(a, OP_POP);
  switch (payment) {
    case ENTRY_PAYABLE:
      break;
    case ENTRY_NONPAYABLE:
      op(a, OP_CALLVALUE);
      revert_if(a);
      break;
  }
  push(a, 4ul + 32ul * words);
  op(a, OP_CALLDATASIZE);
  op(a, OP_LT);
  revert_if(a);
}

/* Reverts unless calldata word j is below 2^160. */
static void address_guard(Asm *a, unsigned j) {
  argument(a, j);
  push(a, 0xa0);
  op(a, OP_SHR);
  revert_if(a);
}

/* deposit p q n: guard n <= callvalue, credit p, append the claim
 * (p, q, n) and return its index. */
static void deposit(Asm *a) {
  entry(a, LABEL_DEPOSIT, 3, ENTRY_PAYABLE);
  address_guard(a, 0);
  address_guard(a, 1);
  op(a, OP_CALLVALUE);
  argument(a, 2);
  op(a, OP_GT);
  revert_if(a);
  argument(a, 0);
  slot(a, SLOT_LEDGER);
  op(a, OP_DUP1);
  op(a, OP_SLOAD);
  argument(a, 2);
  checked_add(a);
  op(a, OP_SWAP1);
  op(a, OP_SSTORE);
  push(a, SLOT_COUNT);
  op(a, OP_SLOAD);
  for (unsigned j = 0; j < 3; j++) {
    argument(a, j);
    op(a, OP_DUP2);
    slot(a, SLOT_PAYER + j);
    op(a, OP_SSTORE);
  }
  op(a, OP_DUP1);
  push(a, 1);
  checked_add(a);
  push(a, SLOT_COUNT);
  op(a, OP_SSTORE);
  return_top(a);
}

/* The decision code of the ballots in calldata words first .. first + n - 1.
 * Each ballot must be 1, 2 or 3. */
static void tally(Asm *a, unsigned first, unsigned members) {
  op(a, OP_PUSH0);
  for (unsigned m = 0; m < members; m++) {
    argument(a, first + m);
    op(a, OP_DUP1);
    push(a, 1);
    op(a, OP_SWAP1);
    op(a, OP_SUB);
    push(a, 2);
    op(a, OP_LT);
    revert_if(a);
    op(a, OP_DUP1);
    push(a, 1);
    op(a, OP_EQ);
    op(a, OP_SWAP1);
    push(a, 2);
    op(a, OP_EQ);
    push(a, members + 1ul);
    op(a, OP_MUL);
    op(a, OP_ADD);
    op(a, OP_ADD);
  }
  push_label(a, LABEL_TABLE);
  op(a, OP_ADD);
  push(a, 0x20);
  op(a, OP_SWAP1);
  op(a, OP_PUSH0);
  op(a, OP_CODECOPY);
  op(a, OP_PUSH0);
  op(a, OP_MLOAD);
  push(a, 0xf8);
  op(a, OP_SHR);
}

/* cast x: the decision of the ballots. It writes nothing. */
static void cast(Asm *a, unsigned members) {
  entry(a, LABEL_CAST, members, ENTRY_NONPAYABLE);
  tally(a, 0, members);
  return_top(a);
}

static void debit_payer(Asm *a) {
  load(a, MEM_AMOUNT);
  load(a, MEM_BALANCE);
  op(a, OP_SUB);
  load(a, MEM_PAYER);
  slot(a, SLOT_LEDGER);
  op(a, OP_SSTORE);
}

/* The payee balance is read after the debit, so a claim with payer =
 * payee leaves the balance unchanged. */
static void credit_payee(Asm *a) {
  argument(a, 0);
  slot(a, SLOT_PAYEE);
  op(a, OP_SLOAD);
  slot(a, SLOT_LEDGER);
  op(a, OP_DUP1);
  op(a, OP_SLOAD);
  load(a, MEM_AMOUNT);
  checked_add(a);
  op(a, OP_SWAP1);
  op(a, OP_SSTORE);
}

/* Reverts unless c < claimCount and claim c is open (SPEC O4). */
static void open_guard(Asm *a) {
  push(a, SLOT_COUNT);
  op(a, OP_SLOAD);
  argument(a, 0);
  op(a, OP_LT);
  op(a, OP_ISZERO);
  revert_if(a);
  argument(a, 0);
  slot(a, SLOT_CLOSED);
  op(a, OP_SLOAD);
  revert_if(a);
}

/* closed c := 1 (SPEC O4). */
static void close_claim(Asm *a) {
  push(a, 1);
  argument(a, 0);
  slot(a, SLOT_CLOSED);
  op(a, OP_SSTORE);
}

/* settle c x: guard c < claimCount and claim c open, guard amount c <=
 * balance (payer c) (the proof h), then the release, refund or hold leg
 * of design section 3 by the decision. Release and refund close claim c,
 * hold leaves it open. */
static void settle(Asm *a, unsigned members) {
  entry(a, LABEL_SETTLE, members + 1, ENTRY_NONPAYABLE);
  tally(a, 1, members);
  store(a, MEM_DECISION);
  open_guard(a);
  argument(a, 0);
  slot(a, SLOT_PAYER);
  op(a, OP_SLOAD);
  store(a, MEM_PAYER);
  argument(a, 0);
  slot(a, SLOT_AMOUNT);
  op(a, OP_SLOAD);
  store(a, MEM_AMOUNT);
  load(a, MEM_PAYER);
  slot(a, SLOT_LEDGER);
  op(a, OP_SLOAD);
  store(a, MEM_BALANCE);
  load(a, MEM_BALANCE);
  load(a, MEM_AMOUNT);
  op(a, OP_GT);
  revert_if(a);
  load(a, MEM_DECISION);
  push(a, 2);
  op(a, OP_GT);
  jump_if(a, LABEL_RELEASE);
  load(a, MEM_DECISION);
  push(a, 3);
  op(a, OP_GT);
  jump_if(a, LABEL_REFUND);
  jump(a, LABEL_DONE);
  jumpdest(a, LABEL_RELEASE);
  debit_payer(a);
  credit_payee(a);
  close_claim(a);
  jump(a, LABEL_DONE);
  jumpdest(a, LABEL_REFUND);
  debit_payer(a);
  close_claim(a);
  jumpdest(a, LABEL_DONE);
  load(a, MEM_DECISION);
  return_top(a);
}

/* amend at the canonical Phi: the packed table sum C_i * 4^i (SPEC O5). */
static void amend(Asm *a, const unsigned char packed[32]) {
  entry(a, LABEL_AMEND, 0, ENTRY_NONPAYABLE);
  push_word(a, packed);
  return_top(a);
}

static void runtime_impossibility(Asm *a) {
  dispatch_head(a);
  dispatch(a, "deposit", 3, LABEL_DEPOSIT);
  revert_block(a);
  deposit(a);
}

static void runtime_debreu(Asm *a, const EscrowContract *contract) {
  unsigned n = contract->members;
  unsigned char table[EVM_TABLE_MAX] = {0};
  unsigned char packed[32] = {0};
  size_t i = 0;
  for (unsigned r = 0; r <= n; r++) {
    for (unsigned f = 0; r + f <= n; f++) {
      unsigned code = contract->codes[i];
      table[r + (n + 1) * f] = (unsigned char)code;
      packed[31 - (2 * i) / 8] |= (unsigned char)(code << ((2 * i) % 8));
      i++;
    }
  }
  dispatch_head(a);
  dispatch(a, "deposit", 3, LABEL_DEPOSIT);
  dispatch(a, "cast", n, LABEL_CAST);
  dispatch(a, "settle", n + 1, LABEL_SETTLE);
  dispatch(a, "amend", 0, LABEL_AMEND);
  revert_block(a);
  deposit(a);
  cast(a, n);
  settle(a, n);
  amend(a, packed);
  bind(a, LABEL_TABLE);
  for (size_t k = 0; k < (size_t)n * (n + 1) + 1; k++)
    put(a, table[k]);
}

static int check_impossibility(const EscrowContract *contract, FILE *err) {
  if (contract->members < 1)
    return fail(err, "EVM_LIMIT", "a contract needs at least 1 member, got 0");
  if (contract->codes != NULL || contract->count != 0)
    return fail(err, "EVM_TABLE", "the impossibility regime takes no decision codes, got %zu",
                contract->count);
  return 0;
}

static int check_debreu(const EscrowContract *contract, FILE *err) {
  unsigned n = contract->members;
  if (n < 1 || n > EVM_DEBREU_MAX)
    return fail(err, "EVM_LIMIT", "the Debreu regime needs 1 to %d members, got %u",
                EVM_DEBREU_MAX, n);
  size_t wanted = ((size_t)n + 1) * ((size_t)n + 2) / 2;
  if (contract->codes == NULL || contract->count != wanted)
    return fail(err, "EVM_TABLE", "%zu decision codes needed for %u members, got %zu",
                wanted, n, contract->codes == NULL ? (size_t)0 : contract->count);
  for (size_t i = 0; i < wanted; i++) {
    unsigned code = contract->codes[i];
    if (code < 1 || code > 3)
      return fail(err, "EVM_TABLE", "decision code %zu is %u, need 1, 2 or 3", i, code);
  }
  return 0;
}

static int build_runtime(Asm *a, const EscrowContract *contract, FILE *err) {
  switch (contract->regime) {
    case ESCROW_REGIME_IMPOSSIBILITY: {
      int bad = check_impossibility(contract, err);
      if (bad)
        return bad;
      runtime_impossibility(a);
      return 0;
    }
    case ESCROW_REGIME_DEBREU: {
      int bad = check_debreu(contract, err);
      if (bad)
        return bad;
      runtime_debreu(a, contract);
      return 0;
    }
  }
  return fail(err, "EVM_USAGE", "unknown regime %d", (int)contract->regime);
}

/* Reverts on a call value, copies the runtime to memory and returns it. */
static void creation(Asm *a, const Asm *body) {
  op(a, OP_CALLVALUE);
  jump_if(a, LABEL_REVERT);
  push(a, body->size);
  op(a, OP_DUP1);
  push_label(a, LABEL_RUNTIME);
  op(a, OP_PUSH0);
  op(a, OP_CODECOPY);
  op(a, OP_PUSH0);
  op(a, OP_RETURN);
  revert_block(a);
  bind(a, LABEL_RUNTIME);
  for (size_t i = 0; i < body->size; i++)
    put(a, body->code[i]);
}

static int finish(Asm *a, FILE *err) {
  if (a->full)
    return fail(err, "EVM_SIZE", "the bytecode exceeds %d bytes", EVM_CAPACITY);
  if (!resolve(a))
    return fail(err, "EVM_INTERNAL", "unresolved jump label");
  return 0;
}

static int write_hex(const Asm *a, FILE *out, FILE *err) {
  for (size_t i = 0; i < a->size; i++)
    fprintf(out, "%02x", a->code[i]);
  fputc('\n', out);
  if (fflush(out) != 0 || ferror(out))
    return fail(err, "EVM_IO", "cannot write the bytecode");
  return 0;
}

int escrow_evm_write(const EscrowContract *contract, EscrowPart part, FILE *out, FILE *err) {
  if (contract == NULL)
    return fail(err, "EVM_USAGE", "no contract");
  Asm body_asm;
  Asm creation_asm;
  memset(&body_asm, 0, sizeof body_asm);
  memset(&creation_asm, 0, sizeof creation_asm);
  int bad = build_runtime(&body_asm, contract, err);
  if (bad)
    return bad;
  bad = finish(&body_asm, err);
  if (bad)
    return bad;
  if (body_asm.size > EVM_RUNTIME_MAX)
    return fail(err, "EVM_SIZE", "the runtime has %zu bytes, the limit is %d",
                body_asm.size, EVM_RUNTIME_MAX);
  switch (part) {
    case ESCROW_PART_RUNTIME:
      return write_hex(&body_asm, out, err);
    case ESCROW_PART_CREATION:
      creation(&creation_asm, &body_asm);
      bad = finish(&creation_asm, err);
      return bad ? bad : write_hex(&creation_asm, out, err);
  }
  return fail(err, "EVM_USAGE", "unknown part %d", (int)part);
}
