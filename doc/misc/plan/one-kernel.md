# plan: one kernel, no test face

**THE CLAIM: K_TEST is not a build flag, it is a second kernel.** Twelve
conditional blocks over 268 lines of C, plus thirteen Makefile sites and a
parallel `out/free/<a>-test/` object tree, and what they buy is a machine that
diverges from the shipped one in exactly the three places the shipped one is
least covered: it never walks the ramfs, never wakes an image, and never warms
an egg from carried source. A green corpus therefore says nothing about any of
them. That is not a theory -- a whole-userland failure lived in the warm path
until 2026-09-01 (see "what this buys"), and no gate could see it.

The whole apparatus exists to hand the kernel a corpus it is already carrying.
`dist_drop` is `bench port wasm`, so `test/` rides the source blob: 394 files,
in the ramfs of every shipped kernel. And `k-prog`'s third lane already evals a
`.l` path off that ramfs. Both facts are measured, on the SHIPPED x64 elf:

    -append "test/zz-fin.l"        ;; missing test_get      (read, evaled, right failure)
    kore wc test/spec.l            75679                    (byte-exact off the ramfs)

So the corpus needs no bake, no second odir and no second face. It needs a
driver file and a way to say "run it".

## the map: what each block buys

Five rows are gone from this table already -- rung 1 took the `syswrite` and
`syscall` nifs and `k_sys_nr`, rung 2 the fs source and `ktests[]`, rung 3 the
layer splice. Blocks are named rather than numbered: the numbers moved when they
went.

| block | buys |
|---|---|
| the wake gate | `woke = false` by construction, INSTEAD of the image wake |
| the boot drink | `test/kernel/all.l` through `k-run-file`, INSTEAD of the kore cat and the boot cmdline |
| Makefile | `ksuf`, the `-test` odir, `-DK_TEST -Dai_tco=1`, four gates |

`-Dai_tco=1` is redundant: `src/love.h:39` already defaults it to 1 and the
shipped kernel takes the default.

## the rungs

**Rung 0 -- the exit channel and quit's second room. LANDED 83db7565.**
`k_qemu_exit` was written per arch to carry the corpus verdict out as a process
exit code. Nothing reads it: `tools/ktest.l` decides on the output TEXT and
never touches hark's status half, `kboot.l` is the same shape, and the three
`$?`-after-qemu in the tree are qemu-user gates. It was also miswired --
`test/kernel/kore0.l` pins `(: (quit n) n)` before the cat loads, so zz-fin's
`(quit 1)` was the identity and control fell to `k_qemu_exit(0)`; a failing
corpus asked qemu to exit 0. With it gone the `#ifdef` in the quit door goes
too: unseated is reset on every face, and the corpus answers its own codes
through kore0.l's pin, one door deeper. -41/+4 lines over three files.

**Rung 1 -- the raw-fd lane, finished by subtraction. LANDED.** `syswrite` and `syscall`
existed because the raw-fd lane was half built. `openfd` and `pipe` minted an fd,
`lseek` seeked it (`posix.c:725` names it "the openfd lane -- not ports"), a
second nif closed it -- and nothing read or wrote one. Every port nif in io.c was
`if (iop(Sp[0])) { .. }` falling through to a no-op, `(fputs port s)` even
documented "no-op on misuse", so a charm handed to `say` or `see` was silently
ignored. That hole is the whole reason for a second door. Close it under the
names that already exist and both instruments have nowhere left to be special.

- **`fdclose` folds into `close`. LANDED.** They were complementary halves of
  one operation: `lvm_close` tested the port kind and fell through to a bare
  `ZeroPoint` on a charm; `lvm_shutfd` closed a charm and answered `()` for
  anything else. Shutfd's three lines are close's charm arm now -- a nif retired
  and 41 call sites spelled `close`.
