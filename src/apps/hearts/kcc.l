; src/apps/hearts/kcc.l -- the kernel's compiler under hearts: kbuild's clang line, a unit compiled
; by mooncc (and its asm by holo) in mooncc's spelling, for a64, x64 and arm32 (the compat vdso),
; and clang's own line for the rest. a probe, a -E or -S, another target and a unit mooncc refuses
; or outruns go to clang, the last two logged to $HEARTS_KCC_LOG as `target<TAB>why`, so the build
; says what is still clang's.
; usage: love kcc.l CLANG-ARGS..   (hearts lays .hearts/bin/hk-cc over this, as CC)
(borrow 'posix)
(: argv cmdline
   av (drop 2 argv)
   love (selfpath 0)
   (lastsl p) ((: (g i) (i < 0 ? -1 (p i = 47 ? i (g (i - 1))))) (#p - 1))
   (dir p) (lastsl p @ k (k <= 0 ? "." (snip p 0 k)))
   (abs p) (p 0 = 47 ? p (cwd 0 + "/" + p))
   here (dir (abs (argv 1)))
   (after w) (: k (findsub av [w]) (0 <= k && k + 1 < #av ? (av (k + 1)) ()))
   (src? a) (!(starts? a "-") && (ends? a ".c" || ends? a ".S"))
   ; the sources, past an -include's word (the arm32 vdso includes a .c)
   srcs ((: (go l acc) (? (atom? l) (rev acc)
                          (<l = "-include" && two? >l) (go >>l acc)
                          (go >l (src? <l ? (<l . acc) acc))))
         av ())
   tg (after "-o")
   tgt (filter (a \ starts? a "--target=") av)
   (clang _) (: p (spawn ("clang" . av)) (quit (charm? p && 0 <= p ? (wait p) 127)))
   ; the target as mooncc's -t, a line naming none being a64
   arch (? (atom? tgt) "a64" (<tgt = "--target=aarch64-linux-gnu") "a64" (<tgt = "--target=x86_64-linux-gnu") "x64"
              (<tgt = "--target=arm-linux-gnueabi") "arm" ())
   (moon? _) (elem "-c" av && two? srcs && string? tg && string? arch)
   ; mooncc names no compiler family, and the kernel refuses one it does not know: it is lent the
   ; pinned clang's, the one the .config was made for. it predefines true, false and bool, which
   ; linux/stddef.h declares; it has __int128 but not clang's typedefs; and the overlay answers
   ; _THIS_IP_ without &&label, which mooncc lacks
   ident ["-D__clang__=1" "-D__clang_major__=22" "-D__clang_minor__=1" "-D__clang_patchlevel__=8"
          "-D__GNUC__=4" "-D__GNUC_MINOR__=2" "-D__GNUC_PATCHLEVEL__=1" "-U" "true" "-U" "false" "-U" "bool"
          "-D__uint128_t=unsigned __int128" "-D__int128_t=__int128" "-I" (here + "/overlay")]
   ; flags mooncc refuses that change nothing it lays: the endianness and target it already has,
   ; an -march for the assembler, x64's fatal warnings (holo warns of nothing) and its unrelaxed
   ; GOTPCRELX (holo lays none)
   (drop? a) (elem a ["-mlittle-endian" "-Wa,--fatal-warnings" "-Wa,-mrelax-relocations=no"]
              || starts? a "--target=" || starts? a "-Wa,-march=")
   ; clang's words -> mooncc's; the source and -o are laid apart
   (spell ws a)
    (? (atom? ws) (rev a)
       (: x <ws  r >ws
          (? (x = "-c" || drop? x || x = <srcs) (spell r a)
             (x = "-o") (spell >r a)
             (x = "-isystem" && two? r) (spell >r (<r . "-I" . a))
             (elem x ["-I" "-D" "-U" "-include"] && two? r) (spell >r (<r . x . a))
             (spell r (x . a)))))
   (log why) (getenv "HEARTS_KCC_LOG" @ f
               (string? f ? (cite 'posix 'open f "a" @ h (hot? h ? (say h (tg + "\t" + why + "\n"), cite 'posix 'close h) 0)) 0))
   (first s) (filter (l \ 0 < #l) (lines s) @ () "" l <l)
   (? !(moon? 0) (clang 0)
      (: sp (abs <srcs)
         r (hark (["sh" "-c" "\"$@\" 2>&1" "kcc" love "timeout" "900" love "mooncc" "-t" arch "-c"]
                  + ident + spell av () + ["-o" tg sp]))
         (? (two? r && <r = 0) (quit 0)
            (: _ (log (? (two? r && <r = 124) "timeout 900s"
                         ("rc " + show (two? r ? <r -1) + " " + first (two? r ? >r ""))))
               (clang 0))))))
