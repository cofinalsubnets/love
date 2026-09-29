# kore — the multi-call toolbox

apps/kore/ orients here; the laws live in test/law/kore.l, the GNU-identical smokes in
`make test_kore`, and every doubt settles by probing the built `kore`.
Speed and adversarial inputs are a different page, filled by
`make -C bench korebench` (kore against busybox, uutils and GNU).

**the inventory below names TOOLS, never their flag coverage**, and the two are not the
same reach. A tool listed here answers to its name; which options it answers to is stated
at the head of its own source, absences included. `make -C bench korebench` found the two
worst of those absences by running the flags rather than reading the list — `sort` had no
`-n` and `ls` no `-l`, each reading the flag as a filename — and both now carry a matrix
against GNU (`test/kore/sort.sh`, `test/kore/ls.sh`) inside `make test_kore`.

kore is love's unix userland, and the verb for it: busybox's multi-call trick done natively.
The love-native POSIX environment over the Linux kernel is kernel + a static `love` + .l
files, and kore is its coreutils and more — sh, make, vi, cc, nc, the archives. How it
compares to busybox, toybox, GNU and uutils, name by name, is the census at the foot.

## the shape

ONE roster — `$(korefiles)` in the Makefile: kore_head (kore's own toolboxes, apps/libra/lint.l,
apps/vi/, apps/tui.l, apps/dns.l, apps/nc.l, the lush files, apps/cook.l), the holo linker
files, kore_arc (gz.l tar.l cpio.l) and kore_net (the tls stack, wget.l, www.l and net.l). The
crew rides IN the default binary's own image, so the
build tree's spelling is `love kore TOOL` and the installed `bin/kore` is a four-line sh
shim — re-evaling the cat per spawn costs ~1.3s, so only the distro, which has no image
to ship, still runs it as a `#!/bin/love` script.
`apps/kore/kore.l` loads LAST and dispatches off the program seat of `cmdline`: `kore TOOL
ARGS..`, or symlink a tool's name to kore and argv[0] picks it (how the distro shadows at
will). The registry is a tablet, so tool names never collide with the globals they call (the
`mkdir` applet CALLS the `mkdir` nif; different namespaces).

The file discipline, two shapes:

* **a tool with a seat** (apps/nc.l, apps/cook.l): define-only, leaking
  one `<tool>-main`; a body-having tail fires it iff the file's own basename
  sits in the program seat — so the same file is a standalone tool AND a quiet
  cat member.
* **a toolbox** (core.l, fs.l): many mains, NO seat — kore is its door.

`--help` and `--version` are answered at that door, not in the tools: `koredoor` in
kore.l wraps every applet on both dispatch lanes (the verb registry and the symlink), so
one synopsis table — `korehelp` — is where a tool's shape is written down, and the two
lanes cannot drift. The door itself is cli's, `udoor` in post.l, and the crew's own verbs
(mc, lupa, pom, tower, story, design, slop, libra, sb, tar, fat, doom) stand at the same one; what
kore keeps is the policy below. The walk reads only the leading flag words and stops at
the first operand and at `--`. It is NOT getopt: a value word that looks like a flag is walked
over, so `grep -e --help f` answers the help rather than searching for `--help` — glue
the value (`grep -e--help f`) to mean the pattern. `-h` comes too, except where the letter
is the tool's own or POSIX and GNU spell it otherwise (`korenoh`: grep du df ls sort touch
chown ln free); `-v` never does — GNU gives --version no short spelling, and the letter is
the tool's wherever it wants one. echo, test and `[` read no options at all and are not at
the door; cook and lush answer both flags themselves, each with more to say than a synopsis.

## the inventory (197 tools, 211 names)

The `applets` tablet in kore.l; the aliases are make/cook, sh/lush, ls/dir/vdir,
less/more, pic/pngcat/jpegcat/gifcat and picless/pngless/jpegless/gifless (`pic cat` and
`pic less`). love's own verbs
carry the rest of the userland the census counts: `cc` (mooncc, doc/misc/moon.md),
`mkdosfs`/`mkfs.vfat` and `fat`, `mc`, `pom`.

