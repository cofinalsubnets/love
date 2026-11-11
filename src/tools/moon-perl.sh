#!/bin/sh
# moon-perl.sh -- build perl 5.40's miniperl with mooncc + moonlibc + the holo linker (no
# gcc/glibc/ld) and prove it runs: a battery, perl's own build steps (buildcustomize,
# configpm, make_patchnum) on it, then the minitest suite, each script that may fail named
# with why. every perl source compiles unpatched; only config.h is corrected.
#
# point PERLSRC at a Configure'd perl-5.40.x tree (config.h exists), or let it find
# `perl-5.40*` under dl/ then $MOONSRC (~/src when unset); a missing tree skips. to make one:
#   curl -LO https://www.cpan.org/src/5.0/perl-5.40.2.tar.gz
#   tar xzf perl-5.40.2.tar.gz
#   (cd perl-5.40.2 && sh Configure -des -Dusedl=undef -Uuseithreads)
#   make moon-perl PERLSRC=$PWD/perl-5.40.2
#
# gcc runs only in the one-time Configure. the tree is copied to out/moonperl and its
# config.h corrected there, from glibc's answers to moonlibc's: the headers and functions
# moonlibc does not carry undefined, fcntl.h named where sys/file.h was, and long double
# laid as double (mooncc's is 8 bytes; Configure measured gcc's 16-byte x87).
set -e

