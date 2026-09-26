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
compares to busybox, GNU, uutils and the two BSDs, name by name, is the census at the foot.

## the shape

ONE roster — `$(korefiles)` in the Makefile: kore_head (kore's own toolboxes, apps/libra/lint.l,
apps/vi/, apps/tui.l, apps/dns.l, apps/ain.l, the lush files, apps/cook.l), the holo linker
files, kore_arc (gz.l tar.l cpio.l) and kore_net (the tls stack and wget.l). The
crew rides IN the default binary's own image, so the
build tree's spelling is `love kore TOOL` and the installed `bin/kore` is a four-line sh
shim — re-evaling the cat per spawn costs ~1.3s, so only the distro, which has no image
to ship, still runs it as a `#!/bin/love` script.
`apps/kore/kore.l` loads LAST and dispatches off the program seat of `cmdline`: `kore TOOL
ARGS..`, or symlink a tool's name to kore and argv[0] picks it (how the distro shadows at
will). The registry is a tablet, so tool names never collide with the globals they call (the
`mkdir` applet CALLS the `mkdir` nif; different namespaces).

The file discipline, two shapes:

* **a tool with a seat** (apps/ain.l, apps/cook.l): define-only, leaking
  one `<tool>-main`; a body-having tail fires it iff the file's own basename
  sits in the program seat — so the same file is a standalone tool AND a quiet
  cat member.
* **a toolbox** (core.l, fs.l): many mains, NO seat — kore is its door.

`--help` and `--version` are answered at that door, not in the tools: `koredoor` in
kore.l wraps every applet on both dispatch lanes (the verb registry and the symlink), so
one synopsis table — `korehelp` — is where a tool's shape is written down, and the two
lanes cannot drift. The door itself is cli's, `udoor` in post.l, and the crew's own verbs
(mc, lupa, pom, tower, story, design, slop, ink, libra, sb, tar, fat, doom) stand at the same one; what
kore keeps is the policy below. The walk reads only the leading flag words and stops at
the first operand and at `--`. It is NOT getopt: a value word that looks like a flag is walked
over, so `grep -e --help f` answers the help rather than searching for `--help` — glue
the value (`grep -e--help f`) to mean the pattern. `-h` comes too, except where the letter
is the tool's own or POSIX and GNU spell it otherwise (`korenoh`: grep du df ls sort touch
chown ln free); `-v` never does — GNU gives --version no short spelling, and the letter is
the tool's wherever it wants one. echo, test and `[` read no options at all and are not at
the door; cook and lush answer both flags themselves, each with more to say than a synopsis.

## the inventory (127 tools, 132 names)

The `applets` tablet in kore.l; the aliases are nc/ain, make/cook, sh/lush, ls/dir and
less/more. love's own verbs carry the rest of the userland the census counts: `cc` (mooncc,
doc/misc/moon.md), `mkdosfs`/`mkfs.vfat` and `fat`, `mc`, `pom`.

