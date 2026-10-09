/* Test driver of the EVM back end, run with:
 *   tcc src/evm.c src/keccak.c -run test/evmtool.c creation|runtime N|K1,K2,... debreu CODE... [ADDRESS...]
 *   tcc src/evm.c src/keccak.c -run test/evmtool.c creation|runtime N impossibility [CODE...]
 *   tcc src/evm.c src/keccak.c -run test/evmtool.c keccak TEXT
 * Codes go to escrow_evm_write unchecked (0 to 255), so the tests reach its
 * EVM_TABLE refusals. An ADDRESS is 0x and 1 to 64 hex digits, unchecked
 * so the tests reach EVM_ADDRESSES refusals. The
 * addresses come after the codes, none or N of them (M4). Exit 0 ok, 1
 * refused by the back end, 2 usage. */
#include "../src/evm.h"
#include "../src/keccak.h"
#include <stdlib.h>
#include <string.h>

enum { TOOL_CODES = 512, TOOL_DIGITS = 9, TOOL_MEMBERS = 64 };

static int usage(void) {
  fputs("usage: evmtool creation|runtime N|K1,K2,... debreu CODE... [ADDRESS...] | evmtool creation|runtime N impossibility"
        " [CODE...] | evmtool keccak TEXT\n", stderr);
  return 2;
}

/* 0x and 1 to 64 hex digits into a word of 32 bytes, big-endian. */
static int address(const char *text, unsigned char word[32]) {
  size_t size = strlen(text);
  int ok = size >= 3 && size <= 66 && strncmp(text, "0x", 2) == 0 &&
           strspn(text + 2, "0123456789abcdefABCDEF") == size - 2;
  memset(word, 0, 32);
  for (size_t i = 0; ok && i < size - 2; i++) {
    char digit[2] = {text[size - 1 - i], '\0'};
    word[31 - i / 2] |= (unsigned char)(strtoul(digit, NULL, 16) << (4 * (i % 2)));
  }
  return ok;
}

/* A decimal number of at most TOOL_DIGITS digits, or -1. */
static long number(const char *text) {
  size_t size = strlen(text);
  int ok = size >= 1 && size <= TOOL_DIGITS && strspn(text, "0123456789") == size;
  return ok ? strtol(text, NULL, 10) : -1;
}

static int keccak(const char *text) {
  unsigned char digest[32];
  escrow_keccak256((const unsigned char *)text, strlen(text), digest);
  for (size_t i = 0; i < 32; i++)
    printf("%02x", digest[i]);
  putchar('\n');
  return 0;
}

static int part_of(const char *text, EscrowPart *part) {
  *part = strcmp(text, "creation") == 0 ? ESCROW_PART_CREATION : ESCROW_PART_RUNTIME;
  return strcmp(text, "creation") == 0 || strcmp(text, "runtime") == 0;
}

static int regime_of(const char *text, EscrowRegime *regime) {
  *regime = strcmp(text, "debreu") == 0 ? ESCROW_REGIME_DEBREU : ESCROW_REGIME_IMPOSSIBILITY;
  return strcmp(text, "debreu") == 0 || strcmp(text, "impossibility") == 0;
}

int main(int argc, char **argv) {
  if (argc == 3 && strcmp(argv[1], "keccak") == 0)
    return keccak(argv[2]);
  EscrowPart part;
  EscrowRegime regime;
  if (argc < 4 || argc - 4 > TOOL_CODES || !part_of(argv[1], &part) || !regime_of(argv[3], &regime))
    return usage();
  long members = number(argv[2]);
  /* K1,K2,...: the member class sizes of K1 + K2 + ... members (M6). */
  static unsigned sizes[TOOL_MEMBERS];
  size_t nclasses = 0;
  if (strchr(argv[2], ',') != NULL) {
    members = 0;
    for (char *part = strtok(argv[2], ","); part != NULL; part = strtok(NULL, ",")) {
      long k = number(part);
      if (k < 0 || nclasses == TOOL_MEMBERS || members > TOOL_MEMBERS)
        return usage();
      sizes[nclasses++] = (unsigned)k;
      members += k;
    }
  }
  if (members < 0)
    return usage();
  unsigned char codes[TOOL_CODES];
  size_t count = 0;
  while (count < (size_t)(argc - 4) && strncmp(argv[4 + count], "0x", 2) != 0) {
    long code = number(argv[4 + count]);
    if (code < 0 || code > 255)
      return usage();
    codes[count] = (unsigned char)code;
    count++;
  }
  static unsigned char words[TOOL_MEMBERS * 32];
  size_t given = (size_t)(argc - 4) - count;
  if (given != 0 && (given != (size_t)members || given > TOOL_MEMBERS))
    return usage();
  for (size_t i = 0; i < given; i++)
    if (!address(argv[4 + count + i], words + 32 * i))
      return usage();
  int listed = regime == ESCROW_REGIME_DEBREU || count > 0;
  EscrowContract contract = { (unsigned)members, regime, listed ? codes : NULL, count, given > 0 ? words : NULL,
                              nclasses > 0 ? sizes : NULL, nclasses };
  return escrow_evm_write(&contract, part, stdout, stderr) == 0 ? 0 : 1;
}
