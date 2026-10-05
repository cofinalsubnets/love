# AGENTS.md

Instructions for any coding agent in this tree.

```love
; love is a self reproducing software artifact that combines
; several tools in a single binary.
;
; - love: a programming language
; - moon: a C compiler and toolchain
; - kore: a userland and coreutils
; - inle: a bare metal somewhat-unix-like love runtime
;
; the love language is a curried lisp dialect with syntactic
; sugar for infix and prefix notation and pattern matching.
; it uses many fewer parens than traditional lisp and resembles a mix
; of scheme, haskell, and apl.
;
; mooncc builds statically linked executables that currently run on
; linux, freebsd and netbsd, using a built in custom libc, for x64,
; a64, and thumb32, with rv64 currently in development.
;
; kore includes sh, make, vi, as, nc, gzip/gunzip, and lots of other
; utilities.
;
; inle currently runs on x64, a64 and rv64 and includes a virtual console,
; filesystem, and doom port.
;
; the love artifact includes all these components in a single binary together
; with a compressed copy of its own source code, which it can use to identically
; reproduce itself, either by bootstrapping through another C compiler, or
; entirely with moon and kore.

; guidelines for working in this tree:
; - keep comments short, calm lowercase, inline when possible, no paragraphs
; - comments should not log history, cite fixed bugs, or refer outside the present code
; - C code may not use mutable globals/statics or directly call malloc/free (with rare exceptions)
; - makefiles must be compatible with our make (cook)
; - shell scripts must be compatible with our shell (lush)
; - `make test` is the fast gate to check if something works (<1m)
; - `make test_slow` is the slow gate, before committing (<10m)
; - `make test_extra` is the really slow gate, before merging (qemu boots, cross-arch, boards)
; - use libra `out/love src/apps/libra/libra.l <file>` to check paren balance
; - don't trust comments without reading the code they're talking about
; - just because something was done on purpose doesn't mean it was for a good reason

; love artifact and build information:
; - love and inle are not separate builds. moon builds both with the same flags and
;   links them together, and they share one copy of almost everything. a given instance
;   of the love artifact is linked for hosted or freestanding use, but the translation
;   is bidirectional and mechanical, and either image can generate the other.
; - mooncc compiles the artifact. the ambient cc is used to build love0, the bootstrap build of
;   love, which runs moon, which builds the finished product. 
; - moon's libc is moonlibc (src/apps/moon/lib/moonlibc), statically linked. not glibc, not musl.
;   if you are about to reach for a libc function, check that we have it
; - __STDC_HOSTED__ is 1 nearly everywhere -- mooncc predefines it. the seven src/inle/
;   board lanes pass -D __STDC_HOSTED__=0 and are the only freestanding compiles; the
;   kernel and wasm are both hosted
; - which artifacts compile a file is a question for the build, not for a comment or a
;   symbol name: `find out -name '<file>.o'`. objects under out/ go stale, so check an
;   mtime before reading one as evidence

; our motto:
; ce qui est tout à fait supérieur reproduit ce qui est tout à fait inférieur, mais transposé


;;; love language examples

1 = 0 5                      ; 0 is const-1, 1 is the identity
8 = 3 2                      ; n x = x ** n
262144 = 2 3 4               ; the tower 4 ** (3 ** 2)
3.0 = (1 / 2) 9              ; (1 / 2) x = sqrt x
i = 0.5 -1                   ; complex numbers
i = (0 ~ 1)                  ; a ~ b = (twin a b), the complex builder
[1 2 3] = sort [3 1 2]       ; [x y z] = (list x y z)
{'a 1 'b 2}                  ; {k v ..} = (hash k v ..), a tablet
"a \"q\"" = """a "q""""      ; three or more quotes: a raw text, no escapes. one ending
                             ; its line closes on a line of its own, whose indent comes off
"7 of 3" = "\(c) of \(#l)"   ; \( a hole: a form to its closer; a string laid as is, the rest shown
[2 3 4] = map (+ 1) [1 2 3]
12 = +[3 4 5]                ; +x = (net x)
3 = #[3 1 2]                 ; #x = (tally x)
60 = *[[3 2] [2 [5]]]        ; *x = (prod x)
1 < 2 <= 3                   ; comparison chaining

; triangular number sequence
[1 3 6 10 15] = map (net * jot * (+ 2)) ^5 ; ^n = (jot n)

; infix notation
(tally "hello" = 3 + 2 ? 'ok 'whoa) = (? (= (tally "hello") (+ 3 2)) 'ok 'whoa)

; an infix lambda (params \ body) applied on the spot, its answer matched by @
(([a b c] \ [(a * b + c) (b * c + a) (c * a + b)]) [3 2 5] @
 [1 3 7] 'this-does-not-match
 ("this" || "alternation") 'does-not-match-either
 [11 13 17] "this matches exactly"
 (l && two? l) 'this-guard-matches
 (11 . 13 . 17 . _) 'this-prefix-matches)

; language advisories
; - (x) = x: singleton lists are no-ops
; - glued and spaced are different operators: <a is (cap a), (< a) is a partial of <;
;   $x and ($ x) likewise part company for everything but a plain number
; - (+ 2 3 4) = ((+ 2 3) 4) = (5 4) = 1024: no varargs, binary ops are binary
; - u + M u = (+ u (M u)): application binds tighter than infix -- and applying a
;   number is the tower (3 2 = 8), so write (u + M) u
; - (1 +) = (+ 1): no sections
; - (map < l) is (< map l): an infix operator by value is parenthesised, (<). the
;   accessor is cap -- and love orders across kinds, so the misread answers 0 in silence
; - 3 / 2 = 1.5 && 3 // 2 = 1: / returns a float, use // for int
; - (-17 % 8) = -1: % and // truncate toward zero; hand-roll floor-mod
; - (: a b  b 5 ..) is ";; missing b": a value binding sees only EARLIER siblings, a
;   lambda body sees later ones too. same split when a module file bakes -- `name value`
;   runs at bake, `(name args)` defers
; - a mid-letrec check must bind: `_ (test ..)`. bare `(test ..)` is define-sugar,
;   so a false one never runs and passes in silence. `test` is the harness macro
;   (test/00-init.l: records and carries on); `assert` is post.l's, and it scares

; the working vocabulary (verified in-tree)
; - (show x) prints-to-string; puts/putc write; putx prints a form
; - sort orders numbers, symbols, strings, and lists; rev, tally (#), elem, map
; - tablets: {} makes, (pin t k v) mutates AND answers t (so foldl builds one),
;   (peep t k d) reads with default, t k = peep t k () ; (keys t) is UNSORTED -- sort before
;   walking or answers drift
; - strings and lists index by application: "abc" 0 = 97, [1 2 3] 1 = 2
; - charm? is number predicate; (show 'sym) spells a symbol
; - cap/cup are total: <() = >() = (); (= a b) across types answers 0, never dies
; - trays (@(..), iota): every numeric word is elementwise with broadcast, = and != too;
;   a whole question is a reduction -- aall/aany of a mask, net/prod/amax/amin of a tray --
;   and max/min are the binary pair. abs of a tray is its norm; floor and int take a float
;   tray to an int tray; peep by a tray of indices gathers, a miss the default

; booleans
; the exact boolean values are {0,1}. however any value can be
; considered boolean if it occurs as a ? predicate. a value is
; true in this situation iff the real part of its net is positive,
; where net is a built in function that reduces any value to a
; complex number. there are lots of ways to state this in love
; here are some equations for all x:
(x \ ?x = bit x = re (net x) > 0)
; where the basic operation net is a complex sum defined for all love types.
(? 1 2 3)  ; 2 ; this predicate succeeds
(? 0 2 3)  ; 3 ; this predicate fails
(-1 ? 2 3) ; 3 ; infix ? is idiomatic ternary syntax
; compound data are summed over their parts and the truth value is the sign.
(? '(1 -0.5) 'yea 'nae) ; yea
(? '(1 -1.5) 'yea 'nae) ; nae
```