| where | tools |
| --- | --- |
| kore.l (thin mains) | diff (diff-main; the patience/myers engines are diff.l), as (elf64 over the holo book), ar (GNU-shape archives + the ranlib index over ld-read, byte-identical smoke), ld (holo's static linker: -pie/-t/-Ttext, byte-identical to mooncc's own link), objcopy (a linked ELF flattened to `-O binary` or `-O ihex`, byte-identical to llvm/gnu objcopy on both), nm |
| apps/ain.l | nc / ain |
| apps/cook.l | make / cook |
| core.l, the line tools | cat tac shuf echo head tail wc sort uniq tee |
| core.l, the field tools | cut tr nl rev |
| core.l, the column tools | fold expand unexpand (all three count COLUMNS, so a tab steps to the next stop) |
| core.l, the line endings | dos2unix unix2dos mac2unix (in place by default; a binary file is refused, the mode is kept) |
| core.l, the encodings | base64 base32 (RFC 4648; `-d` reads it back, `-w` says the wrap) |
| core.l, the two little computations | tsort factor |
| core.l, the record tools | paste comm join split od |
| sum.l, the checksums | cksum md5sum sha256sum (`-c` reads a list back) |
| core.l, the trivia | seq yes true false basename dirname test [ uname arch nproc printf |
| core.l, the byte tools | dd xxd strings |
| fs.l, the fs tools | ls/dir cp mv rm mkdir rmdir ln touch lift pwd chmod install readlink cmp |
| fs.l, the paths and the two bare calls | realpath link unlink |
| fs.l, what they report | stat du df chown mktemp |
| expr.l, the little language | expr (arithmetic, the six comparisons, \| and &, and `:` over the BRE engine) |
| patch.l, the diff read back | patch (unified only; -pN -R -i -o --dry-run, offsets, rejects) |
| re.l, the matcher | grep (-nvclqhaixwFEo, -e stacking, -m) over the lawed regex engine, BRE or ERE |
| sed.l, the editor | sed (-n -E -i -e; s///gp, d, p, q; number/$/regex/range addresses) |
| awk.l, the language | awk (patterns and actions, BEGIN/END, arrays, user functions) |
| find.l, the walk | find (-name -path -type -print -prune -exec; ( ) ! -a -o; the depths) |
| proc.l, the processes and the world | env printenv sleep kill xargs time date id whoami groups |
| proc.l, the /proc family | ps free uptime pidof pgrep pkill killall pwdx |
| proc.l, the one-liners | cal hostname tty clear which timeout |
| top.l | top (the process table, repainted; `-b` batch) |
| proc.l, the privileged three | chroot (the root moved, then exec), mount (bare = /proc/self/mounts; `-t TYPE`, and the FLAG half of `-o` -- `size=`-style filesystem text is refused by name, not dropped), umount |
| fs.l, what fills a /dev | sync mkfifo mknod (`p b c u`, `-m MODE`, linux's wide device encoding) |
| apps/vi/ | vi |
| less.l, the pager | less / more |
| bc.l, the calculator | bc (-l, -q) |
| wget.l, over the tls stack | wget |
| apps/gz.l, apps/tar.l, apps/cpio.l | gzip gunzip zcat, tar, cpio |
| man.l, the pages | man (a page found, decompressed, read as roff and laid out for a terminal) |
| lens.l, the doors onto lapiz | html2text (the lens entered from the other surface), markdown (the lens run the way papel runs it) |
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
* **the nif lane.** fs effects ride inle/posix.c (app-glob LvNif, no core edit) and its
  `posix_` conventions: an effect op answers () ok | an errno nom | 'badarg misuse; a
  value op answers the value | () absence | a nom. inle/posix.c holds rename symlink readlink chmod chown utime
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

One nif of their own — `rusage` (inle/posix.c: `(rusage who)` -> the user and sys microseconds
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

`find [PATH..] [EXPR]`, PATH defaulting to `.`. Primaries `-name` `-path` (fnmatch, via lush's
`sh-match`) `-type f|d|l` `-print` `-prune` `-exec CMD.. ;` `-true` `-false`, the global
`-maxdepth`/`-mindepth`, and the operators `( )` `!`/`-not` `-a`/`-and` (implicit between two
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

`cksum`, `md5sum`, `sha256sum` — the file whole, its bytes digested, one line said. The two
faces are GNU's: cksum's `CRC BYTES NAME` (and no name at all reading stdin), the digest pair's
`DIGEST  NAME` with the two spaces that mean text mode. `-c` reads such a list back and says
`NAME: OK` / `NAME: FAILED` per line, leaving with 1 if any did not match; the gate holds both
directions, GNU reading ours and ours reading GNU's.

The digests themselves are **inle/hash.c** (`sha256`, `md5`, `cksum` — the last being POSIX's
own crc, a different polynomial from `crc32`'s and with the byte count folded in, which is why
an empty file is `4294967295 0`). There is no love statement of any of the three, so an image
that carries no host nif — the kernel's, which compiles no `inle/*.c` — answers 2 and names the
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
`-c` does neither), `du`, `df`, `chown`, `mktemp`. They read the **stat tail**: inle/posix.c's `stat`
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
* **`uptime` has no `N users` field** and will not get one: that count comes out of
  utmp, which this tree does not keep, and a fabricated 0 is worse than an absent field.
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

None of this is law 1 — that says `htread` reads what `htshow` writes, and reading a page
*nobody* wrote with `htshow` is a different promise. It is stated in `test/host/lapiz.l` instead.

## markdown (apps/kore/lens.l)

`markdown [-t html|roff|text] [-w COLS] [FILE..]` — the same lens, driven the direction papel
drives it. `-t html` (the default) is `md->ht`, `-t roff` is `md->rf`, `-t text` is `md->tty`
at a width. The roff lane is the build's own page path a command away: `markdown -t roff
doc/love.md` writes what `doc/love.1` is made of, `.TH` and all, because the `.TH` comes from
the document's front matter and lapiz reads front matter as the meta block.

* **The html is a FRAGMENT**, which is what `markdown(1)` has always meant: the blocks, no
  doctype and no head. papel owns the template that wraps one into a page, and a second
  template here would be a second thing to keep true.
* `-w` and the terminal attributes matter to `-t text` only; html and roff carry neither.
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

## not built

Polish, as need arises: uniq -d/-u, cut -b, tr -ds (the -s is dropped), echo -e, seq over
gems, sed y/N and the hold space, join -o, od with several -t at once, date's spellings past
`@SECONDS`, the checksums' `-b`/`--tag` output modes and `-c`'s `--quiet`/`--status` (a `-c`
list written either way still READS here).
Left out of the coreutils batch deliberately: `fmt` `pr` `csplit` `ptx` `numfmt` (each its own
layout language, not another row), `sha1sum` and the sha512 family (inle/hash.c carries
sha256, md5 and cksum alone), and `who`/`users`/`logname` (no utmp here, and there will not
be one).
Out of the /proc family, deliberately: `pmap` and `vmstat` (each its own layout), `dmesg`
(the ring buffer wants a syscall, not a file).
None block the distro; add them when a real script wants them. What the others carry that
kore does not is the census's to say.

## the census (kore against the other userlands)

Taken 2026-09-26. A row is a tool NAME and a mark says the implementation answers to it —
the same reach as the inventory, nothing about flags. Every tool kore has is a row, and so is
every tool at least two of the others share; a name only one other carries is listed after
the table instead, since those are mostly one system's own administration (a BSD's sbin,
busybox's init and network daemons).

* **kore** — the `applets` tablet in kore.l, plus the love verbs that are unix tools: `cc`
  (mooncc), `mkdosfs`/`mkfs.vfat`, `fat`, `mc`, `pom`.
* **busybox** — `busybox --list`, 1.36.1 as Arch builds it.
* **GNU** — the GNU packages on the Arch box: coreutils 9.11, findutils, diffutils, grep, sed,
  gawk, tar, gzip, cpio, bc, make, bash, binutils, gcc (the driver names, not the target
  triples), inetutils, which, time, m4, patch, wget. coreutils' `kill` and `uptime` are
  counted though Arch builds them out in favour of procps. Not counted: util-linux, procps,
  shadow and the rest of the Linux userland that is not GNU's, and GNU's toolchain-side
  packages (texinfo, gettext, groff, gdb, bison).
* **uutils** — uutils-coreutils 0.12.0, the `uu-*` names. Its findutils and diffutils are
  separate projects, not installed.
* **NetBSD** 10.1 (amd64, the nbsd-x64 box) and **FreeBSD** 14.4 (arm64, fbsd-arm64) — the
  base system's /bin /sbin /usr/bin /usr/sbin, nothing from pkgsrc or ports. NetBSD's
  /usr/games is not taken; FreeBSD keeps its few games in /usr/bin, which is why `pom` marks
  there. A machine-specific tool can differ between a BSD's amd64 and arm64 base.

Retaken with `busybox --list`, `ls /usr/bin/uu-*`, `pacman -Qql` over the packages above, and
`ls /bin /sbin /usr/bin /usr/sbin` on the two boxes (`~/bin/osbox-env`).

| | kore | busybox | GNU | uutils | NetBSD | FreeBSD |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| names | 138 | 392 | 201 | 108 | 1025 | 956 |
| shared with kore | | 120 | 104 | 80 | 110 | 115 |
| carried by no one else | 9 | 181 | 27 | 1 | 505 | 433 |

What at least four of the other five carry and kore does not: `chgrp` `csplit` `dc` `egrep`
`fgrep` `fmt` `logname` `nice` `nohup` `pathchk` `pr` `sha1sum` `sha512sum` `stty` `sum`
`telnet` `truncate` `uncompress` `users` `who`.

| tool | kore | busybox | GNU | uutils | NetBSD | FreeBSD |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| `[` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ac` |  |  |  |  | ✓ | ✓ |
| `accton` |  |  |  |  | ✓ | ✓ |
| `acpidump` |  |  |  |  | ✓ | ✓ |
| `addr2line` |  |  | ✓ |  | ✓ | ✓ |
| `adduser` |  | ✓ |  |  |  | ✓ |
| `ain` | ✓ |  |  |  |  |  |
| `apply` |  |  |  |  | ✓ | ✓ |
| `apropos` |  |  |  |  | ✓ | ✓ |
| `ar` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `arch` | ✓ | ✓ |  | ✓ |  |  |
| `arp` |  | ✓ |  |  | ✓ | ✓ |
| `as` | ✓ |  | ✓ |  | ✓ |  |
| `asa` |  |  |  |  | ✓ | ✓ |
| `at` |  |  |  |  | ✓ | ✓ |
| `atq` |  |  |  |  | ✓ | ✓ |
| `atrm` |  |  |  |  | ✓ | ✓ |
| `authpf` |  |  |  |  | ✓ | ✓ |
| `automount` |  |  |  |  | ✓ | ✓ |
| `automountd` |  |  |  |  | ✓ | ✓ |
| `autounmountd` |  |  |  |  | ✓ | ✓ |
| `awk` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `b2sum` |  |  | ✓ | ✓ |  |  |
| `banner` |  |  |  |  | ✓ | ✓ |
| `base32` | ✓ | ✓ | ✓ | ✓ |  |  |
| `base64` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `basename` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `basenc` |  |  | ✓ | ✓ |  |  |
| `batch` |  |  |  |  | ✓ | ✓ |
| `bc` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `beep` |  | ✓ |  |  |  | ✓ |
| `biff` |  |  |  |  | ✓ | ✓ |
| `blkdiscard` |  | ✓ |  |  | ✓ |  |
| `bootpef` |  |  |  |  | ✓ | ✓ |
| `bootptest` |  |  |  |  | ✓ | ✓ |
| `btpand` |  |  |  |  | ✓ | ✓ |
| `bunzip2` |  | ✓ |  |  | ✓ | ✓ |
| `bzcat` |  | ✓ |  |  | ✓ | ✓ |
| `bzip2` |  | ✓ |  |  | ✓ | ✓ |
| `bzip2recover` |  |  |  |  | ✓ | ✓ |
| `c++` |  |  | ✓ |  | ✓ | ✓ |
| `c++filt` |  |  | ✓ |  | ✓ | ✓ |
| `c89` |  |  | ✓ |  | ✓ | ✓ |
| `c99` |  |  | ✓ |  | ✓ | ✓ |
| `cal` | ✓ | ✓ |  |  | ✓ | ✓ |
| `calendar` |  |  |  |  | ✓ | ✓ |
| `cap_mkdb` |  |  |  |  | ✓ | ✓ |
| `cat` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `cc` | ✓ |  | ✓ |  | ✓ | ✓ |
| `ccdconfig` |  |  |  |  | ✓ | ✓ |
| `certctl` |  |  |  |  | ✓ | ✓ |
| `chat` |  | ✓ |  |  | ✓ | ✓ |
| `chflags` |  |  |  |  | ✓ | ✓ |
| `chfn` |  |  |  |  | ✓ | ✓ |
| `chgrp` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `chio` |  |  |  |  | ✓ | ✓ |
| `chmod` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `chown` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `chpass` |  |  |  |  | ✓ | ✓ |
| `chroot` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `chsh` |  |  |  |  | ✓ | ✓ |
| `cksum` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `clear` | ✓ | ✓ |  |  | ✓ | ✓ |
| `clri` |  |  |  |  | ✓ | ✓ |
| `cmp` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `col` |  |  |  |  | ✓ | ✓ |
| `colrm` |  |  |  |  | ✓ | ✓ |
| `column` |  |  |  |  | ✓ | ✓ |
| `comm` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `compress` |  |  |  |  | ✓ | ✓ |
| `config` |  |  |  |  | ✓ | ✓ |
| `cook` | ✓ |  |  |  |  |  |
| `cp` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `cpio` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `cpp` |  |  | ✓ |  | ✓ | ✓ |
| `cron` |  |  |  |  | ✓ | ✓ |
| `crontab` |  | ✓ |  |  | ✓ | ✓ |
| `crunchgen` |  |  |  |  | ✓ | ✓ |
| `crunchide` |  |  |  |  | ✓ | ✓ |
| `csh` |  |  |  |  | ✓ | ✓ |
| `csplit` |  |  | ✓ | ✓ | ✓ | ✓ |
| `ctags` |  |  |  |  | ✓ | ✓ |
| `ctfconvert` |  |  |  |  | ✓ | ✓ |
| `ctfdump` |  |  |  |  | ✓ | ✓ |
| `ctfmerge` |  |  |  |  | ✓ | ✓ |
| `cu` |  |  |  |  | ✓ | ✓ |
| `cut` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `date` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dc` |  | ✓ | ✓ |  | ✓ | ✓ |
| `dd` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `df` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `diff` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `diff3` |  |  | ✓ |  | ✓ | ✓ |
| `dir` | ✓ |  | ✓ | ✓ |  |  |
| `dircolors` |  |  | ✓ | ✓ |  |  |
| `dirname` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dmesg` |  | ✓ |  |  | ✓ | ✓ |
| `dnsdomainname` |  | ✓ | ✓ |  |  |  |
| `domainname` |  |  |  |  | ✓ | ✓ |
| `dos2unix` | ✓ | ✓ |  |  |  |  |
| `dtc` |  |  |  |  | ✓ | ✓ |
| `dtrace` |  |  |  |  | ✓ | ✓ |
| `du` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dump` |  |  |  |  | ✓ | ✓ |
| `dumpfs` |  |  |  |  | ✓ | ✓ |
| `echo` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ed` |  | ✓ |  |  | ✓ | ✓ |
| `edquota` |  |  |  |  | ✓ | ✓ |
| `egrep` |  | ✓ | ✓ |  | ✓ | ✓ |
| `eject` |  | ✓ |  |  | ✓ |  |
| `elfedit` |  |  | ✓ |  | ✓ |  |
| `env` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `etcupdate` |  |  |  |  | ✓ | ✓ |
| `ex` |  |  |  |  | ✓ | ✓ |
| `expand` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `expr` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `extattrctl` |  |  |  |  | ✓ | ✓ |
| `factor` | ✓ | ✓ | ✓ | ✓ |  | ✓ |
| `false` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `fastboot` |  |  |  |  | ✓ | ✓ |
| `fasthalt` |  |  |  |  | ✓ | ✓ |
| `fat` | ✓ |  |  |  |  |  |
| `fdformat` |  | ✓ |  |  | ✓ | ✓ |
| `fdisk` |  | ✓ |  |  | ✓ |  |
| `fgrep` |  | ✓ | ✓ |  | ✓ | ✓ |
| `file` |  |  |  |  | ✓ | ✓ |
| `find` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `finger` |  |  |  |  | ✓ | ✓ |
| `flex` |  |  |  |  | ✓ | ✓ |
| `flex++` |  |  |  |  | ✓ | ✓ |
| `flock` |  | ✓ |  |  | ✓ |  |
| `fmt` |  |  | ✓ | ✓ | ✓ | ✓ |
| `fold` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `free` | ✓ | ✓ |  |  |  |  |
| `from` |  |  |  |  | ✓ | ✓ |
| `fsck` |  | ✓ |  |  | ✓ | ✓ |
| `fsck_ffs` |  |  |  |  | ✓ | ✓ |
| `fsdb` |  |  |  |  | ✓ | ✓ |
| `fsirand` |  |  |  |  | ✓ | ✓ |
| `fstat` |  |  |  |  | ✓ | ✓ |
| `fstyp` |  |  |  |  | ✓ | ✓ |
| `fsync` |  | ✓ |  |  |  | ✓ |
| `ftp` |  |  | ✓ |  | ✓ | ✓ |
| `ftp-proxy` |  |  |  |  | ✓ | ✓ |
| `ftpd` |  | ✓ | ✓ |  |  |  |
| `fuser` |  | ✓ |  |  |  | ✓ |
| `g++` |  |  | ✓ |  | ✓ |  |
| `gcc` |  |  | ✓ |  | ✓ |  |
| `gcore` |  |  |  |  | ✓ | ✓ |
| `gcov` |  |  | ✓ |  | ✓ | ✓ |
| `gcov-dump` |  |  | ✓ |  | ✓ |  |
| `gencat` |  |  |  |  | ✓ | ✓ |
| `getaddrinfo` |  |  |  |  | ✓ | ✓ |
| `getconf` |  |  |  |  | ✓ | ✓ |
| `getent` |  |  |  |  | ✓ | ✓ |
| `getextattr` |  |  |  |  | ✓ | ✓ |
| `getfacl` |  |  |  |  | ✓ | ✓ |
| `getopt` |  | ✓ |  |  | ✓ | ✓ |
| `gpioctl` |  |  |  |  | ✓ | ✓ |
| `gprof` |  |  | ✓ |  | ✓ | ✓ |
| `grep` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `groups` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `gunzip` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `gzcat` |  |  |  |  | ✓ | ✓ |
| `gzexe` |  |  | ✓ |  | ✓ | ✓ |
| `gzip` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `halt` |  | ✓ |  |  | ✓ | ✓ |
| `hd` |  | ✓ |  |  |  | ✓ |
| `head` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hexdump` |  | ✓ |  |  | ✓ | ✓ |
| `host` |  |  |  |  | ✓ | ✓ |
| `hostapd` |  |  |  |  | ✓ | ✓ |
| `hostapd_cli` |  |  |  |  | ✓ | ✓ |
| `hostid` |  | ✓ | ✓ | ✓ |  |  |
| `hostname` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hoststat` |  |  |  |  | ✓ | ✓ |
| `html2text` | ✓ |  |  |  |  |  |
| `hxtool` |  |  |  |  | ✓ | ✓ |
| `iasl` |  |  |  |  | ✓ | ✓ |
| `iconv` |  |  |  |  | ✓ | ✓ |
| `id` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ident` |  |  |  |  | ✓ | ✓ |
| `ifconfig` |  | ✓ |  |  | ✓ | ✓ |
| `ifmcstat` |  |  |  |  | ✓ | ✓ |
| `indent` |  |  |  |  | ✓ | ✓ |
| `inetd` |  | ✓ |  |  | ✓ | ✓ |
| `infocmp` |  |  |  |  | ✓ | ✓ |
| `init` |  | ✓ |  |  | ✓ | ✓ |
| `install` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `iostat` |  | ✓ |  |  | ✓ | ✓ |
| `ip6addrctl` |  |  |  |  | ✓ | ✓ |
| `ipcrm` |  | ✓ |  |  | ✓ | ✓ |
| `ipcs` |  | ✓ |  |  | ✓ | ✓ |
| `ipf` |  |  |  |  | ✓ | ✓ |
| `ipfstat` |  |  |  |  | ✓ | ✓ |
| `ipmon` |  |  |  |  | ✓ | ✓ |
| `ipnat` |  |  |  |  | ✓ | ✓ |
| `ippool` |  |  |  |  | ✓ | ✓ |
| `iprop-log` |  |  |  |  | ✓ | ✓ |
| `iscsictl` |  |  |  |  | ✓ | ✓ |
| `iscsid` |  |  |  |  | ✓ | ✓ |
| `join` | ✓ |  | ✓ | ✓ | ✓ | ✓ |
| `jot` |  |  |  |  | ✓ | ✓ |
| `kadmin` |  |  |  |  | ✓ | ✓ |
| `kcc` |  |  |  |  | ✓ | ✓ |
| `kdestroy` |  |  |  |  | ✓ | ✓ |
| `kdump` |  |  |  |  | ✓ | ✓ |
| `kgetcred` |  |  |  |  | ✓ | ✓ |
| `kill` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `killall` | ✓ | ✓ |  |  |  | ✓ |
| `kinit` |  |  |  |  | ✓ | ✓ |
| `klist` |  |  |  |  | ✓ | ✓ |
| `kpasswd` |  |  |  |  | ✓ | ✓ |
| `krb5-config` |  |  |  |  | ✓ | ✓ |
| `kstash` |  |  |  |  | ✓ | ✓ |
| `ktrace` |  |  |  |  | ✓ | ✓ |
| `ktutil` |  |  |  |  | ✓ | ✓ |
| `lam` |  |  |  |  | ✓ | ✓ |
| `last` |  |  |  |  | ✓ | ✓ |
| `lastcomm` |  |  |  |  | ✓ | ✓ |
| `lastlogin` |  |  |  |  | ✓ | ✓ |
| `ld` | ✓ |  | ✓ |  | ✓ | ✓ |
| `ldd` |  |  |  |  | ✓ | ✓ |
| `leave` |  |  |  |  | ✓ | ✓ |
| `less` | ✓ | ✓ |  |  | ✓ | ✓ |
| `lessecho` |  |  |  |  | ✓ | ✓ |
| `lesskey` |  |  |  |  | ✓ | ✓ |
| `lex` |  |  |  |  | ✓ | ✓ |
| `lift` | ✓ |  |  |  |  |  |
| `link` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ln` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `locale` |  |  |  |  | ✓ | ✓ |
| `locate` |  |  |  |  | ✓ | ✓ |
| `lock` |  |  |  |  | ✓ | ✓ |
| `lockstat` |  |  |  |  | ✓ | ✓ |
| `logger` |  | ✓ |  |  | ✓ | ✓ |
| `login` |  | ✓ |  |  | ✓ | ✓ |
| `logname` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `look` |  |  |  |  | ✓ | ✓ |
| `lorder` |  |  |  |  | ✓ | ✓ |
| `lp` |  |  |  |  | ✓ | ✓ |
| `lpc` |  |  |  |  | ✓ | ✓ |
| `lpd` |  | ✓ |  |  | ✓ | ✓ |
| `lpq` |  | ✓ |  |  | ✓ | ✓ |
| `lpr` |  | ✓ |  |  | ✓ | ✓ |
| `lprm` |  |  |  |  | ✓ | ✓ |
| `lptest` |  |  |  |  | ✓ | ✓ |
| `ls` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `lsextattr` |  |  |  |  | ✓ | ✓ |
| `lush` | ✓ |  |  |  |  |  |
| `lzcat` |  | ✓ |  |  | ✓ | ✓ |
| `lzma` |  | ✓ |  |  | ✓ | ✓ |
| `lzmainfo` |  |  |  |  | ✓ | ✓ |
| `m4` |  |  | ✓ |  | ✓ | ✓ |
| `mac2unix` | ✓ |  |  |  |  |  |
| `mail` |  |  |  |  | ✓ | ✓ |
| `mailq` |  |  |  |  | ✓ | ✓ |
| `mailwrapper` |  |  |  |  | ✓ | ✓ |
| `mailx` |  |  |  |  | ✓ | ✓ |
| `make` | ✓ |  | ✓ |  | ✓ | ✓ |
| `makefs` |  |  |  |  | ✓ | ✓ |
| `man` | ✓ | ✓ |  |  | ✓ | ✓ |
| `mandoc` |  |  |  |  | ✓ | ✓ |
| `markdown` | ✓ |  |  |  |  |  |
| `mc` | ✓ |  |  |  |  |  |
| `md5` |  |  |  |  | ✓ | ✓ |
| `md5sum` | ✓ | ✓ | ✓ | ✓ |  | ✓ |
| `mdconfig` |  |  |  |  | ✓ | ✓ |
| `mesg` |  | ✓ |  |  | ✓ | ✓ |
| `mkcsmapper` |  |  |  |  | ✓ | ✓ |
| `mkdep` |  |  |  |  | ✓ | ✓ |
| `mkdir` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `mkdosfs` | ✓ | ✓ |  |  |  |  |
| `mkesdb` |  |  |  |  | ✓ | ✓ |
| `mkfifo` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `mkfs.vfat` | ✓ | ✓ |  |  |  |  |
| `mknod` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `mkstr` |  |  |  |  | ✓ | ✓ |
| `mktemp` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `mld6query` |  |  |  |  | ✓ | ✓ |
| `more` | ✓ | ✓ |  | ✓ | ✓ | ✓ |
| `mount` | ✓ | ✓ |  |  | ✓ | ✓ |
| `mount_cd9660` |  |  |  |  | ✓ | ✓ |
| `mount_mfs` |  |  |  |  | ✓ | ✓ |
| `mount_nfs` |  |  |  |  | ✓ | ✓ |
| `mount_udf` |  |  |  |  | ✓ | ✓ |
| `mountd` |  |  |  |  | ✓ | ✓ |
| `moused` |  |  |  |  | ✓ | ✓ |
| `msgs` |  |  |  |  | ✓ | ✓ |
| `mt` |  | ✓ |  |  | ✓ | ✓ |
| `mtree` |  |  |  |  | ✓ | ✓ |
| `mv` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `nc` | ✓ | ✓ |  |  | ✓ | ✓ |
| `ndp` |  |  |  |  | ✓ | ✓ |
| `netstat` |  | ✓ |  |  | ✓ | ✓ |
| `newaliases` |  |  |  |  | ✓ | ✓ |
| `newfs` |  |  |  |  | ✓ | ✓ |
| `newfs_msdos` |  |  |  |  | ✓ | ✓ |
| `newgrp` |  |  |  |  | ✓ | ✓ |
| `newsyslog` |  |  |  |  | ✓ | ✓ |
| `nfsd` |  |  |  |  | ✓ | ✓ |
| `nfsstat` |  |  |  |  | ✓ | ✓ |
| `nice` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `nl` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `nm` | ✓ |  | ✓ |  | ✓ | ✓ |
| `nohup` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `nologin` |  |  |  |  | ✓ | ✓ |
| `nproc` | ✓ | ✓ | ✓ | ✓ |  | ✓ |
| `nslookup` |  | ✓ |  |  | ✓ |  |
| `ntp-keygen` |  |  |  |  | ✓ | ✓ |
| `ntpd` |  | ✓ |  |  | ✓ | ✓ |
| `ntpdate` |  |  |  |  | ✓ | ✓ |
| `ntpdc` |  |  |  |  | ✓ | ✓ |
| `ntpq` |  |  |  |  | ✓ | ✓ |
| `ntptime` |  |  |  |  | ✓ | ✓ |
| `numfmt` |  |  | ✓ | ✓ |  |  |
| `objcopy` | ✓ |  | ✓ |  | ✓ | ✓ |
| `objdump` |  |  | ✓ |  | ✓ | ✓ |
| `od` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `openssl` |  |  |  |  | ✓ | ✓ |
| `pac` |  |  |  |  | ✓ | ✓ |
| `pagesize` |  |  |  |  | ✓ | ✓ |
| `passwd` |  | ✓ |  |  | ✓ | ✓ |
| `paste` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `patch` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `pathchk` |  |  | ✓ | ✓ | ✓ | ✓ |
| `pax` |  |  |  |  | ✓ | ✓ |
| `pfctl` |  |  |  |  | ✓ | ✓ |
| `pflogd` |  |  |  |  | ✓ | ✓ |
| `pgrep` | ✓ | ✓ |  |  | ✓ | ✓ |
| `pidof` | ✓ | ✓ |  |  |  |  |
| `ping` |  | ✓ |  |  | ✓ | ✓ |
| `ping6` |  | ✓ |  |  | ✓ | ✓ |
| `pinky` |  |  | ✓ | ✓ |  |  |
| `pkill` | ✓ | ✓ |  |  | ✓ | ✓ |
| `pmap` |  | ✓ |  |  | ✓ |  |
| `pom` | ✓ |  |  |  |  | ✓ |
| `powerd` |  |  |  |  | ✓ | ✓ |
| `poweroff` |  | ✓ |  |  | ✓ | ✓ |
| `pr` |  |  | ✓ | ✓ | ✓ | ✓ |
| `printenv` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `printf` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ps` | ✓ | ✓ |  |  | ✓ | ✓ |
| `pstat` |  |  |  |  | ✓ | ✓ |
| `ptx` |  |  | ✓ | ✓ |  |  |
| `purgestat` |  |  |  |  | ✓ | ✓ |
| `pwait` |  |  |  |  | ✓ | ✓ |
| `pwd` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `pwd_mkdb` |  |  |  |  | ✓ | ✓ |
| `pwdx` | ✓ | ✓ |  |  |  | ✓ |
| `quot` |  |  |  |  | ✓ | ✓ |
| `quota` |  |  |  |  | ✓ | ✓ |
| `quotacheck` |  |  |  |  | ✓ | ✓ |
| `quotaoff` |  |  |  |  | ✓ | ✓ |
| `quotaon` |  |  |  |  | ✓ | ✓ |
| `ranlib` |  |  | ✓ |  | ✓ | ✓ |
| `rarpd` |  |  |  |  | ✓ | ✓ |
| `rcorder` |  |  |  |  | ✓ | ✓ |
| `rcp` |  |  | ✓ |  | ✓ |  |
| `rdate` |  | ✓ |  |  | ✓ |  |
| `rdump` |  |  |  |  | ✓ | ✓ |
| `readelf` |  |  | ✓ |  | ✓ | ✓ |
| `readlink` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `realpath` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `reboot` |  | ✓ |  |  | ✓ | ✓ |
| `renice` |  | ✓ |  |  | ✓ | ✓ |
| `repquota` |  |  |  |  | ✓ | ✓ |
| `reset` |  | ✓ |  |  | ✓ | ✓ |
| `resize` |  | ✓ |  |  | ✓ |  |
| `resolvconf` |  |  |  |  | ✓ | ✓ |
| `restore` |  |  |  |  | ✓ | ✓ |
| `rev` | ✓ | ✓ |  |  | ✓ | ✓ |
| `revoke` |  |  |  |  | ✓ | ✓ |
| `rfcomm_sppd` |  |  |  |  | ✓ | ✓ |
| `rip6query` |  |  |  |  | ✓ | ✓ |
| `rlogin` |  |  | ✓ |  | ✓ |  |
| `rm` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `rmd160` |  |  |  |  | ✓ | ✓ |
| `rmdir` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `rmextattr` |  |  |  |  | ✓ | ✓ |
| `rmt` |  |  |  |  | ✓ | ✓ |
| `route` |  | ✓ |  |  | ✓ | ✓ |
| `route6d` |  |  |  |  | ✓ | ✓ |
| `routed` |  |  |  |  | ✓ | ✓ |
| `rpc.lockd` |  |  |  |  | ✓ | ✓ |
| `rpc.statd` |  |  |  |  | ✓ | ✓ |
| `rpc.yppasswdd` |  |  |  |  | ✓ | ✓ |
| `rpcbind` |  |  |  |  | ✓ | ✓ |
| `rpcgen` |  |  |  |  | ✓ | ✓ |
| `rpcinfo` |  |  |  |  | ✓ | ✓ |
| `rrestore` |  |  |  |  | ✓ | ✓ |
| `rs` |  |  |  |  | ✓ | ✓ |
| `rsh` |  |  | ✓ |  | ✓ |  |
| `rtadvd` |  |  |  |  | ✓ | ✓ |
| `rtquery` |  |  |  |  | ✓ | ✓ |
| `rup` |  |  |  |  | ✓ | ✓ |
| `ruptime` |  |  |  |  | ✓ | ✓ |
| `rusers` |  |  |  |  | ✓ | ✓ |
| `rwall` |  |  |  |  | ✓ | ✓ |
| `rwho` |  |  |  |  | ✓ | ✓ |
| `rwhod` |  |  |  |  | ✓ | ✓ |
| `sa` |  |  |  |  | ✓ | ✓ |
| `savecore` |  |  |  |  | ✓ | ✓ |
| `scp` |  |  |  |  | ✓ | ✓ |
| `script` |  | ✓ |  |  | ✓ | ✓ |
| `sdiff` |  |  | ✓ |  | ✓ | ✓ |
| `sdpd` |  |  |  |  | ✓ | ✓ |
| `sed` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `sendmail` |  | ✓ |  |  | ✓ | ✓ |
| `seq` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `service` |  |  |  |  | ✓ | ✓ |
| `services_mkdb` |  |  |  |  | ✓ | ✓ |
| `setextattr` |  |  |  |  | ✓ | ✓ |
| `setfacl` |  |  |  |  | ✓ | ✓ |
| `setkey` |  |  |  |  | ✓ | ✓ |
| `sftp` |  |  |  |  | ✓ | ✓ |
| `sh` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `sha1` |  |  |  |  | ✓ | ✓ |
| `sha1sum` |  | ✓ | ✓ | ✓ |  | ✓ |
| `sha224sum` |  |  | ✓ | ✓ |  | ✓ |
| `sha256` |  |  |  |  | ✓ | ✓ |
| `sha256sum` | ✓ | ✓ | ✓ | ✓ |  | ✓ |
| `sha384` |  |  |  |  | ✓ | ✓ |
| `sha384sum` |  |  | ✓ | ✓ |  | ✓ |
| `sha512` |  |  |  |  | ✓ | ✓ |
| `sha512sum` |  | ✓ | ✓ | ✓ |  | ✓ |
| `shar` |  |  |  |  | ✓ | ✓ |
| `showmount` |  |  |  |  | ✓ | ✓ |
| `shred` |  | ✓ | ✓ | ✓ |  |  |
| `shuf` | ✓ | ✓ | ✓ | ✓ |  |  |
| `shutdown` |  |  |  |  | ✓ | ✓ |
| `size` |  |  | ✓ |  | ✓ | ✓ |
| `slattach` |  | ✓ |  |  | ✓ |  |
| `sleep` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `slogin` |  |  |  |  | ✓ | ✓ |
| `sntp` |  |  |  |  | ✓ | ✓ |
| `sockstat` |  |  |  |  | ✓ | ✓ |
| `soelim` |  |  |  |  | ✓ | ✓ |
| `sort` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `split` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `spray` |  |  |  |  | ✓ | ✓ |
| `ssh` |  |  |  |  | ✓ | ✓ |
| `ssh-add` |  |  |  |  | ✓ | ✓ |
| `ssh-agent` |  |  |  |  | ✓ | ✓ |
| `ssh-copy-id` |  |  |  |  | ✓ | ✓ |
| `ssh-keygen` |  |  |  |  | ✓ | ✓ |
| `ssh-keyscan` |  |  |  |  | ✓ | ✓ |
| `sshd` |  |  |  |  | ✓ | ✓ |
| `stat` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `stdbuf` |  |  | ✓ | ✓ |  | ✓ |
| `string2key` |  |  |  |  | ✓ | ✓ |
| `strings` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `strip` |  |  | ✓ |  | ✓ | ✓ |
| `stty` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `su` |  | ✓ |  |  | ✓ | ✓ |
| `sum` |  | ✓ | ✓ | ✓ | ✓ | ✓ |
| `swapctl` |  |  |  |  | ✓ | ✓ |
| `swapoff` |  | ✓ |  |  |  | ✓ |
| `swapon` |  | ✓ |  |  | ✓ | ✓ |
| `sync` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `sysctl` |  | ✓ |  |  | ✓ | ✓ |
| `syslogd` |  | ✓ |  |  | ✓ | ✓ |
| `systat` |  |  |  |  | ✓ | ✓ |
| `tabs` |  |  |  |  | ✓ | ✓ |
| `tac` | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `tail` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `talk` |  |  | ✓ |  | ✓ | ✓ |
| `tar` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `tcopy` |  |  |  |  | ✓ | ✓ |
| `tcpdchk` |  |  |  |  | ✓ | ✓ |
| `tcpdmatch` |  |  |  |  | ✓ | ✓ |
| `tcpdrop` |  |  |  |  | ✓ | ✓ |
| `tcpdump` |  |  |  |  | ✓ | ✓ |
| `tee` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `telnet` |  | ✓ | ✓ |  | ✓ | ✓ |
| `telnetd` |  | ✓ | ✓ |  |  |  |
| `test` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tftp` |  | ✓ |  |  | ✓ | ✓ |
| `tic` |  |  |  |  | ✓ | ✓ |
| `time` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `timeout` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tip` |  |  |  |  | ✓ | ✓ |
| `top` | ✓ | ✓ |  |  | ✓ | ✓ |
| `touch` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tput` |  |  |  |  | ✓ | ✓ |
| `tr` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `traceroute` |  | ✓ |  |  | ✓ | ✓ |
| `traceroute6` |  | ✓ |  |  | ✓ | ✓ |
| `true` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `truncate` |  | ✓ | ✓ | ✓ |  | ✓ |
| `tset` |  |  |  |  | ✓ | ✓ |
| `tsort` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tty` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tunefs` |  |  |  |  | ✓ | ✓ |
| `ul` |  |  |  |  | ✓ | ✓ |
| `umount` | ✓ | ✓ |  |  | ✓ | ✓ |
| `uname` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `uncompress` |  | ✓ | ✓ |  | ✓ | ✓ |
| `unexpand` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `unifdef` |  |  |  |  | ✓ | ✓ |
| `unifdefall` |  |  |  |  | ✓ | ✓ |
| `uniq` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `units` |  |  |  |  | ✓ | ✓ |
| `unix2dos` | ✓ | ✓ |  |  |  |  |
| `unlink` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `unlzma` |  | ✓ |  |  | ✓ | ✓ |
| `unvis` |  |  |  |  | ✓ | ✓ |
| `unxz` |  | ✓ |  |  | ✓ | ✓ |
| `unzip` |  | ✓ |  |  | ✓ | ✓ |
| `uptime` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `usbhidaction` |  |  |  |  | ✓ | ✓ |
| `usbhidctl` |  |  |  |  | ✓ | ✓ |
| `users` |  |  | ✓ | ✓ | ✓ | ✓ |
| `uudecode` |  | ✓ |  |  | ✓ | ✓ |
| `uuencode` |  | ✓ |  |  | ✓ | ✓ |
| `uuidgen` |  |  |  |  | ✓ | ✓ |
| `vacation` |  |  |  |  | ✓ | ✓ |
| `vdir` |  |  | ✓ | ✓ |  |  |
| `verify_krb5_conf` |  |  |  |  | ✓ | ✓ |
| `vi` | ✓ | ✓ |  |  | ✓ | ✓ |
| `view` |  |  |  |  | ✓ | ✓ |
| `vipw` |  |  |  |  | ✓ | ✓ |
| `vis` |  |  |  |  | ✓ | ✓ |
| `vmstat` |  |  |  |  | ✓ | ✓ |
| `w` |  |  |  |  | ✓ | ✓ |
| `wall` |  |  |  |  | ✓ | ✓ |
| `watch` |  | ✓ |  |  |  | ✓ |
| `watchdog` |  | ✓ |  |  |  | ✓ |
| `wc` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `wget` | ✓ | ✓ | ✓ |  |  |  |
| `what` |  |  |  |  | ✓ | ✓ |
| `whatis` |  |  |  |  | ✓ | ✓ |
| `whereis` |  |  |  |  | ✓ | ✓ |
| `which` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `who` |  |  | ✓ | ✓ | ✓ | ✓ |
| `whoami` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `whois` |  | ✓ |  |  | ✓ | ✓ |
| `wpa_cli` |  |  |  |  | ✓ | ✓ |
| `wpa_passphrase` |  |  |  |  | ✓ | ✓ |
| `wpa_supplicant` |  |  |  |  | ✓ | ✓ |
| `write` |  |  |  |  | ✓ | ✓ |
| `xargs` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `xstr` |  |  |  |  | ✓ | ✓ |
| `xxd` | ✓ | ✓ |  |  |  |  |
| `xz` |  | ✓ |  |  | ✓ | ✓ |
| `xzcat` |  | ✓ |  |  | ✓ | ✓ |
| `yacc` |  |  |  |  | ✓ | ✓ |
| `yes` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ypbind` |  |  |  |  | ✓ | ✓ |
| `ypcat` |  |  |  |  | ✓ | ✓ |
| `ypinit` |  |  |  |  | ✓ | ✓ |
| `ypmatch` |  |  |  |  | ✓ | ✓ |
| `yppasswd` |  |  |  |  | ✓ | ✓ |
| `yppoll` |  |  |  |  | ✓ | ✓ |
| `yppush` |  |  |  |  | ✓ | ✓ |
| `ypserv` |  |  |  |  | ✓ | ✓ |
| `ypset` |  |  |  |  | ✓ | ✓ |
| `ypwhich` |  |  |  |  | ✓ | ✓ |
| `zcat` | ✓ | ✓ | ✓ |  | ✓ | ✓ |
| `zcmp` |  |  | ✓ |  | ✓ | ✓ |
| `zdb` |  |  |  |  | ✓ | ✓ |
| `zdiff` |  |  | ✓ |  | ✓ | ✓ |
| `zdump` |  |  |  |  | ✓ | ✓ |
| `zegrep` |  |  | ✓ |  | ✓ | ✓ |
| `zfgrep` |  |  | ✓ |  | ✓ | ✓ |
| `zforce` |  |  | ✓ |  | ✓ | ✓ |
| `zfs` |  |  |  |  | ✓ | ✓ |
| `zgrep` |  |  | ✓ |  | ✓ | ✓ |
| `zic` |  |  |  |  | ✓ | ✓ |
| `zless` |  |  | ✓ |  | ✓ | ✓ |
| `zmore` |  |  | ✓ |  | ✓ | ✓ |
| `znew` |  |  | ✓ |  | ✓ | ✓ |
| `zpool` |  |  |  |  | ✓ | ✓ |
| `ztest` |  |  |  |  | ✓ | ✓ |

The names only one carries:

* **busybox alone** (181): `[[` `acpid` `addgroup` `adjtimex` `arping` `ascii` `ash` `bbconfig`
  `blkid` `blockdev` `bootchartd` `brctl` `busybox` `chattr` `chpasswd` `chpst` `chrt` `chvt`
  `crc32` `crond` `cryptpw` `cttyhack` `deallocvt` `delgroup` `deluser` `depmod` `dhcprelay`
  `dnsd` `dumpkmap` `dumpleases` `envdir` `envuidgid` `ether-wake` `fakeidentd` `fallocate`
  `fatattr` `fbset` `fbsplash` `fdflush` `fgconsole` `findfs` `freeramdisk` `fsck.minix`
  `fsfreeze` `fstrim` `ftpget` `ftpput` `getty` `hdparm` `hexedit` `httpd` `hwclock`
  `i2cdetect` `i2cdump` `i2cget` `i2cset` `i2ctransfer` `ifdown` `ifenslave` `ifplugd` `ifup`
  `inotifyd` `insmod` `ionice` `ip` `ipaddr` `ipcalc` `iplink` `ipneigh` `iproute` `iprule`
  `iptunnel` `kbd_mode` `killall5` `klogd` `linux32` `linux64` `linuxrc` `loadfont` `loadkmap`
  `logread` `losetup` `lsattr` `lsmod` `lsof` `lspci` `lsscsi` `lsusb` `lzopcat` `makedevs`
  `makemime` `mdev` `microcom` `mke2fs` `mkfs.ext2` `mkfs.minix` `mkpasswd` `mkswap` `modinfo`
  `modprobe` `mountpoint` `mpstat` `nameif` `nbd-client` `nmeter` `nsenter` `openvt`
  `partprobe` `pipe_progress` `pivot_root` `popmaildir` `powertop` `pscan` `pstree`
  `raidautorun` `rdev` `readahead` `readprofile` `reformime` `resume` `rfkill` `rmmod`
  `rpm2cpio` `rtcwake` `run-init` `run-parts` `runsv` `runsvdir` `rx` `scriptreplay` `seedrng`
  `setarch` `setconsole` `setfattr` `setfont` `setkeycodes` `setlogcons` `setpriv` `setserial`
  `setsid` `setuidgid` `sha3sum` `showkey` `smemcap` `softlimit` `ssl_client`
  `start-stop-daemon` `sulogin` `sv` `svc` `svlogd` `svok` `switch_root` `taskset` `tc`
  `tcpsvd` `tftpd` `tree` `ts` `ttysize` `tunctl` `tune2fs` `ubiattach` `ubidetach` `ubimkvol`
  `ubirename` `ubirmvol` `ubirsvol` `ubiupdatevol` `udhcpc` `udhcpc6` `udhcpd` `udpsvd`
  `uevent` `unlzop` `unshare` `usleep` `vconfig` `vlock` `volname` `zcip`
* **GNU alone** (27): `bash` `bashbug` `dwp` `gawk` `gawkbug` `gcc-ar` `gcc-nm` `gcc-ranlib`
  `gcov-tool` `gp-archive` `gp-collect-app` `gp-display-html` `gp-display-src`
  `gp-display-text` `gprofng` `gprofng-archive` `gprofng-collect-app` `gprofng-display-html`
  `gprofng-display-src` `gprofng-display-text` `gprofng-gmon` `ld.bfd` `ld.gold` `rbash`
  `rlogind` `rshd` `talkd`
* **uutils alone** (1): `coreutils`
* **NetBSD alone** (505): `addftinfo` `agrep` `aiomixer` `altqd` `altqstat` `amd` `amldb` `amq`
  `amrctl` `apmlabel` `arpaname` `atactl` `atf-config` `atf-report` `atf-run` `atf-sh`
  `atf-version` `audiocfg` `audioctl` `audioplay` `audiorecord` `audit-packages` `badsect`
  `bdes` `bioctl` `blocklistctl` `blocklistd` `bootpd` `bootpgw` `brconfig` `bta2dpd`
  `btattach` `btconfig` `btdevctl` `bthcid` `bthset` `btkey` `btpin` `c11` `canconfig` `catman`
  `cdplay` `cgdconfig` `checknr` `ci` `cleantags` `cnwctl` `co` `colcrt` `cpuctl` `crash` `cvs`
  `cvsbug` `cvslatest` `db` `dbsym` `ddns-confgen` `delv` `deroff` `dev_mkdb` `devpubd`
  `dhcpcd` `dhcpd` `dhcrelay` `dig` `disklabel` `diskpart` `dkctl` `dkscan_bsdlabel` `dmctl`
  `dmsetup` `dns-sd` `dnssec-cds` `dnssec-dsfromkey` `dnssec-importkey` `dnssec-keyfromlabel`
  `dnssec-keygen` `dnssec-revoke` `dnssec-settime` `dnssec-signzone` `dnssec-verify`
  `download-vulnerability-list` `drvctl` `dtruss` `dump_lfs` `dumplfs` `ekermit` `envstat`
  `eqn` `error` `execsnoop` `faithd` `fdiscard` `fgen` `fido2-assert` `fido2-cred`
  `fido2-token` `fincore` `fixmount` `flashctl` `fpr` `fsck_ext2fs` `fsck_lfs` `fsck_msdos`
  `fsck_udf` `fsck_v7fs` `fsinfo` `fsplit` `fssconfig` `fusermount` `fwctl` `gcpp` `gdb`
  `gdbserver` `gdbtui` `gdiffmk` `genassym` `getcap` `getencstat` `gettext` `gpt` `grn`
  `grodvi` `groff` `grog` `grolbp` `grolj4` `grops` `grotty` `group` `groupadd` `groupdel`
  `groupinfo` `groupmod` `gspa` `gsstool` `hdaudioctl` `hesinfo` `hlfsd` `hpftodit` `hprop`
  `i2cscan` `ifwatchd` `indxbib` `info` `infokey` `innetgr` `install-info` `install-sid`
  `installboot` `intrctl` `ioctlprint` `iopctl` `ipfs` `ipftest` `ipresend` `ipsend` `iptest`
  `irdaattach` `iscsi-initiator` `iscsi-target` `isibootd` `iwictl` `kcm` `kdc` `kdigest`
  `kgmon` `kimpersonate` `ksh` `ktruss` `kvno` `ldapadd` `ldapcompare` `ldapdelete` `ldapexop`
  `ldapmodify` `ldapmodrdn` `ldappasswd` `ldapsearch` `ldapurl` `ldapwhoami` `ldpd` `lint`
  `lkbib` `lookbib` `lto-dump` `lua` `luac` `luactl` `lvm` `lzf` `lzfcat` `machine` `makedbm`
  `makeinfo` `makemandb` `map-mbone` `mbrlabel` `md2` `md4` `mdig` `mdnsd` `mdsetimage` `menuc`
  `merge` `midiplay` `midirecord` `mixerctl` `mk-amd-map` `mkalias` `mklocale` `mknetid`
  `mkubootimage` `mlxctl` `mmcformat` `modload` `modstat` `modunload` `mopchk` `mopcopy` `mopd`
  `mopprobe` `moptrace` `mount_9p` `mount_ados` `mount_autofs` `mount_chfs` `mount_efs`
  `mount_ext2fs` `mount_fdesc` `mount_ffs` `mount_filecore` `mount_hfs` `mount_kernfs`
  `mount_lfs` `mount_msdos` `mount_nilfs` `mount_ntfs` `mount_null` `mount_overlay`
  `mount_portal` `mount_procfs` `mount_psshfs` `mount_ptyfs` `mount_puffs` `mount_qemufwcfg`
  `mount_sysctlfs` `mount_sysvbfs` `mount_tmpfs` `mount_ufs` `mount_umap` `mount_union`
  `mount_v7fs` `mount_zfs` `mrinfo` `mrouted` `mscdlabel` `msgattrib` `msgc` `msgcat` `msgcmp`
  `msgcomm` `msgconv` `msgen` `msgexec` `msgfmt` `msginit` `msgmerge` `msgunfmt` `msguniq`
  `mtrace` `named` `named-checkconf` `named-checkzone` `named-compilezone` `named-journalprint`
  `named-rrchecker` `nbperf` `nbsvtool` `ncdcs` `ndbootd` `neqn` `netgroup` `netgroup_mkdb`
  `netpgp` `netpgpkeys` `netpgpverify` `newbtconf` `newfs_ext2fs` `newfs_lfs` `newfs_sysvbfs`
  `newfs_udf` `newfs_v7fs` `npfctl` `npfd` `npftest` `nroff` `nsec3hash` `nsupdate` `ntptrace`
  `nvmectl` `nvmmctl` `omshell` `opensnoop` `page` `pamu2fcfg` `pawd` `paxctl` `pcap-config`
  `pcictl` `pdisk` `perfused` `pfbtops` `pfs` `pic` `pigz` `pkg_add` `pkg_admin` `pkg_create`
  `pkg_delete` `pkg_info` `plainrsa-gen` `post-grohtml` `postalias` `postcat` `postconf`
  `postdrop` `postfix` `postinstall` `postkick` `postlock` `postlog` `postmap` `postmulti`
  `postqueue` `postsuper` `posttls-finger` `pppd` `pppdump` `pppoectl` `pppstats` `pre-grohtml`
  `prenice` `procsystime` `progress` `psrset` `pwhash` `qsafe` `qsieve` `qsubst` `quotadump`
  `quotarestore` `racoon` `racoonctl` `radioctl` `raidctl` `rbootd` `rcmd` `rcs` `rcs2log`
  `rcsclean` `rcsdiff` `rcsfreeze` `rcslog` `rcsmerge` `rdist` `rdump_lfs` `refer` `resize_ffs`
  `resize_lfs` `revnetgroup` `rlog` `rndc` `rndc-confgen` `rndctl` `rpc.bootparamd`
  `rpc.pcnfsd` `rpcapd` `rump.arp` `rump.cgdconfig` `rump.dd` `rump.dhcpclient` `rump.envstat`
  `rump.fssconfig` `rump.halt` `rump.ifconfig` `rump.modload` `rump.modstat` `rump.modunload`
  `rump.ndp` `rump.netstat` `rump.ping` `rump.ping6` `rump.powerd` `rump.raidctl` `rump.route`
  `rump.rtadvd` `rump.sockstat` `rump.sysctl` `rump.traceroute` `rump_allserver` `rump_cd9660`
  `rump_efs` `rump_ext2fs` `rump_ffs` `rump_hfs` `rump_lfs` `rump_msdos` `rump_nfs` `rump_ntfs`
  `rump_server` `rump_syspuffs` `rump_sysvbfs` `rump_tmpfs` `rump_udf` `rump_v7fs` `rump_wmd`
  `scan_ffs` `scan_lfs` `schedctl` `scmdctl` `screenblank` `scsictl` `sdpquery` `send-pr`
  `sesd` `setencstat` `setobjstat` `shlock` `shmif_dumpbus` `shmif_pcapin` `shuffle` `skey`
  `skeyaudit` `skeyinfo` `skeyinit` `sliplogin` `slstats` `sortinfo` `spell` `sqlite3`
  `srtconfig` `stdethers` `stdhosts` `sti` `sunlabel` `svhlabel` `sys_info` `sysinst` `sysstat`
  `tbl` `tbrconfig` `texi2dvi` `texindex` `tfmtodit` `timed` `timedc` `tmux` `tprof` `tradcpp`
  `troff` `trpt` `tsig-keygen` `ttyflags` `umbctl` `unbound` `unbound-anchor`
  `unbound-checkconf` `unbound-control` `unbound-control-setup` `unbound-host` `unlzf` `unpigz`
  `usbdevs` `user` `useradd` `userdel` `userinfo` `usermod` `utoppya` `veriexecctl`
  `veriexecgen` `vgrind` `videoctl` `vnconfig` `vndcompress` `vndconfig` `vnduncompress`
  `wakeonlan` `wdogctl` `wg-keygen` `wg-userspace` `wgconfig` `wiconfig` `wire-test` `wlanctl`
  `wsconscfg` `wsconsctl` `wsfontload` `wsmoused` `wsmuxctl` `xgettext` `xmlwf` `yptest`
  `ypxfr`
* **FreeBSD alone** (433): `CC` `Mail` `acpiconf` `acpidb` `adjkerntz` `alias` `asn1_compile`
  `ath3kfw` `audit` `auditd` `auditdistd` `auditreduce` `authpf-noip` `b64decode` `b64encode`
  `backlight` `bcmfw` `bectl` `bg` `binmiscctl` `bintrans` `blacklistctl` `blacklistd`
  `bluetooth-config` `bmake` `bootparamd` `boottrace` `brandelf` `bsdcat` `bsdconfig` `bsdcpio`
  `bsddialog` `bsdiff` `bsdinstall` `bsdtar` `bsdunzip` `bsnmpd` `bsnmpget` `bsnmpset`
  `bsnmpwalk` `bspatch` `bthidcontrol` `bthidd` `bthost` `btsockstat` `byacc` `bzegrep`
  `bzfgrep` `bzgrep` `bzless` `caesar` `callbootd` `camcontrol` `camdd` `captoinfo` `cd`
  `cdcontrol` `chkey` `chkgrp` `chkprintcap` `ckdist` `clang` `clang++` `clang-cpp`
  `clang-scan-deps` `clear_locks` `comcontrol` `command` `compile_et` `conscontrol` `cpuset`
  `crashinfo` `crypt` `ctladm` `ctld` `ctlstat` `cxgbetool` `daemon` `dconschat` `ddb`
  `decryptcore` `devctl` `devd` `devfs` `devinfo` `devmatch` `dhclient` `dhclient-script`
  `dialog` `diskinfo` `dnctl` `dnctl15` `dpv` `drill` `dumpcis` `dumpon` `dwatch` `edit`
  `editmap` `ee` `efibootmgr` `efidp` `efitable` `efivar` `efiwake` `elfctl` `elfdump` `enigma`
  `etdump` `etherswitchcfg` `fc` `fdcontrol` `fdread` `fdwrite` `fetch` `ffsinfo` `fg`
  `fifolog_create` `fifolog_reader` `fifolog_writer` `file2c` `flowctl` `fortune`
  `freebsd-update` `freebsd-version` `fsck_4.2bsd` `fsck_msdosfs` `fsck_ufs` `fwcontrol`
  `fwget` `gate-ftp` `gbde` `gcache` `gconcat` `geli` `genl` `gensnmptree` `geom` `getfmac`
  `getopts` `getpmac` `ggatec` `ggated` `ggatel` `gjournal` `glabel` `gmirror` `gmountver`
  `gmultipath` `gnop` `gpart` `graid` `graid3` `grdc` `growfs` `gshsec` `gssd` `gstat`
  `gstripe` `gunion` `gvinum` `gvirstor` `hash` `hastctl` `hastd` `hccontrol` `hcsecd`
  `hv_kvp_daemon` `hv_vss_daemon` `i2c` `ibstat` `ibv_asyncwatch` `ibv_devices` `ibv_devinfo`
  `ibv_rc_pingpong` `ibv_srq_pingpong` `ibv_uc_pingpong` `ibv_ud_pingpong` `idprio` `infotocap`
  `iovctl` `ipfw` `ipfw15` `ipfwpcap` `iwmbtfw` `jail` `jexec` `jls` `jobs` `kbdcontrol`
  `kbdmap` `kenv` `keylogin` `keylogout` `keyserv` `kf` `kldconfig` `kldload` `kldstat`
  `kldunload` `kldxref` `ksu` `kswitch` `ktrdump` `kyua` `l2control` `l2ping` `ld.lld`
  `ldconfig` `ldd32` `lesspipe.sh` `lex++` `limits` `lldb` `lldb-server` `llvm-addr2line`
  `llvm-ar` `llvm-cov` `llvm-cxxfilt` `llvm-nm` `llvm-objcopy` `llvm-objdump` `llvm-profdata`
  `llvm-ranlib` `llvm-readelf` `llvm-readobj` `llvm-size` `llvm-strings` `llvm-strip`
  `llvm-symbolizer` `local-unbound` `local-unbound-anchor` `local-unbound-checkconf`
  `local-unbound-control` `local-unbound-setup` `localedef` `lockf` `logins` `lsvfs` `lzdec`
  `lzegrep` `lzfgrep` `lzgrep` `lzless` `mailstats` `make-roken` `makemap` `makewhatis`
  `manctl` `manpath` `mckey` `mdmfs` `mdo` `memcontrol` `mergemaster` `mfiutil` `mididump`
  `ministat` `mixer` `mkimg` `mksnap_ffs` `mkuzip` `mlx5tool` `mlxcontrol` `morse`
  `mount_fusefs` `mount_msdosfs` `mount_nullfs` `mount_smbfs` `mount_unionfs` `mprutil`
  `mpsutil` `mptutil` `mrsasutil` `mtest` `natd` `nawk` `ncal` `newkey` `nex` `nextboot`
  `nfscbd` `nfsdumpstate` `nfsiod` `nfsrevoke` `nfsuserd` `ngctl` `nghook` `nmtree` `nos-tun`
  `nscd` `number` `nvi` `nview` `nvmecontrol` `ofwdump` `pargs` `pciconf` `penv` `periodic`
  `perror` `pfilctl` `pftp` `pkg` `pmc` `pmcannotate` `pmccontrol` `pmcstat` `pmcstudy`
  `pnfsdscopymr` `pnfsdsfile` `pnfsdskill` `posixmqcontrol` `posixshmcontrol` `ppp` `pppctl`
  `praliases` `praudit` `primes` `proccontrol` `procstat` `prometheus_sysctl_exporter`
  `protect` `pw` `pwm` `random` `rctl` `read` `recoverdisk` `red` `ree` `resizewin`
  `rfcomm_pppd` `rgrep` `rmail` `rmd160sum` `rmuser` `rot13` `rpc.tlsclntd` `rpc.tlsservd`
  `rpc.umntall` `rpc.ypupdated` `rpc.ypxfrd` `rping` `rrenumd` `rtadvctl` `rtlbtfw` `rtprio`
  `rtsol` `rtsold` `sade` `sdpcontrol` `sesutil` `setfib` `setfmac` `setfsmac` `setpmac`
  `sha224` `sha512t224` `sha512t224sum` `sha512t256` `sha512t256sum` `skein1024` `skein1024sum`
  `skein256` `skein256sum` `skein512` `skein512sum` `slc` `smbmsg` `snapinfo` `sndctl` `spi`
  `strfile` `swapinfo` `sysrc` `tcpsso` `tcsh` `toe` `trim` `truss` `type` `tzsetup` `uathload`
  `ucmatose` `udaddy` `uefisign` `ugidfw` `uhsoctl` `ulimit` `umask` `unalias` `unstr` `unzstd`
  `usbconfig` `usbdump` `utx` `valectl` `vidcontrol` `vidfont` `vigr` `vtfontcvt` `wait` `wake`
  `watchdogd` `wg` `wlandebug` `xo` `xzdec` `xzdiff` `xzegrep` `xzfgrep` `xzgrep` `xzless`
  `yp_mkdb` `ypchfn` `ypchpass` `ypchsh` `ypldap` `zfsbootcfg` `zfsd` `zhack` `zinject`
  `zonectl` `zstd` `zstdcat` `zstdegrep` `zstdfgrep` `zstdgrep` `zstdless` `zstdmt` `zstream`
  `zstreamdump`
