# Escrow-local integration review, 2026-10-07

## CI and scope

The imported patch adds the branch test and a separate upstream gate.
It removes no tests. It preserves the previously recorded emitter limit
change from 1800 to 1815 and total from 3550 to 3565. The measured emitter
is 1812 lines, and the trusted-line audit passes. Git whitespace checks
remain enabled; zero-context patch storage avoids exemptions.

The review covers the compiler patch, local setup and launcher, single
settlement entry, regenerated fixture, documentation, and regression
test. The original branch-kit index remains byte-identical to the
captured input. No changes were made in that checkout or the sibling
Assay checkout.

## Integration corrections

- The probe launcher previously used an absolute sibling compiler path
  without checking `PIN`. It now runs a private local checkout and checks
  the base, exact patch and build stamp before dispatch.
- The external branch work now lives in a tracked patch with its parser,
  lowering, tests and mutation definitions. A temporary index confirmed
  that the saved patch applies to `PIN` with strict whitespace checking.
- The generator and fixture now expose `settle`, with release, refund and
  hold selected inside the contract. The ABI change is documented.
- The imported SCAN mutation removed the caller effect declaration and
  produced `unbound: caller`, but the test rejected that failure because
  it lacked `SURFACE-BRANCH-SCAN`. The witness now labels the emission
  assertion consistently. The mutant fails, and its restored control
  passes. This correction is included in the tracked dependency patch.
- The patch changed `Makefile`, `dev/stage-a-gates.py` and
  `src/emitter.bend` but not their `dev/DENOMINATORS.sha256` lines, so
  `shasum -a 256 -c dev/DENOMINATORS.sha256` failed on those three files
  in the patched tree (the base passes). The patch now updates the three
  lines and names them in `dev/STAGE-SURFACE-BRANCH-COMMIT.txt`.

## Validation

| Check | Result |
| --- | --- |
| Local pinned compiler setup | Built successfully; subsequent build reused cache |
| `zsh test/generator.sh` | All cases passed, including zero and eight members |
| `zsh probe/regression.sh` | Passed |
| `python3 -P test/settlement.py` | 18 cases, constructor tables and ABI passed; model and geth matched independent expectations |
| Local `dev/surface-branch-test.py` | 30 cases, 2 pairs, 4 scan cases, 8 refusals, 4 mutants with passing restored controls |
| Local `dev/trusted-lines.py .tools/assay` | Passed, emitter 1812/1815, total 3204/3565 |
| Three-member tally certification | `3 3 2 2 3 3 2 1 1 1`; generated fixture matches |
| Both contract regimes | Check, emit and axiom audit passed; only `EvmOpcodes` |
| Stored patch | Applies to pinned base; resulting tree `cc81e87dfdb77dad597dfd6c552038ca951bd200` |
| `shasum -a 256 -c dev/DENOMINATORS.sha256` on the patched tree | Passed (fresh apply and `.tools/assay`); setup reused the cached build; `zsh probe/regression.sh` passed |

Full command captures are retained locally under `.kanon-exec/`:
`run-llJFAI` (build), `run-WIY2V4` (generator), `run-IzwvpP`
(settlement), `run-DMdMnL` (branch suite), and `run-Ub1PX4` (fixtures).
The probe pass is in `run-KOUnQJ`; that combined command then failed
because the trusted-line script was invoked without its root argument.
The corrected trusted-line invocation subsequently passed.

The upstream 111-leg battery was not run. Kernel-to-contract differential
testing, the Bend generator and the dialect refusal test remain separate
M1 work. The settlement regression compares the Assay execution model
and emitted EVM code with independent expectations, not kernel evaluation.

## Blockers and verdict

No unresolved findings in this integration. Ready to merge within the
validation scope above. Callers must adopt the single `settle` ABI.