| where | tools |
| --- | --- |
| kore.l (thin mains) | readelf (binutils' -h -l -S -s -e, at 80 columns or -W, the dynamic symbols' versions with them), diff (diff-main; the patience/myers engines are diff.l), as (elf64 over the holo book), ar (GNU-shape archives + the ranlib index over ld-read, byte-identical smoke), ld (holo's static linker: -pie/-t/-Ttext, byte-identical to mooncc's own link), objcopy (a linked ELF flattened to `-O binary` or `-O ihex`, byte-identical to llvm/gnu objcopy on both), nm, size (binutils' berkeley sums), strip (the symbol table and debugging out of an exe or shared object; `-g` the debugging alone, which is all an object may lose), ranlib (an archive rewritten with its index) |
| apps/nc.l | nc |
| apps/cook.l | make / cook |
| core.l, the line tools | cat tac shuf echo head tail wc sort uniq tee |
| core.l, the field tools | cut tr nl rev |
| core.l, the column tools | fold expand unexpand (all three count COLUMNS, so a tab steps to the next stop), column (lines laid in columns, or `-t` a table) |
| core.l, the line endings | dos2unix unix2dos mac2unix (in place by default; a binary file is refused, the mode is kept) |
| core.l, the encodings | base64 base32 basenc (RFC 4648; basenc's url, hex, base16, the two base2 orders and z85 too; `-d` reads it back, `-w` says the wrap), uuencode uudecode (busybox's, `-m` base64), ascii (toybox's table) |
| core.l, the two little computations | tsort factor |
| core.l, the record tools | paste comm join split od |
| sum.l, the checksums | cksum sum crc32 md5sum sha1sum sha224sum sha256sum sha384sum sha512sum b2sum sha3sum (`-c` reads a list back) |
| core.l, the trivia | seq yes true false basename dirname test [ uname arch nproc |
| awk.l, beside the number engine it shares | printf (C's flags, widths, precisions and conversions but `%a`, `%b` `%q`, the escapes, strto*'s reading and its complaints; reals formatted from their exact binary value, as glibc does, where GNU's are long doubles) |
| core.l, the byte tools | dd xxd strings hexdump hd (the BSD dump: words, or -C's bytes; -n -s -v, no -e) |
| core.l, the shell's helper | getopt (util-linux's: -o -l -n -a -q -Q -T -u, the three operand modes, quoted for `eval set --`; the old `getopt SHORTS` face; -s csh refused) |
| fs.l, the fs tools | ls/dir/vdir cp mv rm mkdir rmdir ln touch lift pwd chmod install readlink cmp |
| fs.l, a name, a mount, a file undone | fsync dircolors (GNU's database, which permits the copy, and its language) pathchk (the system's limits, or POSIX's portable floor under -p/-P) mountpoint (the kernel's mount table; -d, -x) shred (GNU's passes and their arrangement, -z -u -x -s, each pass synced) |
| fs.l, the paths and the two bare calls | realpath link unlink |
| fs.l, what they report | stat du df chown chgrp mktemp truncate |
| expr.l, the little language | expr (arithmetic, the six comparisons, \| and &, and `:` over the BRE engine) |
| patch.l, the diff read back | patch (unified only; -pN -R -i -o --dry-run, offsets, rejects) |
| re.l, the matcher | grep (-nvclqhaixwFEo, -e stacking, -m) over the lawed regex engine, BRE or ERE; egrep and fgrep, grep -E and -F by their old names (kore.l) |
| sed.l, the editor | sed (-n -E -i -e; s///gp, d, p, q; number/$/regex/range addresses) |
| awk.l, the language | awk (patterns and actions, BEGIN/END, arrays, user functions) |
| find.l, the walk | find (names, types, times, sizes, modes; -print0 -delete -exec ; and +; ( ) ! -a -o; the depths) |
| proc.l, the processes and the world | env nohup nice renice setsid printenv sleep usleep kill xargs time ts date id whoami groups |
| proc.l, the terminal | stty (GNU's three views and its settings, the combinations among them), microcom (a serial line and this terminal, byte for byte) |
| proc.l, the host's utmp, read | who users pinky logname (glibc's, netbsd's utmpx and freebsd's utx.active; kore writes none) |
| proc.l, the /proc family | ps free uptime pidof pgrep pkill killall pwdx |
| proc.l, the one-liners | cal hostname hostid dnsdomainname tty clear reset which timeout watch |
| top.l | top (the process table, repainted; `-b` batch) |
| proc.l, the privileged three | chroot (the root moved, then exec), mount (bare = /proc/self/mounts; `-t TYPE`, and the FLAG half of `-o` -- `size=`-style filesystem text is refused by name, not dropped), umount |
| fs.l, what fills a /dev | sync mkfifo mknod (`p b c u`, `-m MODE`, linux's wide device encoding) |
| apps/vi/ | vi |
| ed.l | ed (the line editor), ex (the same buffer by word; its `vi` hands the buffer to vi) |
| less.l, the pager and the byte editor | less / more, hexedit (toybox's, writing each change as it is made) |
| bc.l, the calculators | bc (-l, -q), dc (GNU's, on bc's numbers) |
| wget.l, over the tls stack | wget |
| openssl.l, over the tls stack | openssl (x509, s_client, verify, dgst, rand, base64: the read-only half, openssl 3's spelling) |
| apps/ssh/, over the tls stack | ssh (the client), sshd (the server, for the user it runs as), scp (rcp's protocol over either) |
| apps/gz.l, apps/xz.l, apps/bz2.l, apps/tar.l, apps/cpio.l | gzip gunzip zcat, xz unxz xzcat unlzma lzcat (love/lib/xz.c is the LZMA2 codec), bzip2 bunzip2 bzcat (love/lib/bz2.c), tar, cpio |
| man.l, the pages | man (a page found, decompressed, read as roff and laid out for a terminal) |
| lens.l, the doors onto lapiz | html2text (the lens entered from the other surface), markdown (the lens run the way papel runs it) |
| www.l, over wget.l, lapiz and less.l | www (a web page with its links numbered, followed by number; gopher and gemini too) |
| pic.l, over png.l, jpeg.l and gif.l | pic (pictures printed in cells, two pixels a cell), picless (a viewer: zoom, pan, a gif played) |
| net.l | telnet (a remote terminal: nc with the protocol's options answered), telnetd (its server: a program on a pty per client), httpd (kiosko under busybox's flags), nslookup (a name's records, asked of a nameserver), ping and ping6 (icmp echoes, v4 and v6), traceroute and traceroute6 (the routers on the way) |
| apps/lush.l | sh / lush |

## the discipline (why this stays trustworthy)

* **GNU to the byte.** Every tool with printable output is smoked byte-identical against the
  real GNU tool in `make test_kore` (LC_ALL=C for sort/ls). The fussy faces are pinned
  deliberately: wc pads every field to the digit width of the byte TOTAL; uniq -c wears width
  7; nl is pad-6 + tab and a blank line is seven bare spaces; head/tail banner many files with
  `==> name <==`; `base64 -w 0` ends with no newline at all; `ls -l`'s date column has
  two forms and the boundary is 31556952/2 seconds, coreutils' own half-year. Effects
  (cp/mv/rm/..) are smoked by acting and then verifying with the shell, and the encodings are
  smoked over a BINARY file, which is the only input that says anything.
* **the u-floor.** The shared helpers leak u-prefixed from apps/kore/u.l and are lawed pure in
  test/law/kore.l: uatoi uread udie upad/urpad ujoin uhdr uhead/utail ucount ubase/udir usplit
  ujoinc uspec/upick uset urev udirp, core.l's ucol/utac/ufold/uexpand/uunexpand, the coder
  trio ubenc/ubdec/ubwrap and ucivil/udays, fs.l's uoct/udest/ucopy/rp-parts, and proc.l's
  udur plus the /proc floor (uprocs ustatf upstat upcmd uclk uhms utty uupsay umeminfo
  usignum). The operand walk every reading tool rides is u.l's too: `uwalk` (files or stdin,
  `-` reads stdin, a miss complains on err and the exit code remembers), `ureach` a reader per
  operand, `ulines` a line at a time, `uchunks` a bufferful, `urdj` the operands joined.
* **the exit door.** A main ANSWERS its status as a charm; it does not quit. A leave from deep
  inside a walk rides `udie`, which says its sentence and then `uleave` — a scare carrying the
  status — and `urun` is the driver both faces come back through, flushing the ports and
  answering the charm. So the seat is the one site that quits (`kore-main` answers, and the
  tail of kore.l quits with it), and a caller staying in the image lives through a tool that
  fails: `kore-main` is the in-image door, taking `(link "kore" "ls" "-l")` and answering the
  status. mooncc rides the same floor with two doors of its own — `moon-run` answers, `moon-main`
  quits with what it answers (doc/misc/moon.md). nothing unwinds through a scare, so a port a tool
  still holds at the leave is lost, exactly as `quit` lost it. The property is gated in
  test/kore/prop-status.sh and test/gate/moon.sh; a regression to `quit` passes every other check.
* **the nif lane.** fs effects ride love/posix.c (app-glob LvNif, no core edit) and its
  `posix_` conventions: an effect op answers () ok | an errno nom | 'badarg misuse; a
  value op answers the value | () absence | a nom. love/posix.c holds rename symlink readlink chmod chown utime
  umask rmdir hardlink (`link` the word belongs to the chain ctor). test/fs.l smokes them
  under test_hostnif. `!e` is the success test, `nom? e` the failure test, and a
  specific errno matches by name (mv's `(= e 'exdev)` lane). test/kore/fs.sh
  carries a failure row per tool.
* **exit codes.** 0 clean, 1 something failed (reported on err, the loop continued), 2 usage;
  diff keeps its classic 0/1/2 triple.

## traps

* `show` is the decimal formatter; `string` of a number makes a ONE-CHARM text.
* prel `sort` on strings IS lexicographic (probed via the "b"-vs-"ab" discriminator), which is
  exactly LC_ALL=C. `sortby` is stable only under a `<=`-shaped predicate: handed a strict
  `<` it reverses equal keys. `sort -u` picks a representative out of every equal run, so
  the applet carries the index as its last tiebreak rather than leaning on the predicate.
* a symlink TARGET resolves relative to the LINK's directory, not the cwd.
* lines/unlines normalize an unterminated final line; cat, head, tail and tac keep it as GNU
  does, and sort and uniq add the newline, as GNU sort does.
* a value that can legitimately net 0 — an end index, a (0 0) span — reads BLUE (falsy): give
  it uread's (1 ..) success shape. And never name a local `err` or `out`; they are the PORTS,
  and the shadow says into a charm.

## the column tools, the encodings, tsort and factor (apps/kore/core.l)

`fold`, `expand` and `unexpand` are one section because they share `ucol`: all three count
COLUMNS, so a tab steps to the next stop, `\b` steps back one and `\r` starts the line over.
`fold -b` asks for bytes instead, `-s` backs the break up to the last blank, `-w N` and the
obsolescent `-N` both say the width; `expand -t N -i`; `unexpand -a`, and `-t N` means `-a`
too, as GNU's does.

`column [-tx] [-c COLUMNS] [-s SEP] [-o SEP] [FILE..]` lays lines out as util-linux's does,
byte for byte (test/kore/column.sh holds it to the system's). Filling, every column is one
width: the widest entry's, taken past the next tab stop, the pad in tabs, down the columns
unless `-x`, across `-c`'s width, else `$COLUMNS` or the terminal or 80. `-t` makes a table:
fields split on whitespace (a run as one, the ends dropped), or on each of `-s`'s characters
so an empty field stays; each column as wide as its widest cell, `-o` between (two spaces),
a short row padded out to the last column. Blank lines are skipped and widths are screen
columns, a wide character two. One corner parts from util-linux: with `-x` and no room for
even one column, util-linux runs every name onto one line; kore writes a name a line, as the
BSDs do and as util-linux itself does without `-x`.

* **a tab lands only where it saves at least two columns**, which is why a lone space
  sitting on a tab stop stays a space. It is the one rule the obvious unexpand gets wrong.
* fold breaks BEFORE the charm that would overflow, so a charm wider than the whole width
  still gets a line of its own.

`base64` and `base32` are one coder over two alphabets (RFC 4648): 3 bytes to 4 charms at 6
bits, 5 to 8 at 5, the short tail padded with `=` either way. `-d` reads it back — a newline
is ignored, anything else outside the alphabet is refused with exit 1 — and `-w` says the
wrap, 76 unsaid.

* **`-w 0` closes nothing.** GNU ends a wrapped last line with a newline but leaves one
  long line without one, so the obvious implementation is a byte too long.

`tsort` answers **a** topological order and not GNU's: where the input pins one they agree,
and where it does not both are right, so the gate only asks about inputs that pin one. A loop
is named on err, broken at the first node still standing, and leaves 1. `factor` is trial
division by 2 and the odd numbers — exact for anything this tree spends, and a twenty-digit
semiprime will simply sit there, which is what GNU keeps a Pollard rho for.

## the regex engine (love/boot/post.l, module 're)

BRE and ERE, one parser: the dialects differ only in which sigils wear a backslash. Literals,
`.`, `*`, `+`, `?`, `{n,m}` intervals, `|` alternation, `^`/`$`, ( ) groups, [..] classes with
ranges, negation and the twelve POSIX [:name:] classes (first-] and edge-- literal) — with
GNU's leniency (a repeat with no atom is ink) and one refusal, backrefs, as a parse error.
It left kore because it is pure; apps/kore/re.l is grep over it. `(rebre p)` answers `(1 nodes ngroups)` | `()`; `(rehas
nodes s)` the boolean; `(refind nodes s i)` the leftmost greedy span as `(1 start end)` — the
`(1 ..)` shapes because a match ending at 0 is blue by measure. The matcher is greedy
backtracking in continuation style; the laws hold the dialect by hand AND by a seeded
differential fuzz against an independent Brzozowski-derivative oracle. grep rides it —
GNU-byte-identical smokes + the 0/1/2 exit triple (an unreadable file beats a match).
`refind` carries group SPANS (numbered in \( order, a repeated group reading as its LAST
iteration, GNU's \1) — sed's food.

## sed-lite (apps/kore/sed.l)

Over the regex engine. `sed [-nEi] [-e SCRIPT].. SCRIPT [FILE..]`: ;/newline-separated commands, each [ADDR[,ADDR]] VERB;
addresses number/$/(BRE)/re/, ranges open-at-first close-at-later (numeric end at-or-before
start = one line, like GNU); verbs p, d, q (one address), and s/RE/REPL/[g][p] with any
delimiter — & and \1..\9 in the replacement, the POSIX empty-match rules exact (step after an
empty replacement, DISCARD an empty match where the last one ended: `s/x*/-/g` on "xbz" is
"-b-z-"). Input is the concatenated stream ($ = its last line); unreadable files
complain-and-flow, exit 2; a bad script exits 1 (GNU's split). The pure floor (sparse, usub) is
lawed; the whole face is smoked byte-identical vs GNU (a 12-script battery + -n + stdin + the
error faces). Out of dialect, deliberately: GNU's empty-pattern reuse, \n in replacements, hold
space.

## the process tools (apps/kore/proc.l)

One nif of their own — `rusage` (love/posix.c: `(rusage who)` -> the user and sys microseconds
of this process or of the children it has reaped) — and otherwise environ/getenv/setenv,
spawn (pid | the failure's nom; a child that cannot exec
_exit(127)s) + wait, still (posix.c's kill), rest (core sleep, ms). env prints the world or
assigns K=V.. and runs the command with the child's exit; sleep sums decimal durations with
s/m/h/d suffixes (udur, lawed); kill sends -N or -NAME (default TERM) per pid, exit 0/1; xargs
whitespace-splits stdin (quote-blind, deliberately) onto the command's tail (echo by default),
-n N a batch at a time, exits 0 / 123 (a run failed) / 127 (could not exec), running once even
on empty input, all like GNU. `printenv` prints the world or just the names asked for (a name
with nothing in it says nothing and the exit remembers); `whoami` and `groups` are id's two
thin faces, so they read /etc/passwd and /etc/group exactly as id does. `arch` and `nproc`
live in core.l beside uname, which is the other tool that reads the machine: arch IS uname -m
and nproc counts what /proc/cpuinfo names, which is GNU's `--all` — nothing here reads an
affinity mask.

`time [-p] CMD [ARG..]` costs a command: **real** off the wall clock, **user** and **sys** out
of the children's rusage read on both sides of the spawn — the child is the only one reaped in
between, so the difference is its own. Three lines on stderr, after the command's own output,
seconds to two places; the status answered is the command's. `-p` is the spelling of the one
face, not a switch between two. A kernel with no `rusage` row (netbsd, and inle) reports real
and dashes the other two rather than call two zeroes a measurement.

## the niceness, the terminal, the utmp (apps/kore/proc.l)

Four nifs in love/posix.c: `(prio which who)` and `(setprio which who n)` over get/setpriority
(moonlibc answers linux's `20 - nice` and a BSD's raw nice as one face), and `(termios fd)` /
`(settermios fd l)`, the line discipline as a flat list in linux's canonical bits, which
moonlibc respells for a BSD (a BSD's 0xff "disabled" reads as 0, and the characters linux has
no name for are kept as the terminal has them).

* `nice` and `renice` are GNU's and util-linux's to the message: a refused raise is said and
  the command runs anyway, renice reports each id and warns each failure.
* `stty` is GNU's three views (bare the changes from sane, `-a`, `-g`), wrapped at the
  terminal's width as GNU wraps, and its settings, combinations included. Like GNU it reads
  the state back after setting it and says when the terminal refused part of it (a pty takes
  no parity). There is one speed: `ispeed` and `ospeed` both set it.
* `who`, `users` and `logname` read the host's file in its own shape: glibc's 384-byte records,
  netbsd's 520-byte utmpx, freebsd's packed big-endian futx. GNU's columns and flags, in UTC.
  A user record counts only while its process lives, as GNU's check does. `logname` is linux's
  loginuid where there is one, else the record holding stdin's terminal (matched by device, so
  no ttyname). kore writes no utmp; on a system with none these say so.

## awk (apps/kore/awk.l)

A POSIX awk: BEGIN/END, `pattern { action }` items, `expr, expr` ranges, fields with `$0`
rebuilding on either side, the special variables (NR NF FS OFS ORS FILENAME FNR SUBSEP RSTART
RLENGTH CONVFMT OFMT), arrays with `in` and `delete`, user functions whose array parameters
pass **by reference**, and the builtins length substr index split sub gsub match sprintf sin
cos atan2 exp log sqrt int rand srand tolower toupper system close. `-F`, `-v var=value`,
`-f progfile` (repeatable) and command-line `var=value` between file arguments. Regexes are
re.l's ERE dialect; the whole language is smoked byte-identical against gawk in `make
test_kore`, the pure floor is lawed.

Three pieces are worth knowing before reading it:

* **the value is four-faced.** `()` uninitialised, a number, a string, and `('sn n s)` — a
  STRNUM, the thing that came off input looking like a number. It must compare as a number and
  print as the text it arrived in: `"007"` from a field is 7 to `==` and `007` to `print`. Two
  numeric-ish values compare numerically, anything else as text, and that one rule is why the
  field carries both faces rather than one.
* **the numbers are ours.** `show` prints a double round-trip exact; awk owes `%.6g`. So
  aw-fixed/aw-expo/aw-gen do the digits by hand off a normalised mantissa, and aw-sprintf is a
  real printf (flags, width, precision, `d i o u x X c s e E f g G`). They round half away from
  zero where C rounds half to even — a difference an exact decimal tie can reach and a computed
  double essentially never does.
* **`nil?` is a TRUTH test, not a type one.** It answers 1 for `0`, for `-4` and for `""` as
  readily as for `()`. awk leans on the difference every line, so the empty question is asked by
  identity (`aw-nil?` is `(id? v ())`) and never by truth. Getting this wrong prints `0` as `""`.

Out of dialect, deliberately — each a rung, not an oversight: **getline** in every spelling
(it is the one construct that makes the record loop re-entrant, and half a getline is worse
than none); **output pipes** (`print | "cmd"` — plain `>` and `>>` to a file are here);
**RS** other than newline; **ARGV/ARGC and ENVIRON** (the arguments are walked, not published);
printf's `*` width and `#` flag.

## find (apps/kore/find.l)

`find [-L] [PATH..] [EXPR]`, PATH defaulting to `.`. Tests `-name` `-iname` `-path` `-ipath`
(fnmatch, post.l's glob) `-type f|d|l` `-empty` `-newer FILE` `-mtime N` `-mmin N`
`-size N[cwbkMG]` `-perm [-/]MODE` (octal or symbolic) `-true` `-false`, N as `+N` `-N` or `N`;
actions `-print` `-print0` `-prune` `-delete` `-exec CMD.. ;` `-exec CMD.. {} +`; the global
`-maxdepth`/`-mindepth` and `-depth` (which `-delete` implies), and the operators `( )` `!`/`-not` `-a`/`-and` (implicit between two
primaries) `-o`/`-or`, both short-circuiting, `-a` binding tighter. An expression naming no
action gets `-print`, exactly as GNU does.

* **the walk sorts each directory.** GNU hands out readdir order, which is the file system's
  business and repeats for nobody — so `find | sort` on both sides is the only honest way to
  smoke us against it, and that is what the gate does. Sorted is also what a build wants: the
  same tree cuts the same image twice.
* **symlinks are not followed** (GNU's `-P`, the default). The `stat` nif follows, so the type
  read asks `readlink` FIRST — a link answers `l` whatever it points at, and the walk does not
  descend through it. A dangling link is still visited.
* it loads late in the cat because it captures `sh-match` at its define; find.l's head says so.

## expr, and the record tools (apps/kore/expr.l, apps/kore/core.l)

`expr` is the one applet with a grammar: `|`, `&`, the six comparisons, `+ -`, `* / %`, `:`,
then the primaries (`( )`, `length`, `substr`, `index`, `match`, `+ TOKEN`, a bare word). Its
own file because `:` rides re.l's BRE engine, and a body captures its free names at its define.

* **every value is a TEXT**, and a text that reads as a whole number is a number wherever one
  is wanted. That one rule is the whole type system: `2 < 10` is 1 and `2 < 10a` is 0, because
  the second pair has no number in it.
* the **exit code is a third channel** — 0 the answer is neither `""` nor `"0"`, 1 it is, 2 the
  expression will not do — so the gate compares stdout *and* `$?` on every check.
* **the division truncates toward zero and the remainder wears the dividend's sign**, which is
  C's rule and expr's. love's `//` FLOORS, so the sign is taken out and put back rather than
  divided with; `-7 / 2` is -3 and `-7 % 2` is -1.

`paste`/`comm`/`join`/`split`/`od` read whole files rather than riding `ueach`, because each
walks several at once. Three things are worth knowing:

* **paste's delimiter list cycles per GAP and starts over each row**, and the list advances with
  the separator it spends — never with the cell, since the first cell spends none.
* **join is a relational join**: a key repeated on either side makes the whole cross product,
  file-1-outer. `-o`, `-e` and `-i` are out of dialect (an output template is its own language).
* **od takes ONE -t per run**, the last given winning. GNU's several-at-once lane re-widens every
  column to the widest type in the set, which is a whole layout of its own and not another row.

## the checksums (apps/kore/sum.l)

`cksum`, `sum`, `crc32`, `md5sum`, `sha1sum`, `sha224sum`, `sha256sum`, `sha384sum`,
`sha512sum`, `b2sum`, `sha3sum` — the file streamed a gulp at a time through its digest, one line said. The faces are
GNU's: cksum's `CRC BYTES NAME` (and no name at all reading stdin), sum's two (bsd's 16-bit
rotating sum over 1K blocks, `-s` system v's folded byte total over 512-byte ones), the
digest tools' `DIGEST  NAME` with the two spaces that mean text mode. b2sum's `-l` asks for a
shorter blake2b, which is its own digest and not a prefix of the long one; sha3sum is
toybox's (`-a` any length 128..512, 224 by default, `-S` shake's pad) with busybox's `-c`. `-c` reads such a list back and says
`NAME: OK` / `NAME: FAILED` per line, leaving with 1 if any did not match (b2sum reads a line
of any length it could have written); the gate holds both directions, GNU reading ours and
ours reading GNU's.

The digests themselves are **love/lib/hash.c** (`md5`, `sha1`, the four sha-2s, `sha3`,
`blake2b`, `bsdsum`, `crc32` and `cksum` — the last being POSIX's own crc, a different polynomial from `crc32`'s
and with the byte count folded in, which is why an empty file is `4294967295 0`). md5, sha-1
and the sha-2s share one buffering and one state layout; sha-512 keeps its 64-bit words as
32-bit halves to ride it, and blake2b, which pads nothing and flags its last block, has its
own. There is no love statement of the digests, so an image
that carries no host nif — the kernel's, which compiles no `love/*.c` — answers 2 and names the
digest it is missing rather than saying a wrong number. The probe is asked at first call and
kept, never at load: this file is baked by a love that HAS the nifs.

## what the fs tools report (apps/kore/fs.l)

`realpath` walks a path COMPONENT BY COMPONENT — resolving each symlink as it arrives — so a
last name that does not exist yet still answers, which is GNU's default face and the case a
resolver written around one `stat` gets wrong. `-e` wants the whole path to be there, `-m`
allows any of it to be missing, `-s` takes the links as they lie. `readlink -f` beside it is
STRICTER than GNU's (it wants the path to exist), which is GNU's `readlink -e`; realpath is
the GNU-shaped door. `link` and `unlink` are the two syscalls said plainly, no face on them.

`stat` (bare, or `-c FORMAT` / `--printf=`, which reads the escapes and adds no newline where
`-c` does neither), `du`, `df`, `chown`, `mktemp`. They read the **stat tail**: love/posix.c's `stat`
answers `(size mtime mode ns uid gid nlink blocks ino atime ctime dev rdev blksize)` and `lstat`
the same of the link itself. The tail
is append-only and the KERNEL's own stat (inle/kmain.c) answers the first four alone — an image
tree has no ownership to tell about — so it is asked by `tally` and a world without it says so.

* **the default `stat` face is GNU's block, line for line.** It was refused once, and the
  reason was real: the tuple had no access time, no change time and no device number, so a
  block would have printed the modify time three times over. The last five fields of the tuple
  are those facts, and they cost nothing — one `struct stat` already held them. The birth line
  is the exception: no `struct stat` has a seat for one, so it is the `birth` nif's own call,
  asked once per file by this report alone and never by the `stat`/`lstat` every tree walk
  leans on. It answers on every kernel here — the BSDs out of the stat they already do, linux
  through `statx(2)` — and on a filesystem keeping none it is the dash GNU prints there too.
* **`%t`/`%T` are hex and the block's `Device type:` is decimal** — GNU's own split, and the
  only place the packed device word is taken apart. An unrecognised directive is a bare `?`.
* **du counts `st_blocks`, which is allocation and not size** — a sparse file costs less than it
  measures, a tiny one costs a whole block — and reports 1K units rounded up. `-b`'s apparent
  size counts a FILE's `st_size` and a directory's **not at all**, which is GNU's rule and not a
  guess: an empty directory whose st_size is 40 reports 0. A hard link is counted once per run,
  keyed by inode alone (this stat carries no device). Like find's, the walk sorts each directory.
* **`%N` is shell-quoted, and a link says what it points at.** `'name'`, `"name"` where the
  only trouble is a quote of its own, `'$'\t''` for a control byte — the shell's own rules, so
  the answer pastes back. A byte over 127 rides through: there is no locale here to tell text
  from a stray byte, which is the one place GNU's answer and this one part.
* **`mktemp` MAKES the name** — `openfd` mode 3 is O_EXCL at 0600, and `-d` an exclusive mkdir —
  so the answer is a fact by the time it is printed, not a proposal.
* **`df` reads `/proc/self/mounts` and `statfs(2)`**, which is LINUX's call and no one else's:
  the BSDs spell it over another struct and the syscall map leaves the row out, so a kernel
  without it never gets past the mount list. 1K blocks by default, `-h` the same three-figure
  face as `du -h`, `-i` the inode counts, `-a` the filesystems with no blocks. Every figure
  rounds up and `Use%` is taken off the RAW counts, not the rounded ones. A filesystem whose
  `statfs` refuses is dropped from the bare face and dashed by `-a` — a row of zeroes there
  would read as an answer. GNU's `-a` dashes a few by TYPE (autofs and the rest of its dummy
  list) without asking at all; this one asks, so an automount placeholder reports its zeroes.
* **`id`'s supplementary groups are read out of `/etc/group`**: there is no `getgroups` here and
  no NSS anywhere. The primary comes first, then the rest ascending, which is the order the
  kernel keeps its credential list in and so the order GNU prints.

## the /proc family (apps/kore/proc.l)

`ps`, `free`, `uptime`, `pidof`, `pgrep`, `pkill`, `killall` and `pwdx`. **No nif grew for
any of them** — /proc is a filesystem, so the whole family is `uread` and a parser, and a
world without one (the kernel's own image, which mounts no procfs) reads as *no processes*
rather than as an error.

* **the comm is taken between the FIRST `(` and the LAST `)`** of a stat line, never by
  splitting on spaces: a program may be named `(sd-pam)` or `a b)c`, and a naive split
  reads its parentheses as fields — silently, since every field after it then shifts.
* **`ps` bare is procps' rule**: the processes that are ours *and* share this terminal.
  The owner comes off `/proc/PID` itself, whose directory the process owns — one stat
  where `/proc/PID/status` would be a second read and a second parser. `-e`/`-A`/`a`/`x`
  take every process. The columns are procps' to the space; TIME is USER_HZ 100 and
  truncates, and the hours are never clipped (`100:00:00` is a real answer).
* **`free`'s used is total minus AVAILABLE**, not total minus free — the kernel's own
  estimate of what a new program could have is the only honest reading, and it is what
  procps prints. `-m` and `-g` divide; `-h` wears procps' Ki/Mi/Gi face.
* **`uptime`'s `N users`** is the host's utmp read as `who` reads it: the user records
  whose process is still there. procps asks systemd-logind instead where it can, so the
  two can differ on a desktop. With no utmp the field is left out, never a made-up 0.
  The time of day is UTC, for the reason the clock section gives.
* **the by-name four** match the COMM, which the kernel caps at fifteen charms; `pgrep -f`
  asks the cmdline instead, where a long name survives, and `-x` wants the whole of it.
  `pgrep`/`pkill` never match themselves. The signal spelling (`-9`, `-TERM`) is `kill`'s
  own table, shared.
* the faces are **not smoked byte-for-byte** — the process table moves between two runs —
  so the parsers are lawed and the faces are asked about a process the gate made itself:
  in `ps -e`, found by `pidof`, gone after `pkill`. and the gate kills a COPY of sleep
  under its own name, because `killall sleep` on a shared box reaches into other people's
  work.

## the clock (apps/kore/proc.l)

**UTC and only UTC.** There is no tz database in this tree, so localtime IS gmtime — the same
call moonlibc made, for the same reason. `date -u` is taken and changes nothing. `-d @SECONDS` and
`-r FILE` name a moment other than now, which is also the only thing that makes the tool gateable
against GNU at all; the gate runs the oracle under `TZ=UTC`. The calendar itself is Hinnant's
exact integer civil-from-days in core.l (`ucivil`/`udays`, lawed by the round trip), which stat's
`%y` reads too.

## patch (apps/kore/patch.l)

The other half of diff.l: that file WRITES unified hunks, this reads them back and lays them on
a tree. `-pN` (unsaid drops every leading directory, patch's own default), `-R`, `-i`, `-o`,
`--dry-run`, `-s`. **Unified diffs only, deliberately** — context and normal format are two more
parsers for a shape nothing in this decade emits.

* a FILE is a list of `(text nl)` pairs. **A missing final newline is data** here as everywhere in
  kore, and a patch can both carry one in and take one away, so the flag rides per line.
* **the `\ No newline at end of file` line is tested before the counts run out.** It carries no
  count of its own, so the one closing a hunk arrives after both counters have hit zero — a body
  that stopped on the counts alone leaves every "the patch takes the newline away" case unmarked.
* applying carries a **delta**: the running difference between a seat in the original and the same
  content's seat now. A hunk that does not sit where it says searches outward from there, which is
  what `offset` in patch's report means — and the reach is `n + 1 + |want|`, not `n`, because a
  create hunk's `-0,0` wants seat -1 in a file of no lines.
* a rejected hunk lands in `NAME.rej` **byte-identical to GNU's**, the original in `NAME.orig`,
  and the exit is 1. The `.orig` lands on a MISMATCH and not only on a failure — GNU's
  `--backup-if-mismatch`, since a hunk that moved applied to a file the patch did not describe.
* the gate's oracle is **the tree, not the message**: GNU patch's chatter has moved between
  releases; what it leaves on disk has not.

## the line endings (apps/kore/core.l)

`dos2unix`, `unix2dos` and `mac2unix` are one walk under three names; what separates them is
which break goes in and which comes out. The transform is the easy half — `tr -d '\r'` is most
of `dos2unix` — and it is not why these are tools.

* **In place is the default**, which is what every caller of `dos2unix` means and what no
  ordinary filter does. `-n IN OUT` writes a new file instead; with no operands it is a plain
  stdin-to-stdout filter.
* **A binary file is refused** (a NUL byte says so) unless `-f`. A `dos2unix *` over a mixed
  directory is the accident that rule is there for.
* **The mode is kept**, and `-k` keeps the mtime too.
* **A file already in the target form is not rewritten** — same bytes, no write, so a build
  that runs the rule twice does not touch the timestamp.
* **Neither direction doubles its own output**: `unix2dos` run twice is `unix2dos`, and the
  two are each other's inverse. Idempotence is lawed, because a converter that doubles turns
  a file into `\r\r\n` on the second pass and nothing complains.
* **Only the PAIR is a line ending** for `dos2unix` — a lone CR mid-line survives. A lone CR
  as a break is the classic Mac form and is `mac2unix`'s job.

Not built: `-c` conversion modes (ascii/7bit/iso), BOM handling, `-b` backups, and the
`--info` report.

## html2text (apps/kore/lens.l)

`html2text [-w COLS] [FILE..]`, and the same three-part path `man` takes with the first part
swapped: lapiz's html reader takes the page to the document AST, `ttyshow` lays it out at a
width, and what is left here is the operand walk. papel already runs this lens the other way
(markdown in, html out), so reading html back cost a face and not a parser.

**It is not a browser.** A page is prose to this tool. lapiz's scrub drops the doctype, the
comments, the `<head>` and the `<script>`/`<style>` bodies, and *unwraps* the containers —
`div`, `nav`, `section`, `span` and the rest wrap blocks rather than being one — so what
reaches the reader is headings, paragraphs, lists, definition lists, quotes, displays and the
inline spans. `<b>` is `<strong>` and `<tt>` is `<code>` to a reader with one font.

* **A table is unwrapped to its cells**, which reads as prose and not as a table. The middle
  has no table node, and inventing one in the scrub would be a lie about the lens.
* **A tag with no node here is dropped and its content kept**, so an unknown element costs a
  wrapper and never the text inside it.
* **Text with no `<p>` around it is still a paragraph** — once the containers are gone that
  is where most of a real page's prose turns out to live.
* **An `<a>` is normalized to its href** by the scrub, so the reader knows one link shape;
  an `<a>` with no href is an anchor, not a link, and prints as its text alone.
* Named and numeric entities both decode; an unknown name rides through as written, which is
  better than eating the word it was part of.
* **An `<img>` shows as its `[alt]`**, and on a terminal a local picture is drawn under that
  line, two pixels a cell as `pic` draws it, its path taken from the page's own directory.
  One on the web stays its `[alt]`: this reads files, it does not fetch.

None of this is law 1 — that says `htread` reads what `htshow` writes, and reading a page
*nobody* wrote with `htshow` is a different promise. It is stated in `test/host/lapiz.l` instead.

## markdown (apps/kore/lens.l)

`markdown [-t html|roff|text|dvi] [-w COLS] [FILE..]` — the same lens, driven the direction papel
drives it. `-t html` (the default) is `md->ht`, `-t roff` is `md->rf`, `-t text` is `md->tty`
at a width. `-t dvi` sets one document (a file or stdin; a man page is read as roff) in pages
with caja, TeX's engine in love (apps/caja/), from Computer Modern's metrics and plain TeX's
hyphenation patterns in a TeX tree -- `$CAJA_TEXMF`, else TeX Live's usual places. The roff lane is the build's own page path a command away: `markdown -t roff
doc/love.md` writes what `doc/love.1` is made of, `.TH` and all, because the `.TH` comes from
the document's front matter and lapiz reads front matter as the meta block.

* **The html is a FRAGMENT**, which is what `markdown(1)` has always meant: the blocks, no
  doctype and no head. papel owns the template that wraps one into a page, and a second
  template here would be a second thing to keep true.
* `-w` and the terminal attributes matter to `-t text` only; html and roff carry neither.
* **`![alt](src)` is an image**: an `<img>` in html, its `[alt]` in roff and text, and on a
  terminal `-t text` draws a local picture under its line as html2text does.
* The roff lane normalizes what roff cannot spell — a head at 3+ lands at 2, a fence language
  is dropped, a rule vanishes, a link flattens to its text with the url trailing. That is
  lapiz's stated rf behaviour, not this tool's.

## man (apps/kore/man.l)

`man [-w] [SECTION] NAME..`. The tree writes its pages in `doc/*.md` and the build shows them
as roff (`tools/mkman.l`, through `apps/lapiz.l`); reading one back is the same lens run the other
way. So man owns none of the three hard parts — lapiz's roff reader takes the page to the
document AST, its `ttyshow` lays that out at a width, and `apps/kore/less.l` pages the result.
What is man's own is the search path, the decompression, and the handing over.

* **The search** is MANPATH if it is set, else `/usr/local/share/man`, `/usr/share/man`,
  `/usr/local/man`, each walked in section order. A leading numeric operand is the section.
* **Compression is decided by the magic bytes, not the suffix** — a gzipped page named without
  `.gz` still reads, and a page named `.gz` that is not gzipped is not mangled into one.
* **`.so` redirects are followed once**, resolved under the root the page was found in.
* **`-w` reads nothing**: it answers the path. That is what a script wants, and it is what
  makes the search testable without a terminal.
* **With no terminal the page is poured, and poured plain** — the attributes belong to the
  terminal and a pipe is not one. With one, bold and underline ride through the pager: an SGR
  sequence costs no column there and a wrap re-opens it on the next row.

**mdoc is not read.** A BSD-style page (`.Dd`/`.Sh`/`.Nm` — about one man1 page in twenty-five
here) is a different macro set, and rendering it through the man-macro reader produces a page
of macro names rather than prose. So it is named as unsupported instead of rendered wrong.
Also absent: `apropos`/`whatis`, the cat cache, and `.so` chains deeper than one.

## www (apps/kore/www.l)

`www [-w COLS] URL|FILE`. A text browser that owns none of the hard parts. wget's round trip
fetches, lapiz's `ttpage` lays the page out with every link as `[n]`, and less's engine pages
it. What www adds is URL resolution (RFC 3986 5.2, held to 5.4's table), the history, and a few
keys over less's:

* **`N RETURN`** follows link N, **`N U`** shows its URL, and **`U`** shows the page's own.
* **`o URL`** opens a URL, **`B`** or backspace goes back, **`r`** reloads, and **`h`** is the help.
* **A URL without a scheme is https**, unless it names a file here. A file opens as `file:`,
  and its links resolve against it.
* **With no terminal the page is poured plain, with its references after it**, as `lynx -dump`
  does. A server's error status still shows its page, and exits 8, as wget does.
* **A `#name` lands on the line where lapiz laid that id.** Within the page it's a step in
  the history with no fetch, so back is a scroll. On another page it lands after that page loads.
* **A page opened without a `#name` opens where its own content starts**, past the menus:
  lapiz marks the first `<main>` (or `role="main"`), else an `<article>`. **`m`** goes back
  there, and **`g`** is still the very top.
* **`TAB`** moves to the next link on the screen and **shift-`TAB`** to the one before. The
  current link shows in standout with its URL on the status line, and **`RETURN`** follows it.
* **A form that sends by GET shows each text field as a link**, `[n][name____]`. Following
  one asks for the text, prefilled with what the field holds, and `RETURN` sends the form.
  lapiz writes the form's other controls into the link as they stand: hidden fields, checked
  boxes, the chosen option and the first submit button. A form that POSTs shows no field.
* **Pages come gzipped** when the server will send them that way (apps/gz.l unzips them). A
  page in latin-1 or windows-1252, by its header or else its own `<meta>`, is converted to
  utf-8. A `<base href>` is what the page's links resolve against, and an image shows as its
  alt text.
* **A PNG, JPEG or GIF is drawn under its alt text** on a terminal, two pixels to a cell, as
  `pic` draws it (a GIF stands at its first frame). A picture is fetched when it comes
  within a screen of the view, shrunk to the page's width and the screen's height (never
  enlarged), and kept by URL for the session. The rows are text, so they scroll, page and
  re-lay with the rest.
* **Resizing the window lays the page out again at the new width**, keeping the first link
  that was on the screen at the same place.
* **`gopher://` opens gopher** (RFC 1436, its URLs RFC 4266's). A menu's text lines keep
  their spacing, so the ASCII art stands, and each item is a link marked with its kind:
  `(DIR)`, `(TXT)`, `(?)` for a search, `(HTML)`, `(BIN)`, `(TEL)`. A search item is a field
  like a form's, its answer sent after a tab; a text item has its escaped dots undone; an
  `h` item with a `URL:` selector goes to that URL.
* **`gemini://` opens gemini.** text/gemini is laid as a page: headings, lists, quotes,
  preformatted blocks kept as written, and each `=>` line a link resolved against the page;
  other text shows as it is. A request for input (1x) is a field whose answer goes back as
  the query, a redirect (3x) is followed, and the rest of the statuses are said. The server's
  key is pinned the first time it is seen, host:port and the SHA-256 of its
  SubjectPublicKeyInfo a line in `~/.love/gemini_hosts`, and held to after: gemini's own trust
  on first use. A changed one
  is refused with the line to delete to accept it. When a server asks for a client
  certificate, an empty one goes back.

Absent: forms that POST, scripts, cookies, pictures other than PNG, JPEG and GIF, charsets other than
utf-8, latin-1 and windows-1252, and gemini's client certificates. An https server is
verified as wget's is: its certificate to a root in the host's bundle, or its key to a pin in
`~/.love/tls_pins`; a refusal says which check failed on which certificate. The TLS client speaks chacha20-poly1305 and aes-128-gcm, the
second what RFC 8446 has every server speak.

## pic (apps/kore/pic.l)

`pic` is one command with four verbs; with none it is `pic cat`.

`pic [cat] [-g MODE] [-w COLS] [-h ROWS] [FILE..]` prints each picture, PNG, JPEG or GIF (a
GIF's first frame), as wide as the terminal (or `COLS`, or 80 when there is none) and no
taller than `ROWS` cells, shrunk and never enlarged. With no FILE it reads stdin, and with
several it names each above it. `MODE` picks how:

- `block`, the default: rows of text, two pixels to a cell. The upper pixel is the colour of a `▀` and
  the lower its background, 24-bit where `COLORTERM` says `truecolor` or `24bit` and the
  256-colour cube otherwise. Each cell is the alpha-weighted mean of its pixels' boxes, and a
  mostly see-through pixel is left blank.
- `sixel`: DEC's sixel graphics, up to 255 colours (exact up to that, a median cut past it),
  a see-through pixel left to the ground.
- `kitty`: kitty's graphics protocol, the pixels sent raw in 4096-byte chunks.
- `auto`: on a terminal, pic asks it (kitty's query, the cell size `CSI 16 t`,
  and DA1, whose answer ends the wait, a second at most) and takes kitty's, then sixel, then
  blocks. Off a terminal it draws blocks without asking.

For sixel and kitty's a picture is fitted to `COLS` times the cell's width in pixels (8 by 16
when the terminal does not say). `pngcat`, `jpegcat` and `gifcat` are `pic cat`.

`pic less [-g MODE] FILE..` shows one picture at a time, fitted to the screen, in blocks or
as `-g` says (the modes are `pic cat`'s). In sixel and kitty's a view is sampled by nearest
pixel, so a redraw stays quick, and 100% is a source pixel to a screen pixel. `+` and `-`
zoom (past the fit into single pixels, and back out below it), `0` fits it again, `h` `j` `k`
`l` or the arrows pan a quarter of the view, `n` and `p` move between files. A GIF plays at
its own delays; `space` pauses it and `.` and `,` step a frame. The status line holds the
name, the size, the zoom and the frame. `picless`, `pngless`, `jpegless` and `gifless` are
the same tool.

`pic convert [-q QUALITY] [-t TYPE] IN OUT` writes IN as OUT's type, from its extension
(`.png`, `.gif`, `.jpg`/`.jpeg`, `.six`/`.sixel`, `.ans`) or `-t`. `ans` is the blocks
`pic cat` prints, as text 80 cells wide, for `cat` to show again. `-` is stdin for IN and stdout for
OUT. A GIF gives its first frame, except that a file already of the type goes across as it
is (a GIF keeps its frames), unless `-q` asks for a JPEG to be written again. A JPEG has
no alpha; its quality is 90 unless `-q` says otherwise.

`pic pixelize [-w COLS] [-h ROWS] [-s PX] [-c 256] [-q QUALITY] [-t TYPE] IN OUT` writes
the picture as `pic cat` draws it in blocks at `COLS` (80) by `ROWS`, as a picture: each
half-cell becomes a square of `PX` pixels (by default the source's own scale, so the output
is near the input's size), a pixel the terminal would leave blank is transparent, an odd last
row's lower half is transparent as the cell's is, and `-c 256` takes each channel to the
level the 256-colour cube shows (0, 95, 135, 175, 215, 255). OUT is a PNG unless its
extension or `-t` says otherwise; to `.ans` it is the blocks' text itself, `-c 256` in the
cube's codes.

The decoders: apps/png.l (every colour type and depth, Adam7), love/lib/jpeg.c (baseline and
progressive, any sampling), love/lib/gif.c (LZW, interlace, transparency, and the three
disposals across frames). A GIF keeps at most 1000 frames and 128 MB of them. The encoders:
apps/png.l (a palette of 1 to 8 bits a pixel up to 256 colours, else RGBA; a row that
repeats the one above filtered up, others sub), love/lib/jpeg.c (baseline), apps/gif.l (one
frame, the palette also sixel's).

## telnet, telnetd, httpd, nslookup, ping, ping6 and traceroute (apps/kore/net.l)

`telnet HOST [PORT]` is nc (apps/nc.l) with the telnet protocol's options answered
(RFC 854 and 855). It lets the server echo and suppress go-ahead, offers to suppress
go-ahead itself, and refuses every other option either way. On a terminal it follows the
server's echo. While the server echoes, the terminal is raw and each key is sent as typed
(character mode). Otherwise the terminal's own line editing holds a line until return (line
mode). A line ends CR LF on the wire, and `^]` closes the connection. When stdin is not a
terminal, its lines are sent, and its end half-closes the connection so the server's
answer can still arrive.

`telnetd [-FK] [-p PORT] [-b ADDR[:PORT]] [-l LOGIN] [-f ISSUE]` is busybox's: each client
gets LOGIN on a pty of its own, `/bin/login` unless `-l` names another program, and anything
else it names is said on stderr (whoever reaches the port runs it, unauthenticated). `-b`
takes a dotted quad to listen on one address, loopback's say, where `listen` answers every
address by default. The server offers to echo and suppress go-ahead and asks the client's
window size, which the pty follows as it changes; every other option is refused, and TERM is
xterm. A client's CR LF or CR NUL is a CR, as the pty's ICRNL expects. The program's end
closes the connection and the client's going hangs the program up. `/etc/issue.net`, or
`-f`'s file, is shown first. `-F` and `-K` are what it always does; `-i`, `-w` and `-S` are
refused by name.

`microcom [-X] [-s SPEED] [-t TIMEOUT] TTY` (apps/kore/proc.l) is busybox's serial terminal,
the other way onto a board: the line is opened read-write, never as the controlling terminal
and without waiting on its carrier, then set raw 8N1 with no flow control at `-s`'s speed or
its own. Bytes pass as they are both ways; ^X leaves unless `-X`, `-t` milliseconds of quiet
leave too, and the line's settings go back as they were. `-d` is refused by name.

`httpd [-fv] [-p [IP:]PORT] [-h DIR]` is kiosko under busybox's name and flags: the port
defaults to 80 and the directory to `.`, and `-v` logs each request. `-f` is accepted and
always in force, because it never runs in the background. A bare `PORT` (or `:PORT`)
listens on 127.0.0.1 only; `IP:PORT` names the address, and `0.0.0.0:PORT` or `*:PORT`
serves every one. Busybox's other flags (`-c -u -r -m -e -d -i`) are refused by name.

`nslookup [-type=T] [-port=N] HOST [SERVER]` asks a nameserver directly and prints what it
says, laid out as busybox's nslookup lays it. The server is SERVER (a dotted quad or a name)
or else the first in `/etc/resolv.conf` that answers; no hosts file and no search domains
are read. With no `-type` it asks A and AAAA, and a dotted quad asks its PTR. The types are
A, AAAA, CNAME, MX, NS, PTR, SOA and TXT. The query offers EDNS0's 1232 bytes, so a long
answer such as a TXT set arrives whole; one that still does not fit is said to be cut, as
there is no TCP retry. A name that does not exist exits 1. The protocol pieces live in
apps/dns.l (`dns-qedns`, `dns-raw`, `dns-records`), beside the resolver.

`ping [-46q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST` sends an ICMP echo every `-i`
seconds (1 by default, fractions allowed), `-c` times or until ^C, and prints each reply's
size, sequence, TTL and round trip, then the loss and min/avg/max, in busybox's format.
After the last echo it waits up to `-W` seconds (10) for the rest. It exits 0 when any
reply came back and 1 otherwise. It uses Linux's unprivileged ICMP echo socket, open to the
groups in `net.ipv4.ping_group_range`, or else a raw ICMP socket, which needs root; FreeBSD
and NetBSD have only the raw kind. Where both are refused it says so.

`traceroute [-46nI] [-f FIRST] [-m MAX] [-q N] [-w SECS] HOST` (and `traceroute6`) sends
ICMP echoes with the TTL rising from `-f` (1) to `-m` (30), `-q` (3) to each hop, and prints
busybox's lines: each hop's router, as its PTR name off the first nameserver unless `-n`, and
each probe's round trip or `*` after `-w` seconds (3). The target's reply ends it, and so does
an unreachable, marked `!N` `!H` `!P` or `!X`. Busybox's probes are UDP by default; these are
the ICMP ones its `-I` sends, the one kind Linux's unprivileged echo socket can send, and
that socket brings the routers' errors back on its error queue (`IP_RECVERR`). A raw socket
(root, and the BSDs) reads them as they come. NetBSD's raw socket sends every packet at TTL
255 whatever it is asked, so there traceroute sees only the target.

`ping6`, or `ping -6`, or `ping` given an address with a colon in it, does the same over
ICMPv6, and its TTL is the reply's hop limit. A name is looked up by `resolve6` in
apps/dns.l: `/etc/hosts`' v6 lines first, then AAAA from the nameservers. `-s` is at most
1452 here, one datagram on a 1500-byte link.

## ssh, sshd and scp (apps/ssh/)

One of everything, OpenSSH's first choices: curve25519-sha256 for the exchange, ssh-ed25519
keys, chacha20-poly1305@openssh.com both ways, public-key authentication. The client came first
(`ssh [-p port] [-i identity] [-l user] [-t|-T] [-o option=value] [user@]host [command]`);
the server is its other half. The host key is held to known_hosts as OpenSSH holds it, plain
and hashed names alike: a match goes on, a changed or revoked key stops, and an unknown host,
or one known only under another key type, is asked about on the terminal, where `yes` adds the
key and anything else, or no terminal, stops. `-o StrictHostKeyChecking=` takes `ask` (the
default), `accept-new` (an unknown host is added unasked, for scripts), `yes` (never ask:
unknown hosts are refused) and `no` (no check at all); `-o UserKnownHostsFile=` names the file.

`sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]` serves the user it runs
as and only that user: there is no setuid here, so a login naming anyone else is refused. It
listens on 22 by default, never detaches (`-D` and `-e` are taken for OpenSSH's sake) and logs
to stderr. The host key is `-h`'s, else /etc/ssh/ssh_host_ed25519_key when that user can read
it, else `~/.ssh/sshd_ed25519_key`, written on first use (0600, OpenSSH's format, a `.pub`
beside it). authorized_keys is read at each login, so an edit counts at once; a line with
options ahead of its key type (`command=`, `from=` ..) grants nothing, since none are honoured.
Each connection is a task, and it carries one session channel: the login shell, or a command
under it with `-c`, on a pty when the client asks for one (`window-change` follows it) and on
three pipes when not, so bytes pass clean and stderr stays apart. The exit status goes home.
Refused: rekeying (OpenSSH asks after 1 GB; the connection ends there), port forwarding, agent
forwarding, subsystems (so sftp, and OpenSSH 9's scp by default, which rides it), and passwords.

`scp [-pqrO] [-P port] [-i identity] [-o option=value] source .. target` copies with rcp's
protocol over an exec channel, the one OpenSSH's `scp -O` speaks: files, and with `-r` whole
trees, one side `[user@]host:path` and the other local. A file's mode always travels; `-p`
keeps its mtime too, which becomes its access time as well. The remote end is `scp -t`
receiving or `scp -f` sending, whatever `scp` the remote shell finds, OpenSSH's or kore's;
kore's answers both, so kore to kore, OpenSSH's `scp -O` to kore and kore to OpenSSH all
work. A received name with a slash, or `.` or `..`, is refused. Two remote hosts, or none,
are refused by name.

## ed and ex (apps/kore/ed.l)

One buffer and two dialects over it. The addresses are POSIX's in both: `N . $ 'x /re/
?re?` with `+ - ^` offsets (a bare number after an address adds too), joined by `,` and `;`,
either side of which may be missing -- `,` is `1,$`, `;` is `.,$`, `,N` is `1,N`, `N,` is
`N,N` -- and `%` is `1,$`. The regexes are re.l's BRE.

`ed [-s] [-p PROMPT] [FILE]` has POSIX's commands and GNU's few beside them: `a c d e E f
g G h H i j k l m n p P q Q r s t u v V w W wq z = !` and the bare newline, with the `p l n`
suffixes. An error prints `?`, and `H` turns the reason on beneath it. `s` reads `&` and
`\1`..`\9`, `%` alone for the last replacement, and a backslash-newline to split the line;
its flags are `g`, a count N (the Nth match on), and `p l n`, and a bare `s` repeats the last,
with `g` and `p` toggling and `r` taking the last search pattern. A `g` list runs on over
lines ending in a backslash and may carry `a i c` text; `u` takes a whole `g` back at once.
`!cmd` runs the shell, `%` in it is the file and a leading `!` the last command; `r !cmd`,
`e !cmd` and `w !cmd` read and write through one.

`ex [-s] [-R] [-v] [-c CMD | +CMD] [FILE]` reads the same buffer by word: `[range]
word[!] [args]`, any unambiguous head of the word (`d`, `del`, `delete`; `co` is copy and `c`
change), `|` between commands (`g`, `v` and `!` take the rest of the line), and a count after
the word taking that many lines from the range's last. Beyond ed's: named registers `a`-`z`
for `d`, `ya` and `pu` (an upper-case name appends), `> <` by `shiftwidth`, `&` and `~`, a
range filtered through `!cmd`, `j` joining at the blanks, `set` (`number list autoprint
ignorecase shiftwidth report window`), and `vi`, which hands the buffer to the vi engine
(apps/vi/vi.l's `vi-buffer`) and ends with it; `-v` starts there. Its messages are vim's
shapes (`"f" 5L, 31B`), and errors are words on stderr.

Standard input that is not a terminal is a script, and an error in one ends the edit with
status 1 -- POSIX's rule, and GNU ed's; vim's ex carries on. The buffer is records in chunks
of 64: an address walks the chunk counts and an edit rebuilds only the chunks it touches, so
`g` over 20,000 lines runs in a fraction of a second. Absent: `^C` handling (it ends the
editor, as it does every tool here), ex's file list (`next`, `args`), open mode, `s`'s `c`
flag, and ed's `-x` and `-r`.

## not built

Polish, as need arises: printf's `%a`, uniq -d/-u, cut -b, echo -e, seq over
gems, sed y/N and the hold space, join -o, od with several -t at once, date's spellings past
`@SECONDS`, the checksums' `-b`/`--tag` output modes and `-c`'s `--quiet`/`--status` (a `-c`
list written either way still READS here).
Left out of the coreutils batch deliberately: `fmt` `pr` `csplit` `ptx` `numfmt` (each its own
layout language, not another row).
shred draws its pattern order from its own random numbers, as GNU's does, so the two agree on
which passes are random and never on the order of the rest; watch has no `-d`, `-c` or `-p`;
hostid and dnsdomainname ask /etc/hosts and the host's own addresses, never DNS.
readelf reads no relocations, dynamic section, notes or dumps; dircolors spells LS_COLORS
that kore's own ls does not yet read; hexedit has no search.
Of xz, not yet: `-l`, writing `.lzma`, and the BCJ and delta filters (a stream using one is
refused by name). The encoder's parse is one fast greedy one, near `xz -1`'s ratio at any
level; a level picks only the dictionary. strip leaves a relocatable object's symbol table
alone, since its relocations name those symbols; `-g` works there.
Out of the /proc family, deliberately: `pmap` and `vmstat` (each its own layout), `dmesg`
(the ring buffer wants a syscall, not a file).
None block the distro; add them when a real script wants them. What the others carry that
kore does not is the census's to say.

## the census (kore against the other userlands)

Taken 2026-09-26; kore's column retaken and plan9port's added 2026-09-27. A row is a tool
NAME and a mark says the implementation answers to it — the same reach as the inventory,
nothing about flags (plan9port's `ls` or `grep` answers to the name in Plan 9's manner). Every
tool kore has is a row, and so is every tool at least two of the others share; a name only
one other carries is listed after the table instead, since those are mostly one system's own
(busybox's init and network daemons, GNU's toolchain driver names, plan9port's graphics and
file servers, util-linux's disk and login tools). `mc` is a name and not a tool shared:
kore's is a file browser, plan9port's lays its input in columns, which kore's `column` does.
Not counted in any column: one implementation's spelling of a general tool (kore's `lush`
`cook`, busybox's `ash` `linuxrc`, GNU's `bash` `rbash` `gawk` `gcc` `gcc-ar` `gcc-nm`
`gcc-ranlib` `g++` `ld.bfd` `ld.gold`) and a userland's name for itself (`coreutils`,
plan9port's `9`).

* **kore** — the `applets` tablet in kore.l, plus the love verbs that are unix tools: `cc`
  (mooncc), `mkdosfs`/`mkfs.vfat`, `fat`, `mc`, `pom`.
* **busybox** — `busybox --list`, 1.36.1 as Arch builds it.
* **toybox** — `toybox` bare, 0.8.14-57 (38ebde21) built from ~/src/toybox at defconfig: the
  pending tools (`sh`, `vi`, `awk`, `bc`, `make` ..) are off, as a release build has them.
* **GNU** — the GNU packages on the Arch box: coreutils 9.11, findutils, diffutils, grep, sed,
  gawk, tar, gzip, cpio, bc, make, bash, binutils, gcc (the driver names, not the target
  triples), inetutils, which, time, m4, patch, wget. coreutils' `kill` and `uptime` are
  counted though Arch builds them out in favour of procps. Not counted here: util-linux
  (its own column), procps, shadow and the rest of the Linux userland that is not GNU's, and
  GNU's toolchain-side packages (texinfo, gettext, groff, gdb, bison).
* **uutils** — uutils-coreutils 0.12.0, the `uu-*` names. Its findutils and diffutils are
  separate projects, not installed.
* **plan9port** — 20260826 as Arch packages it: the files in `$PLAN9/bin`
  (/usr/lib/plan9/bin), less the three `.rc` libraries its scripts source. The commands in
  its subdirectories (`venti/`, `fossil/`, `upas/`, `fs/`, `disk/`) are reached by those
  prefixed names and are not counted.
* **util-linux** — 2.42.4 as Arch packages it: the files in /usr/bin and /usr/sbin, setarch's
  arch names (`linux32` `linux64` `i386` `x86_64` `uname26`) among them.

Retaken with `busybox --list`, `toybox`, `ls /usr/bin/uu-*`, `ls $PLAN9/bin` and `pacman -Qql`
over the packages above; util-linux's column added 2026-09-27.

| | kore | busybox | toybox | GNU | uutils | plan9port | util-linux |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| names | 205 | 389 | 239 | 191 | 107 | 260 | 136 |
| shared with kore | | 170 | 142 | 135 | 101 | 49 | 12 |
| carried by no one else | 11 | 136 | 25 | 48 | 0 | 201 | 75 |

What at least three of the other six carry and kore does not: `blkdiscard`, `blkid`,
`blockdev`, `chrt`, `dmesg`, `eject`, `fallocate`, `flock`, `fmt`, `fsfreeze`, `hwclock`,
`ionice`, `linux32`, `logger`, `login`, `losetup`, `mkswap`, `nsenter`, `pivot_root`, `pr`,
`rfkill`, `rtcwake`, `su`, `swapoff`, `swapon`, `switch_root`, `taskset`, `uncompress`,
`unshare`.

| tool | kore | busybox | toybox | GNU | uutils | plan9port | util-linux |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `[` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `ar` | ✓ | ✓ |  | ✓ |  |  |  |
| `arch` | ✓ | ✓ | ✓ |  | ✓ |  |  |
| `as` | ✓ |  |  | ✓ |  |  |  |
| `ascii` | ✓ | ✓ | ✓ |  |  | ✓ |  |
| `awk` | ✓ | ✓ |  | ✓ |  | ✓ |  |
| `b2sum` | ✓ |  |  | ✓ | ✓ |  |  |
| `base32` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `base64` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `basename` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `basenc` | ✓ |  |  | ✓ | ✓ |  |  |
| `bc` | ✓ | ✓ |  | ✓ |  | ✓ |  |
| `blkdiscard` |  | ✓ | ✓ |  |  |  | ✓ |
| `blkid` |  | ✓ | ✓ |  |  |  | ✓ |
| `blockdev` |  | ✓ | ✓ |  |  |  | ✓ |
| `bunzip2` | ✓ | ✓ | ✓ |  |  | ✓ |  |
| `bzcat` | ✓ | ✓ | ✓ |  |  |  |  |
| `bzip2` | ✓ | ✓ |  |  |  | ✓ |  |
| `cal` | ✓ | ✓ | ✓ |  |  | ✓ | ✓ |
| `cat` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `cc` | ✓ |  |  | ✓ |  |  |  |
| `chattr` |  | ✓ | ✓ |  |  |  |  |
| `chgrp` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `chmod` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `chown` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `chroot` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `chrt` |  | ✓ | ✓ |  |  |  | ✓ |
| `chvt` |  | ✓ | ✓ |  |  |  |  |
| `cksum` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `clear` | ✓ | ✓ | ✓ |  |  |  |  |
| `cmp` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `col` |  |  |  |  |  | ✓ | ✓ |
| `column` | ✓ |  |  |  |  |  | ✓ |
| `comm` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `cp` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `cpio` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `crc32` | ✓ | ✓ | ✓ |  |  |  |  |
| `csplit` |  |  |  | ✓ | ✓ |  |  |
| `cut` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `date` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `dc` | ✓ | ✓ |  | ✓ |  | ✓ |  |
| `dd` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `deallocvt` |  | ✓ | ✓ |  |  |  |  |
| `df` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `diff` | ✓ | ✓ |  | ✓ |  | ✓ |  |
| `dir` | ✓ |  |  | ✓ | ✓ |  |  |
| `dircolors` | ✓ |  |  | ✓ | ✓ |  |  |
| `dirname` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `dmesg` |  | ✓ | ✓ |  |  |  | ✓ |
| `dnsdomainname` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `dos2unix` | ✓ | ✓ | ✓ |  |  |  |  |
| `du` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `echo` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `ed` | ✓ | ✓ |  |  |  | ✓ |  |
| `egrep` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `eject` |  | ✓ | ✓ |  |  |  | ✓ |
| `env` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `ex` | ✓ |  |  |  |  |  |  |
| `expand` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `expr` | ✓ | ✓ |  | ✓ | ✓ |  |  |
| `factor` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `fallocate` |  | ✓ | ✓ |  |  |  | ✓ |
| `false` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `fat` | ✓ |  |  |  |  |  |  |
| `fdisk` |  | ✓ |  |  |  |  | ✓ |
| `fgrep` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `file` |  |  | ✓ |  |  | ✓ |  |
| `find` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `findfs` |  | ✓ |  |  |  |  | ✓ |
| `flock` |  | ✓ | ✓ |  |  |  | ✓ |
| `fmt` |  |  | ✓ | ✓ | ✓ | ✓ |  |
| `fold` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `free` | ✓ | ✓ | ✓ |  |  |  |  |
| `freeramdisk` |  | ✓ | ✓ |  |  |  |  |
| `fsck` |  | ✓ |  |  |  |  | ✓ |
| `fsck.minix` |  | ✓ |  |  |  |  | ✓ |
| `fsfreeze` |  | ✓ | ✓ |  |  |  | ✓ |
| `fstrim` |  | ✓ |  |  |  |  | ✓ |
| `fsync` | ✓ | ✓ | ✓ |  |  |  |  |
| `ftpd` |  | ✓ |  | ✓ |  |  |  |
| `ftpget` |  | ✓ | ✓ |  |  |  |  |
| `ftpput` |  | ✓ | ✓ |  |  |  |  |
| `getopt` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `grep` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `groups` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `gunzip` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `gzip` | ✓ | ✓ |  | ✓ |  | ✓ |  |
| `halt` |  | ✓ | ✓ |  |  |  |  |
| `hd` | ✓ | ✓ | ✓ |  |  |  |  |
| `head` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `hexdump` | ✓ | ✓ |  |  |  |  | ✓ |
| `hexedit` | ✓ | ✓ | ✓ |  |  |  |  |
| `hostid` | ✓ | ✓ |  | ✓ | ✓ |  |  |
| `hostname` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `html2text` | ✓ |  |  |  |  |  |  |
| `httpd` | ✓ | ✓ | ✓ |  |  |  |  |
| `hwclock` |  | ✓ | ✓ |  |  |  | ✓ |
| `i2cdetect` |  | ✓ | ✓ |  |  |  |  |
| `i2cdump` |  | ✓ | ✓ |  |  |  |  |
| `i2cget` |  | ✓ | ✓ |  |  |  |  |
| `i2cset` |  | ✓ | ✓ |  |  |  |  |
| `i2ctransfer` |  | ✓ | ✓ |  |  |  |  |
| `iconv` |  |  | ✓ |  |  | ✓ |  |
| `id` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `ifconfig` |  | ✓ | ✓ |  |  |  |  |
| `inotifyd` |  | ✓ | ✓ |  |  |  |  |
| `insmod` |  | ✓ | ✓ |  |  |  |  |
| `install` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `ionice` |  | ✓ | ✓ |  |  |  | ✓ |
| `ipcrm` |  | ✓ |  |  |  |  | ✓ |
| `ipcs` |  | ✓ |  |  |  |  | ✓ |
| `join` | ✓ |  |  | ✓ | ✓ | ✓ |  |
| `kill` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `killall` | ✓ | ✓ | ✓ |  |  |  |  |
| `killall5` |  | ✓ | ✓ |  |  |  |  |
| `ld` | ✓ |  |  | ✓ |  |  |  |
| `less` | ✓ | ✓ |  |  |  |  |  |
| `lift` | ✓ |  |  |  |  |  |  |
| `link` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `linux32` |  | ✓ | ✓ |  |  |  | ✓ |
| `linux64` |  | ✓ |  |  |  |  | ✓ |
| `ln` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `logger` |  | ✓ | ✓ |  |  |  | ✓ |
| `login` |  | ✓ | ✓ |  |  |  | ✓ |
| `logname` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `look` |  |  |  |  |  | ✓ | ✓ |
| `losetup` |  | ✓ | ✓ |  |  |  | ✓ |
| `ls` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `lsattr` |  | ✓ | ✓ |  |  |  |  |
| `lsmod` |  | ✓ | ✓ |  |  |  |  |
| `lspci` |  | ✓ | ✓ |  |  |  |  |
| `lsusb` |  | ✓ | ✓ |  |  |  |  |
| `lzcat` | ✓ | ✓ |  |  |  |  |  |
| `mac2unix` | ✓ |  |  |  |  |  |  |
| `make` | ✓ |  |  | ✓ |  |  |  |
| `makedevs` |  | ✓ | ✓ |  |  |  |  |
| `man` | ✓ | ✓ |  |  |  | ✓ |  |
| `markdown` | ✓ |  |  |  |  |  |  |
| `mc` | ✓ |  |  |  |  | ✓ |  |
| `mcookie` |  |  | ✓ |  |  |  | ✓ |
| `md5sum` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `mesg` |  | ✓ |  |  |  |  | ✓ |
| `microcom` | ✓ | ✓ | ✓ |  |  |  |  |
| `mkdir` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `mkdosfs` | ✓ | ✓ |  |  |  |  |  |
| `mkfifo` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `mkfs.minix` |  | ✓ |  |  |  |  | ✓ |
| `mkfs.vfat` | ✓ | ✓ |  |  |  |  |  |
| `mknod` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `mkpasswd` |  | ✓ | ✓ |  |  |  |  |
| `mkswap` |  | ✓ | ✓ |  |  |  | ✓ |
| `mktemp` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `modinfo` |  | ✓ | ✓ |  |  |  |  |
| `more` | ✓ | ✓ |  |  | ✓ |  | ✓ |
| `mount` | ✓ | ✓ | ✓ |  |  | ✓ | ✓ |
| `mountpoint` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `mv` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `nbd-client` |  | ✓ | ✓ |  |  |  |  |
| `nc` | ✓ | ✓ | ✓ |  |  |  |  |
| `netstat` |  | ✓ | ✓ |  |  |  |  |
| `nice` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `nl` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `nm` | ✓ |  |  | ✓ |  |  |  |
| `nohup` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `nologin` |  |  | ✓ |  |  |  | ✓ |
| `nproc` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `nsenter` |  | ✓ | ✓ |  |  |  | ✓ |
| `nslookup` | ✓ | ✓ |  |  |  |  |  |
| `numfmt` |  |  |  | ✓ | ✓ |  |  |
| `objcopy` | ✓ |  |  | ✓ |  |  |  |
| `od` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `openvt` |  | ✓ | ✓ |  |  |  |  |
| `partprobe` |  | ✓ | ✓ |  |  |  |  |
| `passwd` |  | ✓ |  |  |  | ✓ |  |
| `paste` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `patch` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `pathchk` | ✓ |  |  | ✓ | ✓ |  |  |
| `pgrep` | ✓ | ✓ | ✓ |  |  |  |  |
| `pidof` | ✓ | ✓ | ✓ |  |  |  |  |
| `ping` | ✓ | ✓ | ✓ |  |  |  |  |
| `ping6` | ✓ | ✓ | ✓ |  |  |  |  |
| `pinky` | ✓ |  |  | ✓ | ✓ |  |  |
| `pivot_root` |  | ✓ | ✓ |  |  |  | ✓ |
| `pkill` | ✓ | ✓ | ✓ |  |  |  |  |
| `pmap` |  | ✓ | ✓ |  |  |  |  |
| `pom` | ✓ |  |  |  |  |  |  |
| `poweroff` |  | ✓ | ✓ |  |  |  |  |
| `pr` |  |  |  | ✓ | ✓ | ✓ |  |
| `printenv` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `printf` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `prlimit` |  |  | ✓ |  |  |  | ✓ |
| `ps` | ✓ | ✓ | ✓ |  |  | ✓ |  |
| `ptx` |  |  |  | ✓ | ✓ |  |  |
| `pwd` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `pwdx` | ✓ | ✓ | ✓ |  |  |  |  |
| `ranlib` | ✓ |  |  | ✓ |  |  |  |
| `readahead` |  | ✓ | ✓ |  |  |  |  |
| `readelf` | ✓ |  | ✓ | ✓ |  |  |  |
| `readlink` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `readprofile` |  | ✓ |  |  |  |  | ✓ |
| `realpath` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `reboot` |  | ✓ | ✓ |  |  |  |  |
| `renice` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `reset` | ✓ | ✓ | ✓ |  |  |  |  |
| `rev` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `rfkill` |  | ✓ | ✓ |  |  |  | ✓ |
| `rm` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `rmdir` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `rmmod` |  | ✓ | ✓ |  |  |  |  |
| `rtcwake` |  | ✓ | ✓ |  |  |  | ✓ |
| `scp` | ✓ |  |  |  |  |  |  |
| `script` |  | ✓ |  |  |  |  | ✓ |
| `scriptreplay` |  | ✓ |  |  |  |  | ✓ |
| `sed` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `seq` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `setarch` |  | ✓ |  |  |  |  | ✓ |
| `setfattr` |  | ✓ | ✓ |  |  |  |  |
| `setpriv` |  | ✓ |  |  |  |  | ✓ |
| `setsid` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `sh` | ✓ | ✓ |  | ✓ |  |  |  |
| `sha1sum` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `sha224sum` | ✓ |  | ✓ | ✓ | ✓ |  |  |
| `sha256sum` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `sha384sum` | ✓ |  | ✓ | ✓ | ✓ |  |  |
| `sha3sum` | ✓ | ✓ | ✓ |  |  |  |  |
| `sha512sum` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `shred` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `shuf` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `size` | ✓ |  |  | ✓ |  |  |  |
| `sleep` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `sort` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `split` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `ssh` | ✓ |  |  |  |  |  |  |
| `sshd` | ✓ |  |  |  |  |  |  |
| `stat` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `stdbuf` |  |  |  | ✓ | ✓ |  |  |
| `strings` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `strip` | ✓ |  |  | ✓ |  |  |  |
| `stty` | ✓ | ✓ |  | ✓ | ✓ |  |  |
| `su` |  | ✓ | ✓ |  |  |  | ✓ |
| `sulogin` |  | ✓ |  |  |  |  | ✓ |
| `sum` | ✓ | ✓ |  | ✓ | ✓ | ✓ |  |
| `swapoff` |  | ✓ | ✓ |  |  |  | ✓ |
| `swapon` |  | ✓ | ✓ |  |  |  | ✓ |
| `switch_root` |  | ✓ | ✓ |  |  |  | ✓ |
| `sync` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `sysctl` |  | ✓ | ✓ |  |  |  |  |
| `tac` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `tail` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `tar` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `taskset` |  | ✓ | ✓ |  |  |  | ✓ |
| `tee` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `telnet` | ✓ | ✓ |  | ✓ |  |  |  |
| `telnetd` | ✓ | ✓ |  | ✓ |  |  |  |
| `test` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `time` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |
| `timeout` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `top` | ✓ | ✓ | ✓ |  |  |  |  |
| `touch` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `tr` | ✓ | ✓ |  | ✓ | ✓ | ✓ |  |
| `traceroute` | ✓ | ✓ |  |  |  |  |  |
| `traceroute6` | ✓ | ✓ |  |  |  |  |  |
| `true` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `truncate` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `ts` | ✓ | ✓ | ✓ |  |  |  |  |
| `tsort` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `tty` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `tunctl` |  | ✓ | ✓ |  |  |  |  |
| `uclampset` |  |  | ✓ |  |  |  | ✓ |
| `umount` | ✓ | ✓ | ✓ |  |  |  | ✓ |
| `uname` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `uncompress` |  | ✓ |  | ✓ |  | ✓ |  |
| `unexpand` | ✓ | ✓ |  | ✓ | ✓ |  |  |
| `unicode` |  |  | ✓ |  |  | ✓ |  |
| `uniq` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `unix2dos` | ✓ | ✓ | ✓ |  |  |  |  |
| `unlink` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `unlzma` | ✓ | ✓ |  |  |  |  |  |
| `unshare` |  | ✓ | ✓ |  |  |  | ✓ |
| `unxz` | ✓ | ✓ |  |  |  |  |  |
| `unzip` |  | ✓ |  |  |  | ✓ |  |
| `uptime` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `users` | ✓ |  |  | ✓ | ✓ |  |  |
| `usleep` | ✓ | ✓ | ✓ |  |  |  |  |
| `uudecode` | ✓ | ✓ | ✓ |  |  |  |  |
| `uuencode` | ✓ | ✓ | ✓ |  |  |  |  |
| `uuidgen` |  |  | ✓ |  |  |  | ✓ |
| `vconfig` |  | ✓ | ✓ |  |  |  |  |
| `vdir` | ✓ |  |  | ✓ | ✓ |  |  |
| `vi` | ✓ | ✓ |  |  |  |  |  |
| `watch` | ✓ | ✓ | ✓ |  |  |  |  |
| `watchdog` |  | ✓ | ✓ |  |  |  |  |
| `wc` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `wget` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `which` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `who` | ✓ |  | ✓ | ✓ | ✓ |  |  |
| `whoami` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `www` | ✓ |  |  |  |  |  |  |
| `xargs` | ✓ | ✓ | ✓ | ✓ |  |  |  |
| `xxd` | ✓ | ✓ | ✓ |  |  |  |  |
| `xz` | ✓ | ✓ |  |  |  |  |  |
| `xzcat` | ✓ | ✓ |  |  |  |  |  |
| `yes` | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `zcat` | ✓ | ✓ | ✓ | ✓ |  | ✓ |  |

The names only one carries:

* **busybox alone** (136): `[[` `acpid` `addgroup` `adduser` `adjtimex` `arp` `arping`
  `bbconfig` `beep` `bootchartd` `brctl` `chat` `chpasswd` `chpst` `crond` `crontab` `cryptpw`
  `cttyhack` `delgroup` `deluser` `depmod` `dhcprelay` `dnsd` `dumpkmap` `dumpleases` `envdir`
  `envuidgid` `ether-wake` `fakeidentd` `fatattr` `fbset` `fbsplash` `fdflush` `fdformat`
  `fgconsole` `fuser` `getty` `hdparm` `ifdown` `ifenslave` `ifplugd` `ifup` `inetd` `init`
  `iostat` `ip` `ipaddr` `ipcalc` `iplink` `ipneigh` `iproute` `iprule` `iptunnel` `kbd_mode`
  `klogd` `loadfont` `loadkmap` `logread` `lpd` `lpq` `lpr` `lsof` `lsscsi` `lzma` `lzopcat`
  `makemime` `mdev` `mke2fs` `mkfs.ext2` `modprobe` `mpstat` `mt` `nameif` `nmeter` `ntpd`
  `pipe_progress` `popmaildir` `powertop` `pscan` `pstree` `raidautorun` `rdate` `rdev`
  `reformime` `resize` `resume` `route` `rpm2cpio` `run-init` `run-parts` `runsv` `runsvdir`
  `rx` `seedrng` `sendmail` `setconsole` `setfont` `setkeycodes` `setlogcons` `setserial`
  `setuidgid` `showkey` `slattach` `smemcap` `softlimit` `ssl_client` `start-stop-daemon` `sv`
  `svc` `svlogd` `svok` `syslogd` `tc` `tcpsvd` `tftp` `tftpd` `tree` `ttysize` `tune2fs`
  `ubiattach` `ubidetach` `ubimkvol` `ubirename` `ubirmvol` `ubirsvol` `ubiupdatevol` `udhcpc`
  `udhcpc6` `udhcpd` `udpsvd` `uevent` `unlzop` `vlock` `volname` `whois` `zcip`
* **toybox alone** (25): `acpi` `count` `devmem` `fstype` `getconf` `gpiodetect` `gpiofind`
  `gpioget` `gpioinfo` `gpioset` `help` `host` `iorenice` `iotop` `memeater` `mix` `nbd-server`
  `netcat` `oneit` `pwgen` `sntp` `ucsicontrol` `ulimit` `vmstat` `w`
* **GNU alone** (48): `addr2line` `bashbug` `c++` `c++filt` `c89` `c99` `cpp` `diff3` `dwp`
  `elfedit` `ftp` `gawkbug` `gcov` `gcov-dump` `gcov-tool` `gp-archive` `gp-collect-app`
  `gp-display-html` `gp-display-src` `gp-display-text` `gprof` `gprofng` `gprofng-archive`
  `gprofng-collect-app` `gprofng-display-html` `gprofng-display-src` `gprofng-display-text`
  `gprofng-gmon` `gzexe` `m4` `objdump` `rcp` `rlogin` `rlogind` `rsh` `rshd` `sdiff` `talk`
  `talkd` `zcmp` `zdiff` `zegrep` `zfgrep` `zforce` `zgrep` `zless` `zmore` `znew`
* **uutils alone** (0): none
* **plan9port alone** (201): `"` `""` `9660srv` `9ar` `9c` `9fs` `9import` `9l` `9p` `9pfuse`
  `9pserve` `9term` `B` `E` `Getdir` `Mail` `Netfiles` `acid` `acidtypes` `acme` `acmeevent`
  `adict` `aescbc` `asn12dsa` `asn12rsa` `astro` `auxclog` `auxstats` `awd` `bmp` `bundle`
  `calendar` `cb` `cleanname` `clock` `cmapcube` `colors` `compress` `core` `crop` `db`
  `delatex` `deroff` `devdraw` `dial` `dict` `disknfs` `dns` `dnsdebug` `dnsquery` `dnstcp`
  `doctype` `dsa2pub` `dsa2ssh` `dsagen` `dsasign` `dump9660` `eqn` `factotum` `fontsrv`
  `fortune` `freq` `fsize` `g` `getflags` `gif` `grap` `graph` `gview` `hget` `hist` `hoc`
  `htmlfmt` `htmlroff` `ico` `idiff` `img` `import` `ipso` `jpg` `label` `lc` `lex` `listen1`
  `lookman` `macedit` `mapd` `mk` `mk9660` `mklatinkbd` `mntgen` `mtime` `namespace`
  `ndbipquery` `ndbmkdb` `ndbmkhash` `ndbmkhosts` `ndbquery` `netfileget` `netfileput`
  `netfilestat` `netkey` `news` `nobs` `nroff` `osxvers` `p` `page` `paint` `pbd` `pemdecode`
  `pemencode` `pic` `plot` `plumb` `plumber` `png` `ppm` `primes` `proof` `psdownload`
  `psfonts` `psu` `psv` `quote1` `quote2` `ramfs` `rc` `read` `readcons` `resample` `rio`
  `rsa2csr` `rsa2pub` `rsa2ssh` `rsa2x509` `rsafill` `rsagen` `sam` `samsave` `samterm` `scat`
  `secstore` `secstored` `secuser` `sftpcache` `sig` `slay` `soelim` `spell` `sprog` `src`
  `srv` `ssam` `ssh-agent` `stack` `start` `stats` `statusbar` `stop` `svgpic` `tbl` `tcolors`
  `tcs` `togif` `toico` `topng` `toppm` `tpic` `tr2post` `tref` `troff` `troff2html`
  `troff2png` `tweak` `u` `units` `unmount` `unutf` `unvac` `usage` `vac` `vacfs` `vbackup`
  `vcat` `vmount` `vmount0` `vnfs` `vwhois` `web` `win` `wintext` `winwatch` `wmail` `xd`
  `xshove` `yacc` `yesterday` `yuv` `zerotrunc` `zip`
* **util-linux alone** (75): `addpart` `agetty` `bits` `blkpr` `blkzone` `cfdisk` `chcpu`
  `chfn` `chmem` `choom` `chsh` `colcrt` `colrm` `copyfilerange` `coresched` `ctrlaltdel`
  `delpart` `enosys` `exch` `fadvise` `fincore` `findmnt` `fsck.cramfs` `getino` `hardlink`
  `i386` `ipcmk` `irqtop` `isosize` `last` `lastb` `lastlog2` `ldattach` `lsblk` `lsclocks`
  `lscpu` `lsfd` `lsipc` `lsirq` `lslocks` `lslogins` `lsmem` `lsns` `mkfs` `mkfs.bfs`
  `mkfs.cramfs` `namei` `newgrp` `partx` `pg` `pipesz` `rename` `resizepart` `runuser`
  `scriptlive` `setpgid` `setterm` `sfdisk` `swaplabel` `tunelp` `ul` `uname26` `utmpdump`
  `uuidd` `uuidparse` `vigr` `vipw` `waitpid` `wall` `wdctl` `whereis` `wipefs` `write`
  `x86_64` `zramctl`