pkgfind() {                        # pkgfind <dir-glob> <witness-file>
  for c in dl/$1 "${MOONSRC:-$HOME/src}"/$1; do
    [ -f "$c/$2" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 0
}

name=moon-perl
ho=out
mc="$ho/love mooncc"
love=$ho/love
PERLSRC=${PERLSRC:-$(pkgfind 'perl-5.40*' config.h)}

if [ ! -f "$PERLSRC/config.h" ]; then
  echo "$name: no Configure'd perl-5.40 found (looked in dl and ${MOONSRC:-$HOME/src}) -- skipped."
  echo "         set PERLSRC=<a Configure'd perl-5.40 tree> to run (see src/tools/moon-perl.sh)."
  exit 0
fi
[ -x "$love" ] || { echo "$name: missing $love -- run 'make host'"; exit 1; }

d=$(pwd)/$ho/moonperl
rm -rf "$d"; mkdir -p "$d"
cp -a "$PERLSRC" "$d/src"
P=$(cd "$d/src" && pwd)

# --- config.h, glibc's answers corrected to moonlibc's ---
# headers moonlibc does not carry
nohdr="I_BFD I_CRYPT I_DBM I_DLFCN I_EXECINFO I_GDBM I_LANGINFO I_MNTENT I_NDBM I_QUADMATH
  I_SHADOW I_SYSLOG I_SYSUIO I_SYS_DIR I_SYS_FILE I_SYS_POLL I_SYS_STATFS I_SYS_STATVFS
  I_SYS_SYSCALL"
# functions it does not: the posix-2008 locale family, the *at and cloexec calls, the old
# bsd calls, sysv ipc, netdb, and what glibc alone answers
nofn="HAS_NL_LANGINFO HAS_NL_LANGINFO_L HAS_NEWLOCALE HAS_USELOCALE HAS_DUPLOCALE
  HAS_FREELOCALE HAS_QUERYLOCALE HAS_POSIX_2008_LOCALE USE_LOCALE_THREADS HAS_LC_MONETARY_2008
  HAS_STRXFRM HAS_STRXFRM_L
  HAS_ACCEPT4 HAS_DUP3 HAS_LINKAT HAS_MKOSTEMP HAS_PIPE2 HAS_FUTIMES HAS_EACCESS
  HAS_ALARM HAS_PAUSE HAS_VFORK HAS_KILLPG HAS_GETPGID HAS_SETPGRP HAS_FLOCK HAS_FLOCK_PROTO
  HAS_LOCKF HAS_TELLDIR HAS_SEEKDIR HAS_READDIR_R HAS_SETLINEBUF HAS_CLEARENV HAS_TRUNCL
  HAS_MODFL HAS_MODFL_PROTO HAS_MEMRCHR HAS_GETLOGIN HAS_GETLOGIN_R HAS_TTYNAME HAS_TTYNAME_R
  HAS_GETGROUPS HAS_SETREUID HAS_SETREGID HAS_SETRUID HAS_SETRGID HAS_PRCTL HAS_PRCTL_SET_NAME
  HAS_SIGINFO_SI_BAND HAS_CRYPT HAS_CRYPT_R HAS_GETSPNAM HAS_GETSPNAM_R HAS_BACKTRACE
  HAS_DLADDR HAS_SYSCALL HAS_STATVFS HAS_FSTATVFS HAS_STATFS HAS_FSTATFS HAS_GETMNTENT
  HAS_HASMNTOPT HAS_READV HAS_WRITEV HAS_RECVMSG HAS_SENDMSG HAS_STRUCT_MSGHDR
  HAS_STRUCT_CMSGHDR
  HAS_MSG HAS_MSGCTL HAS_MSGGET HAS_MSGRCV HAS_MSGSND HAS_SEM HAS_SEMCTL HAS_SEMGET HAS_SEMOP
  HAS_SHM HAS_SHMAT HAS_SHMCTL HAS_SHMDT HAS_SHMGET HAS_SHMAT_PROTOTYPE
  HAS_GETHOSTBYNAME HAS_GETHOSTBYADDR HAS_GETHOSTENT HAS_SETHOSTENT HAS_ENDHOSTENT
  HAS_GETHOSTBYNAME_R HAS_GETNETBYNAME HAS_GETNETBYADDR HAS_GETNETENT HAS_SETNETENT
  HAS_ENDNETENT HAS_GETPROTOBYNAME HAS_GETPROTOBYNUMBER HAS_GETPROTOENT HAS_SETPROTOENT
  HAS_ENDPROTOENT HAS_GETSERVBYNAME HAS_GETSERVBYNAME_R HAS_GETSERVBYPORT HAS_GETSERVENT
  HAS_SETSERVENT HAS_ENDSERVENT"
C=$P/config.h
for m in $nohdr $nofn; do sed -i "s|^#define $m\b.*|/* #undef $m */|" "$C"; done
sed -i 's|^/\*#define I_FCNTL\t/ \*\*/|#define I_FCNTL /**/|' "$C"
# long double is double: its size, kind, mantissa and the inf/nan bytes
sed -i 's|^#define LONG_DOUBLESIZE .*|#define LONG_DOUBLESIZE 8 /**/|;
        s|^#define LONG_DOUBLEKIND .*|#define LONG_DOUBLEKIND 0 /**/|;
        s|^#define LONGDBLMANTBITS .*|#define LONGDBLMANTBITS 52 /**/|;
        s|^#define LONGDBLINFBYTES .*|#define LONGDBLINFBYTES 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x7f /**/|;
        s|^#define LONGDBLNANBYTES .*|#define LONGDBLNANBYTES 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0xff /**/|' "$C"
sed -i "s/^longdblsize=.*/longdblsize='8'/; s/^longdblkind=.*/longdblkind='0'/" "$P/config.sh"
grep -q '^#define I_FCNTL' "$C" && grep -q '^#define LONG_DOUBLESIZE 8' "$C" \
  || { echo "FAIL config.h corrections did not take (a Configure other than 5.40's?)"; exit 1; }

echo "MOON-PERL  $PERLSRC  (mooncc + moonlibc + holo, no gcc/glibc/ld)"

# miniperl's objects, as the Makefile's miniperl_objs: common, then the mini-only three
OBJS="av builtin caretx class deb doio doop dquote dump globals gv hv keywords locale mathoms
  mg mro_core numeric pad peep perlio perly pp pp_ctl pp_hot pp_pack pp_sort pp_sys reentr
  regcomp regcomp_debug regcomp_invlist regcomp_study regcomp_trie regexec run scope sv taint
  time64 toke utf8 util miniperlmain"
CFLAGS="-DPERL_CORE -I$P -Isrc/apps/moon/include"
for b in op perl universal; do ln -sf $b.c "$P/${b}mini.c"; done

# the libc floor, as moon-m4.sh lays it
for f in src/apps/moon/lib/moonlibc/math/*.c; do
  b=`basename "$f" .c`
  $mc -Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include -c "$f" "$d/m_$b.o" || { echo "FAIL mooncc -c $f"; exit 1; }
done
{ cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l src/love/holo/elf.l src/love/holo/obj.l src/apps/moon/lib/mksys.l
  echo "((cite 'moon 'mksys-x64) \"$d/sys.o\")"; } | $love || { echo "FAIL mksys sys.o"; exit 1; }

# uudmap.h, bitcount.h and mg_data.h are written by a program of perl's, built here too
$mc $CFLAGS -c "$P/generate_uudmap.c" "$d/gu.o" || { echo "FAIL mooncc -c generate_uudmap.c"; exit 1; }
$mc "$d/gu.o" "$d"/m_*.o "$d/sys.o" -o "$d/generate_uudmap" || { echo "FAIL link generate_uudmap"; exit 1; }
gu=$(cd "$d" && pwd)/generate_uudmap
(cd "$P" && "$gu" uudmap.h bitcount.h mg_data.h) || { echo "FAIL generate_uudmap"; exit 1; }

objs=""
for b in $OBJS; do
  $mc $CFLAGS -c "$P/$b.c" "$d/$b.o" || { echo "FAIL mooncc -c $b.c"; exit 1; }
  objs="$objs $d/$b.o"
done
for b in opmini perlmini universalmini; do
  $mc $CFLAGS -DPERL_IS_MINIPERL -DPERL_EXTERNAL_GLOB -c "$P/$b.c" "$d/$b.o" || { echo "FAIL mooncc -c $b.c"; exit 1; }
  objs="$objs $d/$b.o"
done
$mc $objs "$d"/m_*.o "$d/sys.o" -o "$P/miniperl" || { echo "FAIL holo link miniperl"; exit 1; }
echo "  linked $(wc -c < "$P/miniperl") bytes -> $P/miniperl"

# ---- prove it runs ----
mp="$P/miniperl"
# a utf-8 LANG takes: perl's composite LC_ALL goes through setlocale and back, unwarned
t=$(unset LC_ALL; LANG=en_US.UTF-8 "$mp" -e 'print "ok\n"' 2>&1)
[ "$t" = "ok" ] || { echo "FAIL LANG=en_US.UTF-8: '$t'"; exit 1; }
# the rest in C, as perl's own suite expects
export LC_ALL=C
t=$("$mp" -e 'print "ok\n"')
[ "$t" = "ok" ] || { echo "FAIL print: '$t'"; exit 1; }
t=$("$mp" -e 'my %h=(b=>2,a=>1); printf("%s %d %.3f %s", join(",",sort keys %h), 6*7, atan2(1,1)*4, scalar reverse "evol")')
[ "$t" = "a,b 42 3.142 love" ] || { echo "FAIL hash/printf/atan2: '$t'"; exit 1; }
t=$("$mp" -e '"id:7" =~ /(\w+):(\d+)/ and print "$1 $2"; print " ", unpack("H*", pack("NnC", 1, 2, 3))')
[ "$t" = "id 7 00000001000203" ] || { echo "FAIL regex/pack: '$t'"; exit 1; }
t=$("$mp" -e 'print 9**9**9, " ", -9**9**9, " ", 0+"nan" != 0+"nan" ? "nan" : "?"')
[ "$t" = "Inf -Inf nan" ] || { echo "FAIL inf/nan: '$t'"; exit 1; }
echo "  OK a utf-8 LANG + print + hash/sort/printf + regex/pack + inf/nan"

# perl's own build steps, run by the miniperl they build
(cd "$P" && ./miniperl -w -Ilib -Idist/Exporter/lib -MExporter -e '<?>') || { echo "FAIL miniperl -MExporter"; exit 1; }
(cd "$P" && ./miniperl -Ilib -f write_buildcustomize.pl) || { echo "FAIL write_buildcustomize.pl"; exit 1; }
(cd "$P" && ./miniperl -Ilib make_patchnum.pl > /dev/null) || { echo "FAIL make_patchnum.pl"; exit 1; }
(cd "$P" && ./miniperl -Ilib configpm > /dev/null) || { echo "FAIL configpm"; exit 1; }
echo "  OK buildcustomize + make_patchnum + configpm"

# the minitest suite. a script may fail only for a reason named here; the rest must pass
known="
io/errnosig.t      alarm
io/pipe.t          alarm
op/alarm.t         alarm
op/sigdispatch.t   alarm
io/fs.t            futimes
op/crypt.t         crypt
op/tie_fetch_count.t crypt
io/semctl.t        sysv ipc
op/time.t          a change to TZ is not read again
op/chdir.t         Errno, which minitest does not build
op/do.t            Errno
op/require_errors.t Errno
op/smartmatch.t    Errno
op/magic.t         parent, which minitest does not build
op/tiehash.t       parent
op/taint.t         experimental, which minitest does not build
op/split_unicode.t the unicode tables, which minitest does not build
op/tr.t            the unicode tables
re/pat.t           the unicode tables
re/regex_sets.t    the unicode tables
re/script_run.t    the unicode tables
"
(cd "$P/t" && rm -f perl && ln -s ../miniperl perl)
log=$d/minitest.log
(cd "$P/t" && PERL_SKIP_TTY_TEST=1 timeout 3000 ./perl -I../lib TEST base/*.t comp/*.t cmd/*.t \
   run/*.t io/*.t re/*.t opbasic/*.t op/*.t uni/*.t perf/*.t > "$log" 2>&1) || true
tail -2 "$log" | grep -q 'scripts=' || { echo "FAIL minitest did not finish (see $log)"; exit 1; }
failed=$(sed -n 's/^\t\([a-z]*\/[^ ]*\.t\)$/\1/p' "$log")
bad=""; fixed=""
for f in $failed; do
  printf '%s\n' "$known" | grep -q "^$f " || bad="$bad $f"
done
for f in $(printf '%s\n' "$known" | awk 'NF {print $1}'); do
  printf '%s\n' "$failed" | grep -qx "$f" || fixed="$fixed $f"
done
summary=$(tail -1 "$log")
[ -z "$fixed" ] || echo "  now passing, drop from known:$fixed"
[ -z "$bad" ] || { echo "FAIL minitest:$bad (see $log)"; exit 1; }
n=$(printf '%s\n' "$failed" | awk 'NF' | wc -l)
echo "  OK minitest: $n known failures, the rest pass ($summary)"

echo "$name: perl 5.40 miniperl built by mooncc + moonlibc + holo, runs its own build steps + minitest -- ok"
