#!/bin/zsh
# usage: zsh probe/run.sh LABEL ARGS..
# Runs the pinned assay launcher with ARGS.  NODE_COMPILE_CACHE goes to a
# scratch directory, not the assay tree.  The V8 heap cap is 3 GB.
# probe/rss.cjs kills the process above 4 GB RSS and prints the wall time
# and the peak RSS, measured inside node.
set -u
S=${TMPDIR:-/tmp}/escrow-probe
P=${0:A:h}
label=$1; shift
mkdir -p $S/logs $S/node-cache
/usr/bin/env NODE_COMPILE_CACHE=$S/node-cache \
  NODE_OPTIONS="--max-old-space-size=3072 --require $P/rss.cjs" \
  python3 -P "$P/../toolchain/assay.py" "$@" >$S/logs/$label.out 2>$S/logs/$label.err
code=$?
print -r -- "[$label] shell_exit=$code $(rg -o '\[probe\].*' $S/logs/$label.err | tail -1)"
print -r -- "--- stdout ($(wc -l <$S/logs/$label.out | tr -d ' ') lines, first ${LINES_OUT:-30})"
head -${LINES_OUT:-30} $S/logs/$label.out | cut -c1-300
print -r -- "--- stderr"
rg -v '^\[probe\]' $S/logs/$label.err | head -15 | cut -c1-400
exit $code