- **the io.c port surface takes a charm as an fd. LANDED.** `see` `say` `put`
  `chug` `slurp`, and `flush` which was already a no-op with nothing to do. Six
  silent no-ops are operations, and `syswrite` is not needed under any name: its
  laws are now `(say fd s)` into a pipe read back through the other end, and
  `(say 4096 s)` swallowed by an absent row without faulting the task. fds 0, 1
  and 2 are not special: a charm that reached `see` by mistake is misuse, and
  refusing the low three to catch it would forbid `say` to stdout by number,
  which is a thing to want.
  The lanes are src/fd.c's, beside `ai_fd_write_all`, and they go at the ROW
  and not at read(2) -- `k_fd_read` folds busy and end into one 0, so a syscall
  read would take an idle pipe for its end. An fd spelled in love stays absolute
  (kmain's seat law), so a raw op is seat-blind where the port lane is not.
  `slurp`'s drain lost its `unsee`: the byte `see` drew goes to the jug instead
  of back to the vessel, which is the same bytes in the same order for a port and
  the only spelling a raw fd can hold, a pushback needing somewhere to live.
- **`stat` takes a charm as an fd. LANDED.** `fstat` without a new name, and
  the contract's `()` for "absence or unreadability" was already the right
  answer for EBADF. `lstat` on a charm is the same thing: an fd names the thing
  itself and no link is in the way. It earns its place twice over -- the `fstat`
  ROW had no love-level caller at all (src/image.c's two are the hosted
  file-load path, and the kernel wakes from memory), so its only exercise was
  the instrument written to exercise it. `(= (stat fd) (stat path))` holds on
  both seats, which is also a law about k_fd_stat and k_statat fabricating the
  same tuple.
- **`lseek` stops normalizing an unknown whence. LANDED.** It read
  `wh == 1 ? SEEK_CUR : wh == 2 ? SEEK_END : SEEK_SET`, so `(lseek fd 0 7)`
  seeked to 0 and reported success. The three are still spelled by name, a
  platform's numbers being its own; a stranger goes down as -1, which no seat
  takes, so the ROW answers EINVAL. A non-charm whence is misuse (-1) like the
  other two operands rather than a quiet SET.

No new nif. `fdclose` went, seven nifs gained a kind and one lost a bug -- the
three lanes those kinds ride are src/fd.c's, where the fd doors already live.

**The subtraction. LANDED.** `syswrite`, `syscall` and `k_sys_nr` are out (-93
lines over kmain.c and sys.c), and `test/kernel/sys.l` with them: 386 lines, 114
of the corpus's assertions.

The file was NOT rewritten in place, which the first draft of this rung expected.
Once the laws are spelled with ordinary nifs they are laws that fs.l, wfs.l and
pipe.l already hold -- wfs.l owns create/mkdir/rmdir/unlink/rename/chdir/chmod/
utime, fs.l owns stat/readdir/lseek/openfd, pipe.l owns the pipe and its
aliases -- so a rewritten sys.l would have been a fourth copy under a header
explaining what it used to be. Its survivors moved to the file whose subject they
are: the row KIND through `(stat fd)` (a file, a directory, a fifo, and `()` for
a row that is not there) and close's EBADF on a stranger row and on a reclose.
`(= (stat fd) (stat path))` replaces the 144-byte cask walk and is the better
law -- it catches a wrong offset through the parse that matters, where reading
the cask only asserted that the offsets are the ones we wrote down.

What went with the instruments is one kind of law: the refusal branches nolibc
cannot reach, and raw wire formats. A dirfd that is not AT_FDCWD, an absolute
path ignoring its dirfd, O_RDWR on a ramfs file, `dup3` src == dst, `pipe2` with
a flag word, `fcntl` with a stranger cmd, UTIME_OMIT, getcwd's ERANGE, the
NULL-pointer EFAULT arms, getdents64's 8-aligned record walk. Every ROW under
those keeps coverage through an ordinary nif -- dup issues fcntl, dup2 issues
dup3, pipe issues pipe2, utime issues utimensat, rmdir issues unlinkat with
AT_REMOVEDIR, readdir issues getdents64, stat issues newfstatat and now fstat --
so what is lost is the argument values those rows refuse, defensive arms
guarding against a caller that does not exist. src/sys.c says so above its
dispatch rather than leaving them looking exercised. getpid's row is the one
casualty: this seat has no getpid nif (love's answers the TASK pid, kmain's own
door), so nothing in the tree reaches it -- nolibc's own C callers still do.

The instrument's claim to be "the syscall seam's one gate" was false, which is
the finding under this rung. Every ordinary nif on this seat bottoms out in a
libc call landing in sys.c's rows, so a green kernel corpus was always saying
the seam is live; `syswrite` said it a second time, louder.

**Rung 2 -- the corpus off the ramfs. LANDED.** The step under it was the fs
SOURCE: the test kernel now links `src.o` like the shipped one, so both inflate
the same blob and walk the same tar. There is one filesystem. `kfs.h`, its list
rule, `tools/lcatfs.l`, `tools/lcatv.l`, `out/lib/ktests.{l,h}` and the `kt`
roster are all gone, and `k_bakes` needs no `#ifdef` because there is nothing to
choose between.

`test/kernel/all.l` is the corpus: it spells its own roster and hands each member
to `reads`, which takes a FILE PORT and so needs no slurp, no tap and no baked
string. kmain names it (`k-run-file`, the same door a `.l` path off the cmdline
takes), so `-append "test/kernel/other.l"` replaces it and the wiring is one line.

The roster is not a file both sides read, which the first draft wanted: nothing
on the Makefile side needs it any more, so the driver globs `test/` the way
mk/common.mk's `t` does -- the same three front-loads, the same exclusions --
and spells the kernel half, which is a dependency order, in place. A new
`test/*.l` is picked up by both without an edit.

It reads FASTER, which was not the point but is the measure: x64 11.78s ->
8.58s, a64 102.6s -> 67.9s. A baked string was one 900 KB allocation walked
as a charlist; a port is a gulp at a time and the member is done with when the
next one opens.

One law moved, exactly the one the trap below named: `(= 2 (tally (readdir "")))`
was true of a filesystem holding `lib/` and `tmp/`. The root now lists the tree's
own top names, so the law says what it was always for -- entries are the distinct
next COMPONENTS, never whole paths.

**Rung 3 -- the layers move into the driver. LANDED.** `(use 'coin) (use 'rng)
(use 'q) (use 'kanren)` left kmain for `all.l`; they are baked modules, so `use`
finds them with no filesystem read, and they now sit beside the only reason they
exist.

This rung's stated payoff was wrong and is worth saying so: the four were already
`#ifdef K_TEST`, so the shipped image never carried a ring, a random stream,
rationals or a unifier. What it buys is one `#ifdef` fewer -- two left in kmain,
`woke = false` and the corpus call -- and a splice that no longer has to be
spelled in C to be reached from love. The falsifier is the uses commented out:
`;; missing rand`, exit 2, so the layers are load-bearing and the corpus says so.

**Rung 4 -- delete K_TEST. LANDED.** `ksuf`, the `-test` odir tree,
`-DK_TEST -Dai_tco=1`, `tools/ccdb.l`'s copy of it, `src/x64_asmops.h`'s last
sentence, and both `#ifdef`s left in kmain. The `k_pie_in` fork reads plainly
now: at the host's own arch project the shipped binary, everywhere else build the
pie.

**ONE GATE PER LANE**, which is what the fork already was and what the gates were
not. The projection wakes the image the binary carries; the pie carries none and
warms the egg. So `test_disk` is the WAKE lane (x64, the projection) and
`test_kernel_a64` is the WARM lane (a64, the pie) -- named in both echo
lines, because the pair is the coverage and a reader should not have to derive
it. Neither lane is a face the artifact does not wear.

The corpus is selected the way anything else is: `-append "test/kernel/all.l"`.
That door already existed -- `k-prog`'s third lane evals a `.l` path off the
ramfs -- so the shipped kernel needed nothing added to run the corpus, which is
the claim at the top of this plan, now demonstrated rather than argued.
`tools/ktest.l` passes the append for the `-kernel` door; firmware carries no
command line, so the ESP gets `love.cmd` beside `love.elf` and the loader reads
it. That cost two fields in `src/uefi_loader.c`'s hand-kept `struct k_boot` copy,
which was a PREFIX of the real one -- `date` and `cmdline` were missing, and a
member the compiler cannot find is how mooncc says so (`cannot compile
'kcmdline' (cause unnamed)`, which is the same face it wears for anything else).

Counts: the wake lane 4923, the warm lane 4907, against 4916 for the deleted test
face. Nothing regressed; the lanes differ because a woken image and a warmed egg
answer a few laws differently, which is the whole reason to run both.

## what this buys

Coverage, and the arc has already paid for the claim. `test_vec` is the only
gate in the tree that boots a WARM kernel -- everything else either projects the
host binary, which wakes a baked image, or builds K_TEST, which carries no
`src.o` to warm from. It was one of the 43 orphans no aggregate reached until
148fdc35, and the first thing it found was a warm a64 kernel that reaches
the shell, answers status ok and prints nothing at all, at `-m 512M` and no
other size from 256M to 4096M. That is the GC placement lottery `tools/ktest.l`
already documents (a major takes a contiguous 2x pool beside the old one). One
kernel means the corpus runs on the ramfs walk, the wake and the warm path, so
that class of hole has a gate over it.

And it removes the last reason the two arches differ in kind rather than in
machine: x64 projects and wakes, a64 builds and warms, and after this
both run the same corpus the same way.

## traps this plan already knows

- **the roster is an ordering, not a set.** `mk/common.mk`'s `t` front-loads
  00-init, spec and uu.l explicitly, and a locale sort would order `uukind*`
  before `uu.l` and run the laws against an unloaded kernel. `test/kernel/all.l`
  front-loads the same three and spells the kernel half, a dependency order, by
  hand -- its own header says so, because a later reader will want to glob it.
- **a member that will not open must be LOUD.** The roster names paths; a typo
  drops a whole file's laws and the gate still counts what is left and goes
  green. `feed` scares on a non-port, and the falsifier is one bad roster entry:
  `;; no-corpus-member "..."`, exit 2.
- **kore0.l's `quit` pin is load-bearing and positional.** It shadows `quit`
  for the REST of the stream, so files before it (00-init, spec, uu) still meet
  the real door -- which now resets. Ordinary assert failures do not quit; only
  `test-strict` (a missing name) and `test_fin` do.
- **a red gate must stay red.** Deleting a verdict channel is exactly the change
  that turns a gate green. Rung 0's falsifier: append `(assert (= 1 2))` to a
  kernel corpus file, confirm `test_disk` reports "1 failed:" and exits 2,
  revert. Run it again at every rung that touches the failure path.
- **`k_semihost_exit` has a second caller.** `test/gate/asmops.c` uses it for
  the clang/mooncc differential; it stays in the header whatever kmain does.
- **the corpus is bigger than the machine at some sizes.** `ktest.l` asks for
  768M, and `test/gate/vec.sh` had to be raised to match (ed4007f7). A merged
  corpus is not smaller; price the margin before assuming a size.
- **K_TEST also picked the fs SOURCE.** Met at rung 2, and the mtime laws it
  warned about held: the archive's dates are milliseconds on the same scale, so
  `fs.l` needed no change there. What moved was the SHAPE -- the root used to
  list two entries and now lists the tree's top names.
