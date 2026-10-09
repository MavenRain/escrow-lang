# escrow-lang host capability: TinyCC (M2, 2026-10-07)

USER rulings 2026-10-07: the host is TinyCC, the surface is the current
subset of assay syntax, and `escrowc` writes EVM bytecode directly (SPEC
section 8). This file records the host facts that `escrowc` depends on.
The assay probe results P1 to P8 (2026-10-06) are in the git history:
`git show 8351635:probe/CAPABILITY.md`.

## Compiler

- `tcc` on `PATH`: tcc version 0.9.28rc 2026-09-04 mob@0fb54300 (AArch64
  Darwin). The Makefile builds with `tcc -std=c99 -Wall -Werror`.
- `tcc -run` works. `make` runs `tools/embed.c` with `tcc -run` to write
  `build/prelude.c` from `prelude/Prelude.esc`. `test/settlement.py` runs
  `test/evmtool.c` with `tcc src/evm.c src/keccak.c -run`.
- tcc has no `-Wswitch-enum`. `make check-clang` checks every C file with
  `cc -std=c99 -Wall -Wextra -Wswitch-enum -Werror -fsyntax-only`, so a
  switch that does not list each enumerator fails the gate.
- `escrowc` uses only the C standard library.

## Limits

- Stack depth (MEASURED 2026-10-07): the checker evaluates by C recursion.
  On an 8 MB main-thread stack, the tcc build crashed between depth 12288
  and 16384 (a test that doubles the depth with `appendBallots`). Thus
  `CHECK_DEPTH = 4096` in `src/check.c` bounds the nested eval, apply,
  conversion, quote, check and infer calls.
- Fuel: `CHECK_FUEL = 1 << 24` evaluation steps for each declaration, each
  tally and each ballot vector. Past `CHECK_DEPTH` or `CHECK_FUEL` the
  checker refuses the program (exit 1). It does not crash.
- Memory: one arena per run, capped at `ESCROW_ARENA_MAX` (256 MiB). A
  source file is at most `ESCROW_SOURCE_MAX` (1 MiB). The parser depth
  guard is 512.
- `Nat` is a 64-bit word: `natAdd 18446744073709551615 1` is refused with
  `TYPE_NAT` (test/refusal.sh).
- Time: at members 3, `escrowc verdicts examples/programs/arrow-debreu.esc
  F` (27 ballot vectors) and `escrowc table` each finish in less than
  0.01 s.
- Members: the first declaration must use a positive integer literal no
  larger than C's `UINT_MAX` (`REFUSE_MEMBERS`). `table` limits Arrow-Debreu
  programs to 1000 members (`TABLE_LIMIT`); `verdicts` limits either
  regime to 10 members (`VERDICT_LIMIT`). The memory and fuel limits
  still apply within these bounds.
- EVM writer (`src/evm.c`), Arrow-Debreu: members 1 to 14 (`EVM_LIMIT`),
  and one code in 1 to 3 per class tally (`EVM_TABLE`). At one class there
  are exactly `(n+1)(n+2)/2` codes. For class sizes `k_i`, the count is the
  product of `(k_i+1)(k_i+2)/2`, with at most 128 rows. For example,
  `council` has classes `(2, 2)` and 36 codes, rather than the 15 codes of
  one class of 4. Before the writer, `escrowc table` and `build` refuse
  more than 128 rows at two or more classes (`REFUSE_TABLE_SIZE`), after
  the 1000-member check (`TABLE_LIMIT`). The bound 14 keeps the one-class
  packed `amend` table in one word: 120 codes of 2 bits are 240 bits, and
  15 members give 136 codes (272 bits).
- Runtime size (MEASURED 2026-10-08 at a00089c, M3): the Arrow-Debreu
  runtime at 14 members is 1693 bytes. The limit `EVM_RUNTIME_MAX` is
  24576 bytes (EIP-170). The runtime has the 120-code verdict table and
  the `deposit`, `cast`, `settle`, `amend` and `withdraw` entries. The
  program is `examples/programs/arrow-debreu.esc` with 14 members and
  14-ballot configurations. `escrowc build --runtime` used about 6 MiB of
  memory (6.0 and 6.3 MiB in two runs).
- Arrow-impossibility has no verdict table, so its writer accepts the
  full member range of program checking without a 14-member cap. The
  writer requires no decision codes (`EVM_TABLE`).

## Carried from the assay host

- P2 (2026-10-06): in the assay kernel, a constructor of a `mu` family with
  a parameter cannot appear in a term, and a family with a type index lives
  in `Type 1`. The prelude was written to this limit (SPEC O8): one
  equality family per index type and one list family per element type.
  Ruling 2 keeps the prelude and both example programs unchanged, so
  `escrowc` checks these forms as they are.

## Gates (M4, 2026-10-08; M6 counts, 2026-10-09)

- `make`, `make check-clang`, `make test` (parse.sh, check.sh, refusal.sh,
  normal-forms.py): GREEN, 131 ok at M6.
- `python3 test/settlement.py`: `cases=148 deploy=2 geth=expected OK`
  (M6, 2026-10-09; M4 had `cases=131`, M2 had `cases=60`).
- `python3 test/differential.py`: `vectors=27
  codes=111123133123222323133323333`. For each vector, each member sends
  one `vote` on claim 0, then the script calls `settle(0)` (M4). `amend`,
  `cast` and `settle` in geth agree with `escrowc table` and `escrowc
  verdicts`, and the geth storage after `settle`, apart from the ballots
  word, agrees with `escrowc eval` of source `settle`. M6 adds two
  programs: `test/fixtures/two-classes.esc` (27 vectors, the same codes)
  and `examples/programs/council.esc` (81 vectors).
- Differential mutation check: changing the EVM writer's decision code for
  three release ballots from 1 to 2 fails first at `differential-amend`,
  because geth returns the altered packed table. The later cast check would
  return refund while the checker expects release.
