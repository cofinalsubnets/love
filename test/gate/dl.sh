#!/bin/sh
# test/gate/dl.sh -- the pinned, hash-checked inputs the tests fetch into dl/ themselves, once.
# a failed fetch skips loudly, naming what and from where; a hash that differs is a FAIL: the
# pin or its source moved. dl/NAME/.pin holds the sha it was unpacked from.
#   sh test/gate/dl.sh NAME..   fetch each missing one; exit 1 only on a mismatch
#   . test/gate/dl.sh           after skip.sh: dl_need NAME (the lane skips without it),
#                               dl_want NAME (one leg skips: gate_partly, answers 1)
# dl/ is $DL, else the nearest at or above the tree (dlfind.sh), else ./dl

# NAME: url sha256 member [tar patterns..]; member is the archive's path that becomes dl/NAME,
# or `-` for a lone file
dl_pin() {
  case $1 in
    c-testsuite) dl_p=5c7275656d751de0e68b2d340a95b5681858ed07
      set -- https://github.com/c-testsuite/c-testsuite/archive/$dl_p.tar.gz \
        010008bf4b5671f947ae7e8d693a1c959a4a4d795fa7227c0abb1f95de45f7e7 c-testsuite-$dl_p ;;
    mp3-vectors) dl_p=ea99364f61c14656440e8d77e9c233ccf3124633
      set -- https://github.com/lieff/minimp3/archive/$dl_p.tar.gz \
        5628166eb82a9bb581317918a334c317a2c0a30278bb14a20381307976768f34 minimp3-$dl_p/vectors \
        --wildcards '*/vectors/l3-*' '*/vectors/M2L3*' ;;
    opus-vectors)
      set -- https://opus-codec.org/static/testvectors/opus_testvectors-rfc8251.tar.gz \
        6b26a22f9ba87b2b836906a9bb7afec5f8e54d49553b1200382520ee6fedfa55 opus_newvectors ;;
    tinycc) dl_p=e23dabed154a8495f3ac1ff3cc9d04fa1c207893
      set -- https://github.com/TinyCC/tinycc/archive/$dl_p.tar.gz \
        d2470fdeed862ddb18f4ec4e6a405fa984580c3d85c38492516749c61931c30e tinycc-$dl_p ;;
    chibicc) dl_p=90d1f7f199cc55b13c7fdb5839d1409806633fdb
      set -- https://github.com/rui314/chibicc/archive/$dl_p.tar.gz \
        cadb44e82354002000f6d2bbf41d3155f47a9b3e9abd50a309fdcd9b5ef791e0 chibicc-$dl_p ;;
    edk2-ovmf)
      set -- https://github.com/osdev0/edk2-ovmf-nightly-bins/releases/download/20260531T041444Z/edk2-ovmf.tar.gz \
        534384e4b971730143f54708493fe43932eabbfd275094b636561fb2028bde62 edk2-ovmf \
        --exclude='*secboot*' ;;
    doomgeneric) dl_p=dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284
      set -- https://github.com/ozkl/doomgeneric/archive/$dl_p.tar.gz \
        1bd3f7f26220494159a38d71f2847ec81b58d6bbd7c7c8d81b08993018001148 doomgeneric-$dl_p ;;
    doom1.wad)
      set -- https://raw.githubusercontent.com/Daivuk/PureDOOM/7c19bf5d0fe512a071a701e62618d87c556c329d/doom1.wad \
        1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771 - ;;
    *) return 1 ;;
  esac
  dl_url=$1 dl_sha=$2 dl_mem=$3; shift 3; dl_pat="$*"
}

dl_dir() {
  [ -n "${DL:-}" ] || DL=$(sh src/tools/dlfind.sh .)
  [ -n "$DL" ] || DL=$PWD/dl
}

dl_sum() { sha256sum < "$1" | cut -d' ' -f1; }

# dl_get NAME: 0 when dl/NAME is the pinned one, 2 when it cannot be fetched (said loudly),
# 1 on a hash mismatch (said as a FAIL)
dl_get() {
  dl_pin "$1" || { echo "FAIL dl: no pin for $1" >&2; return 1; }
  dl_dir
  dl_d=$DL/$1
  if [ "$dl_mem" = - ]; then
    [ -f "$dl_d" ] && [ "$(dl_sum "$dl_d")" = "$dl_sha" ] && return 0
  else
    [ -f "$dl_d/.pin" ] && [ "$(cat "$dl_d/.pin")" = "$dl_sha" ] && return 0
  fi
  mkdir -p "$DL" || { echo "SKIP dl: cannot make $DL for $1"; return 2; }
  dl_t=$DL/.$1.$$
  rm -rf "$dl_t" "$dl_t.x"
  echo "MK	dl/$1  <- $dl_url"
  if ! curl -sSfL --retry 2 -o "$dl_t" "$dl_url"; then
    rm -f "$dl_t"
    echo "SKIP dl: COULD NOT FETCH $1 from $dl_url -- the tests that read dl/$1 skip"
    return 2
  fi
  dl_s=$(dl_sum "$dl_t")
  if [ "$dl_s" != "$dl_sha" ]; then
    rm -f "$dl_t"
    echo "FAIL dl: $1 from $dl_url hashes $dl_s, not the pinned $dl_sha" >&2
    return 1
  fi
  if [ "$dl_mem" = - ]; then
    mv -f "$dl_t" "$dl_d" && return 0
    rm -f "$dl_t"; echo "SKIP dl: cannot write $dl_d"; return 2
  fi
  # $dl_pat is word-split on purpose: the tar patterns
  mkdir "$dl_t.x" && tar xzf "$dl_t" -C "$dl_t.x" $dl_pat && rm -f "$dl_t" \
    && echo "$dl_sha" > "$dl_t.x/$dl_mem/.pin" \
    || { rm -rf "$dl_t" "$dl_t.x"; echo "SKIP dl: cannot unpack $1 into $DL"; return 2; }
  # a racing fetch may land first, and keeps it; a stale one moves aside
  [ -f "$dl_d/.pin" ] && [ "$(cat "$dl_d/.pin")" = "$dl_sha" ] && { rm -rf "$dl_t.x"; return 0; }
  [ -e "$dl_d" ] && { mv "$dl_d" "$dl_d.old.$$" 2>/dev/null; rm -rf "$dl_d.old.$$"; }
  mv "$dl_t.x/$dl_mem" "$dl_d" 2>/dev/null || [ -f "$dl_d/.pin" ]
  dl_r=$?
  rm -rf "$dl_t.x"
  [ $dl_r = 0 ] || { echo "SKIP dl: cannot move $1 into $dl_d"; return 2; }
}

dl_need() {
  dl_get "$1"
  case $? in 0) ;; 2) gate_skip "${name:-dl}: no dl/$1 (could not fetch it) -- skipped" ;; *) exit 1 ;; esac
}
dl_want() {
  dl_get "$1"
  case $? in 0) return 0 ;; 2) gate_partly "${name:-dl}: no dl/$1 (could not fetch it) -- that leg skipped"; return 1 ;; *) exit 1 ;; esac
}

case $0 in
  *dl.sh)
    bad=0
    for n in "$@"; do dl_get "$n"; [ $? = 1 ] && bad=1; done
    exit $bad ;;
esac