## the lanes a change owes

`make test` is the fast gate, and every change runs it. Beyond it, a change owes the lanes of the files it touches, not of what it meant to change. A branch that gates only its own lanes is how a union goes red.

- `src/apps/kore/*` -> `test_kore` `test_hostnif`
- `src/apps/lush.l`, `src/apps/cook.l`, `src/apps/bee.l` -> `test_hostnif`
- `src/love/snap.c`, `src/love/image.c`, `Makefile`, `src/tools/hotbake.sh` -> `test_ccwarn` `test_hdiff` `test_inle`
- a crewfiles member, or anything else baked -> `test_fixpoint` `test_bakerep`, and `make hotprof` to write `src/tools/hot.prof` again (bakerep fails while it is stale)
- `src/apps/moon/*` -> `test_moon` `test_clay` `test_cca64` `test_ccrv64` `test_ccwasm` `test_ccthumb1` `test_ccthumb2` `test_fixpoint`
- `src/love/holo/*` -> `test_holo` `test_as`
- `src/apps/sb/*` -> `test_sb`
- `src/apps/hearts/*` -> `test_hearts`
- `src/apps/player/mpd.l` -> `test_mpd` (needs mpd, mpc and flac on the box)

`test_slow` runs last, on the exact tree that lands. The `test_cc%` lanes are pattern rules in `test/test.mk`, so grepping for `^test_cc...:` misses them.

