# Escrow-local Assay dependency

`../PIN` identifies the Assay base. `assay-surface-branch.patch` adds the
tail statement `if le a b then BODY else BODY`, lowering to core `le`.
Both legs retain the incoming bindings and proof state. Its parser,
lowering, tests, mutation definitions and upstream documentation are
preserved together in the patch.

The patch uses zero context lines so Git's whitespace checks also apply
to the patch artifact. Its exact base is pinned, and setup applies it
with `--unidiff-zero --whitespace=error-all`.

The patch was captured from the 11 staged files in the separate
`escrow-lang-branch-kit/assay` checkout at base
`30feb7b02baa1964e0743aedfb0d4b477c9b870a`. That checkout and the sibling
Assay repository are not build destinations. Future dependency fixes
belong in this patch and the ignored local checkout under `.tools/assay`.
The upstream notes in the patch describe the state at import, including
pending mutation and full-battery validation.
Current review results and the local mutation-witness correction are in
[REVIEW.md](REVIEW.md).

`assay.py setup` creates a private clone, applies the patch, verifies its
exact diff, and builds the CLI. It checks the checkout against `PIN` and
the patch again before running a command. No compiler binary or copied
Git history is staged in escrow-lang.

The generated contract exposes one `settle` entry. It computes the tally,
checks the payer's balance, then chooses release, refund or hold. This
changes the interim ABI: callers must use `settle`, not `settleRelease`,
`settleRefund` or `settleHold`.

Run `zsh test/generator.sh`, `zsh probe/regression.sh`, and
`python3 test/settlement.py` after setup. The last command compares Assay's
execution model and emitted EVM behavior with independent expected
storage for all three decisions, balance failures, overflow and equal
payer/payee addresses. Its logs stay in `.gatework/settlement/`.
