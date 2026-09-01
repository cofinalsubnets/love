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
`.l` path off that ramfs. Both facts are measured, on the SHIPPED x86_64 elf:

    -append "test/zz-fin.l"        ;; missing test_get      (read, evaled, right failure)
    kore wc test/spec.l            75679                    (byte-exact off the ramfs)

So the corpus needs no bake, no second odir and no second face. It needs a
driver file and a way to say "run it".

## the map: what each block buys

Two rows are gone from this table already: rung 1 took the `syswrite` and
`syscall` nifs out of kmain, and `k_sys_nr` out of sys.c. Blocks are named
rather than numbered -- the line numbers moved when they went.

| block | buys |
|---|---|
| the fs source | the `lib/*.l` lcatfs bake, INSTEAD of the ramfs untar (83 lines of gz+ustar+symlink walk the corpus never runs) |
| `ktests[]` vs `src_korelist[]` | which corpus is baked in, and which one binds |
| the wake gate | `woke = false` by construction, INSTEAD of the image wake |
| the layer splice | `(use 'coin) (use 'rng) (use 'q) (use 'kanren)` -- the corpus asserts on them, a booting kernel wants none |
| the boot drink | `tests` through `reads`, INSTEAD of the kore cat and the boot cmdline |
| Makefile x13 | `ksuf`, the `-test` odir, `-DK_TEST -Dai_tco=1`, the header swap, the `kt` roster, `ktests.{l,h}`, four gates |

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
  The lanes are src/seat.c's, beside `ai_fd_write_all`, and they go at the ROW
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
three lanes those kinds ride are src/seat.c's, where the fd doors already live.

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

**Rung 2 -- the corpus off the ramfs.** A driver file (`test/kernel/all.l`)
reads a roster, slurps each member and drives `reads` -- the same shape kmain
already spells for the kore cat at 2088-2097, about ten lines of love. The
roster becomes a FILE both the host gate and the driver read, which retires the
`kt` Makefile variable, `out/lib/ktests.{l,h}`, `out/lib/kfs.h` and `lcatfs.l`'s
last caller. The gates invoke it as `-append "test/kernel/all.l"`. Rung 1's
laws ride the same file on both seats.

**Rung 3 -- the layers move into the driver.** `(use 'coin) (use 'rng) (use 'q)
(use 'kanren)` leave kmain for `all.l`; they are baked modules, so `use` finds
them. The shipped image stops carrying a ring, a random stream, rationals and a
unifier it never wanted.

**Rung 4 -- delete K_TEST.** What is left is `ksuf`, the `-test` odir, the
header swap, `-DK_TEST`, `tools/ccdb.l:32`, and the `ifndef K_TEST` half of the
`k_pie_in` fork -- which then reads plainly: at the host's own arch project the
shipped binary, everywhere else build the pie. `src/x86_64_asmops.h:11` loses
its last sentence.

## what this buys

Coverage, and the arc has already paid for the claim. `test_vec` is the only
gate in the tree that boots a WARM kernel -- everything else either projects the
host binary, which wakes a baked image, or builds K_TEST, which carries no
`src.o` to warm from. It was one of the 43 orphans no aggregate reached until
148fdc35, and the first thing it found was a warm aarch64 kernel that reaches
the shell, answers status ok and prints nothing at all, at `-m 512M` and no
other size from 256M to 4096M. That is the GC placement lottery `tools/ktest.l`
already documents (a major takes a contiguous 2x pool beside the old one). One
kernel means the corpus runs on the ramfs walk, the wake and the warm path, so
that class of hole has a gate over it.

And it removes the last reason the two arches differ in kind rather than in
machine: x86_64 projects and wakes, aarch64 builds and warms, and after this
both run the same corpus the same way.

## traps this plan already knows

- **the roster is an ordering, not a set.** `mk/common.mk`'s `t` front-loads
  00-init, spec and uu.l explicitly, and a locale `ls` would order `uukind*`
  before `uu.l` and run the laws against an unloaded kernel. A roster file must
  keep the order; globbing the ramfs must not replace it.
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
- **K_TEST also picks the fs SOURCE.** Rung 2 hands the merged kernel a corpus
  whose stat laws (`test/kernel/fs.l`) read mtimes; the lcatfs bake preserved
  real ones and the ustar walk carries the archive's. Check the laws hold on
  tar mtimes before deleting `kfs.h`.
