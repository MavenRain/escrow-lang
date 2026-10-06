#!/bin/zsh
# usage: zsh probe/p4-gen.sh N > FILE
# P4: writes a file that folds a tally over a list of N ballots and checks
# the result with a refl candidate.  Thus `assay check` must evaluate the
# fold.  Ballot i (from 1) is release, refund or hold for (i - 1) mod 3 =
# 0, 1, 2.  The list is a chain of N definitions, one constructor each.
set -u
n=$1
r=$(( (n + 2) / 3 )); f=$(( (n + 1) / 3 )); h=$(( n / 3 ))
cat <<'HEAD'
mu Decision : Type 0 :=
  | release : Decision
  | refund : Decision
  | hold : Decision
mu Ballots : Type 0 :=
  | bnil : Ballots
  | bcons (h : Decision) (t : Ballots) : Ballots
def rec foldBallots : (0 B : Type 0) -> (Decision -> B -> B) -> B -> Ballots -> B :=
  fun (0 B : Type 0) (f : Decision -> B -> B) (z : B) (xs : Ballots) =>
    match xs as w in Ballots return B with
    | bnil => z
    | bcons h t => f h (foldBallots B f z t)
def T3 : Type 0 := prod (Nat, prod (Nat, Nat))
mu EqT3 : (0 a : T3) -> (0 b : T3) -> Type 0 :=
  | reflT3 : (0 x : T3) -> EqT3 x x
def bump : Decision -> T3 -> T3 := fun (d : Decision) (t : T3) =>
  match d as w in Decision return T3 with
  | release => tuple (natAdd t.0 1, t.1)
  | refund => tuple (t.0, tuple (natAdd t.1.0 1, t.1.1))
  | hold => tuple (t.0, tuple (t.1.0, natAdd t.1.1 1))
def tallyOf : Ballots -> T3 := foldBallots T3 bump (tuple (0, tuple (0, 0)))
def b0 : Ballots := bnil
HEAD
ds=(release refund hold)
for (( i = 1; i <= n; ++i )); do
  print -r -- "def b$i : Ballots := bcons ${ds[$(( (i - 1) % 3 + 1 ))]} b$(( i - 1 ))"
done
print -r -- "def tally$n : EqT3 (tallyOf b$n) (tuple ($r, tuple ($f, $h))) := reflT3 (tuple ($r, tuple ($f, $h)))"
