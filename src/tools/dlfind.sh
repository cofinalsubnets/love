#!/bin/sh
# dlfind.sh DIR -- the nearest dl/ at or above DIR: a tree with none of its own (a worktree, a
# nest made inside a checkout) reads the one it sits in. silent when there is none.
d=$(cd "$1" 2>/dev/null && pwd) || exit 0
while :; do
  [ -d "$d/dl" ] && { echo "$d/dl"; exit 0; }
  [ "$d" = / ] && exit 0
  d=$(dirname "$d")
done
