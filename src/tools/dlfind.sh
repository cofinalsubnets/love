#!/bin/sh
# dlfind.sh DIR -- the nearest dl/ at or above DIR: a tree with none of its own (a worktree, a
# nest made inside a checkout) reads the one it sits in. a tree outside any checkout reads the
# nest's: the path on the first line of ~/.love/etc/dl. silent when there is none.
d=$(cd "$1" 2>/dev/null && pwd) || exit 0
while :; do
  [ -d "$d/dl" ] && { echo "$d/dl"; exit 0; }
  [ "$d" = / ] && break
  d=$(dirname "$d")
done
f=${HOME:-/nonexistent}/.love/etc/dl
[ -r "$f" ] || exit 0
read -r p < "$f" || [ -n "$p" ] || exit 0
[ -d "$p" ] && echo "$p"
exit 0
