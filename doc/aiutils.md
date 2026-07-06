# aiutils -- the busybox rung of the distro

the state of crew/utils/ and the road ahead. this ORIENTS; the laws live in
crew/utils/law.l, the GNU-identical smokes in `make test_utils`, and every doubt
settles by probing the built `au`. last trued up 2026-07-06.

## the arc

the distro plan (the ai-native POSIX environment over the Linux kernel) climbs
three rungs, each independently shippable: **aiutils** (this one -- the busybox
clone), a **vim clone** over cb + bao's edln/edraw seeds, and a **chibicc-class
C compiler** last, scoped to *compiles ai.c*, never the kernel. the pieces that
already existed -- cook (make), sh.l/bao (shell), holo (assembler), the terminal
stack, init.l (pid 1) -- mean aiutils is the gap between the posix-pid1
container and a livable system. the distro shape: kernel + static `ai` + .l
files, busybox's multi-call trick natively.

## au, the multi-call toolbox

ONE catted script (`out/host/au`, `bin/au` installs): the Makefile cats

    text.l core.l fs.l diff.l ain.l cook.l asbook.l elf.l au.l   (aufiles)

behind a `#!/usr/bin/env -S ai` shebang. au.l loads LAST and dispatches off the
program seat of `cmdline` -- `au TOOL ARGS..`, or symlink a tool's name to au
and argv[0] picks it (how the distro will shadow at will). the registry is a
tablet, so tool names never collide with the globals they call (the `mkdir`
applet CALLS the `mkdir` nif; different namespaces).

the file discipline, two shapes:

* **a tool with a seat** (tools/ain.l, crew/cook/cook.l): define-only, leaking
  one `<tool>-main`; a body-having tail fires it iff the file's own basename
  sits in the program seat -- so the same file is a standalone tool AND a quiet
  cat member.
* **a toolbox** (core.l, fs.l): many mains, NO seat -- au is its door.

## the inventory (32 tools, 34 names)

| where | tools |
| --- | --- |
| au.l (thin mains) | diff (the patience/myers engines), as (elf64 over the holo book) |
| tools/ain.l | nc / ain |
| crew/cook/cook.l | make / cook |
| core.l, the line tools | cat echo head tail wc sort uniq tee |
| core.l, the field tools | cut tr nl rev |
| core.l, the trivia | seq yes true false basename dirname |
| fs.l, the fs tools | ls cp mv rm mkdir rmdir ln touch pwd chmod |
| re.l, the matcher | grep (-n -v -c -l) over the lawed BRE engine |

## the discipline (why this stays trustworthy)

* **GNU to the byte.** every tool with printable output is smoked
  byte-identical against the real GNU tool in `make test_utils` (LC_ALL=C for
  sort/ls). the fussy faces are pinned deliberately: wc pads every field to the
  digit width of the byte TOTAL; uniq -c wears width 7; nl is pad-6 + tab and a
  blank line is seven bare spaces; head/tail banner many files with
  `==> name <==`; ls -a is GNU -A. effects (cp/mv/rm/..) are smoked by acting
  and then verifying with the shell.
* **the u-floor.** the shared helpers leak u-prefixed from core.l and are lawed
  pure in law.l: uatoi uread udie upad ujoin uhdr uhead/utail ucount ubase/udir
  usplit ujoinc uspec/upick uset urev ueach, and fs.l's uoct/udirp/udest/ucopy.
  `ueach` is the cat walk every whole-input tool rides (files or stdin, `-`
  reads stdin, a miss complains on err and the exit code remembers).
* **the nif lane.** fs effects ride host/init.c + host/fs.c (app-glob AI_NIF,
  no core edit), init.c's posix_ conventions: an effect op answers () ok | a
  POSITIVE errno | EINVAL misuse; a value op answers the value | (). host/fs.c
  holds rename symlink readlink chmod chown utime umask rmdir hardlink
  (`link` the word belongs to the chain ctor). boot/fs.l smokes them in
  test_hostnif.
* **exit codes.** 0 clean, 1 something failed (reported on err, the loop
  continued), 2 usage; diff keeps its classic 0/1/2 triple.

## the traps already paid for

* `show` is the decimal formatter; `string` of a number makes a ONE-CHARM text
  (ain.l's error path still carries that latent bug).
* prel `sort` on strings IS lexicographic (probed via the "b"-vs-"ab"
  discriminator), which is exactly LC_ALL=C -- no comparator needed.
* a symlink TARGET resolves relative to the LINK's directory, not the cwd.
* lines/unlines normalize an unterminated final line (the tool layer's ONE
  normalization); cat copies verbatim, head/tail/sort/uniq normalize like GNU
  sort does (GNU head does not -- known, harmless, unsmoked).
* ⚠ **open compiler bug** (doc/bug-nested-go-shadow.md, core-thread work): a
  nested define named like a sibling pin, beside unfolded computed pins, makes
  the enclosing recursion silently no-op. until fixed, give nested loops
  DISTINCT noms in tool code (fs.l's zap walks `ent`, never `go`).

## the regex engine (crew/utils/re.l)

landed. a POSIX-BRE dialect -- literals, `.`, `*`, head-`^`/tail-`$`, [..]
classes with ranges/negation (first-] and edge-- literal), \-escapes, \( \)
groups, GNU's \+ \? -- with GNU's leniency (a repeat with no atom is ink) and
GNU's refusals mirrored as parse errors (backrefs, intervals, alternation).
(rebre p) answers (1 nodes) | (); (rehas nodes s) the boolean; (refind nodes
s i) the leftmost greedy span as (1 start end) -- the (1 ..) shapes because a
match ending at 0 is blue by measure. the matcher is greedy backtracking in
continuation style; the laws (law.l) hold the dialect by hand AND by a seeded
differential fuzz against an independent Brzozowski-derivative oracle. grep
rides it: -n -v -c -l, GNU-byte-identical smokes + the 0/1/2 exit triple
(an unreadable file beats a match). sed's substitution will ride refind;
group SPANS (for \1 in replacements) are the one engine extension it needs.

## remaining work, in order

1. **sed-lite** -- s/re/repl/[g], d, p, -n, line/range addresses; rides re.l
   (refind + a group-span extension for \1).
2. **the process tools** -- env, sleep, kill, xargs. no new nifs: environ/
   setenv/getenv, `rest`, bao's `still`, spawn/wait.
3. **polish, as need arises** -- ls -l (stat already carries size/mtime/mode),
   cp -r, multi-source cp/mv into a directory, sort -n/-k, uniq -d/-u, cut -b,
   tr [:class:] and -ds, echo -e, seq over gems, grep -i/-o/-E. none block the
   distro; add them when a real script wants them.

after aiutils: the vim clone (rung 2), then the C compiler (rung 3) -- see the
ai-distro arc. the multi-call `au` is already the shape the distro boots with.
