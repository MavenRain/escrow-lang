#!/bin/zsh
# usage: zsh probe/regression.sh
# Requires the Assay launcher used by probe/run.sh. Keeps logs in a fresh
# temporary directory for inspection after a failure.
set -eu
root=${0:A:h:h}
out=$(mktemp -d "${TMPDIR:-/tmp}/escrow-tooling.XXXXXX")
repo=$root

if env TMPDIR="$out" zsh "$root/probe/run.sh" bad check "$repo/probe/p5-sigma-eta.asy" >"$out/bad.log" 2>&1; then
  print -u2 -r -- 'runner accepted an Assay rejection'
  exit 1
fi
rg -q '\[bad\] shell_exit=1' "$out/bad.log"
env TMPDIR="$out" zsh "$root/probe/run.sh" good check "$repo/probe/p3-refl.asy" >"$out/good.log" 2>&1

zsh "$root/probe/p4-gen.sh" 0 >"$out/p4-0.asy"
env TMPDIR="$out" zsh "$root/probe/run.sh" zero check "$out/p4-0.asy" >"$out/zero.log" 2>&1
zsh "$root/probe/p4-gen.sh" 100 >"$out/p4-100.asy"
cmp "$out/p4-100.asy" "$repo/probe/p4-fold-100.asy"

if zsh "$root/prelude/assemble.sh" --members $'3\naxiom forged : Prop' >"$out/injected.asy" 2>"$out/injected.err"; then
  print -u2 -r -- 'assembler accepted a multiline member count'
  exit 1
fi
[[ ! -s "$out/injected.asy" ]]
zsh "$root/prelude/assemble.sh" --members 3 >"$out/prelude.asy"
rg -q '^def members : Nat := 3$' "$out/prelude.asy"

print -r -- "tooling regressions passed (logs: $out)"