## the machine is shared

Several sessions gate on one box. Two makes in one `out/` race, and a box short of memory reaps gates. A heavy lane waits its turn through `src/apps/locks.l` (`locks-run`; bee's `lock_*` tools):

- heavy: `test_slow` `test_extra` `test_inle` `test_kernel_%` `test_gcstress` `test_boards` `test_hearts` `moon-flex` `moon-bison`, and a `make out/love` from a clean `out/`
- one make at a time in an `out/`: an exclusive lock named by its path
- a lane that runs on another box takes that box's slot, not a heavy one. the boxes are bee's host registry, `~/.love/etc/bee/hosts` (`love bee --hosts`; doc/bee.md, HOSTS): each host's reach, caps, slots and facts, each slot an exclusive lock `host-NAME-N`. the a64 kernel lane boots under kvm on a `kvm-a64` host; the a64 lanes' binaries (`test_cca64` `test_cts_a64` `test_raw_a64` `test_softfp`'s a64 leg, the BSD lanes' local half, `test_love_a64`) are built here, run one batch per ssh by `love bee --on a64-exec`, and compared here; `test_kernel_vmx` boots on a `vt-x` host, in `test_extra` only; the BSD lanes find their boxes by `freebsd-x64` and its kin. with no host the kernel lane runs tcg here, and is heavy, and the binaries run under qemu-aarch64

## the merge queue

Take part in a merge queue only through bee's tools: as a bee agent, or from Claude Code through the tree's `.mcp.json`, which loads `love bee --mcp` (`mcp__bee__queue_row`, `queue_lead`, `queue_land`, `queue_landed`, `inbox`). Never edit a queue by hand. The protocol is written once in `doc/bee.md`, THE MERGE QUEUE, and each queue's header states it.

When the queue is long (two or more rows waiting or gating, or more heavy-lock waiters than slots), fold, don't line up. One owner's branches join as one union that gates once, and each branch runs only its light lanes.

Start a Claude Code session in this tree as `claude --dangerously-load-development-channels server:bee` (a resume too), so bee's mail wakes it when idle; `doc/bee.md` says how. Without the flag, mail waits for the session's next bee tool call. To bring a session back after a restart or a crash, `love bee --resume NAME` (the names: `love bee --resume`) relaunches it under its own name, ringing.

After a landing that changes bee, every live session restarts at its next convenient point: between tasks, never mid-gate, in the same directory. bee says so itself, in the release note and when its binary is replaced.
