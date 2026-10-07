#ifndef ESCROW_KECCAK_H
#define ESCROW_KECCAK_H
#include <stddef.h>
/* Keccak-256 as the EVM uses it (pad 0x01, not the SHA3-256 pad 0x06). */
void escrow_keccak256(const unsigned char *data, size_t size, unsigned char digest[32]);
#endif
