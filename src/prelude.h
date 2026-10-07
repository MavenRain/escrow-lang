/* The prelude, embedded in escrowc by tools/embed.c (build/prelude.c), so
 * escrowc reads no prelude file at run time. */
#ifndef ESCROW_PRELUDE_H
#define ESCROW_PRELUDE_H
#include <stddef.h>

extern const char escrow_prelude_name[];        /* prelude/Prelude.esc */
extern const unsigned char escrow_prelude_text[]; /* the bytes, then one NUL */
extern const size_t escrow_prelude_size;        /* the bytes without the NUL */
#endif
