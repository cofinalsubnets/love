; src/apps/hearts/kcc.l -- the kernel's compiler under hearts: kbuild's clang line, a unit compiled
; by mooncc (and its asm by holo) in mooncc's spelling, and clang's own line for the rest. a probe,
; a -E or -S, another target (the arm32 vdso) and a unit mooncc refuses or outruns go to clang, the
; last two logged to $HEARTS_KCC_LOG as `target<TAB>why`, so the build says what is still clang's.
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
   srcs (filter src? av)
   tg (after "-o")
   tgt (filter (a \ starts? a "--target=") av)
   (clang _) (: p (spawn ("clang" . av)) (quit (charm? p && 0 <= p ? (wait p) 127)))
   (moon? _) (elem "-c" av && two? srcs && string? tg && (atom? tgt || <tgt = "--target=aarch64-linux-gnu"))
   ; mooncc names no compiler family, and the kernel refuses one it does not know: it is lent the
   ; pinned clang's, the one the .config was made for. it predefines true, false and bool, which
   ; linux/stddef.h declares; it has __int128 but not clang's typedefs; and the overlay answers
   ; _THIS_IP_ without &&label, which mooncc lacks
   ident ["-D__clang__=1" "-D__clang_major__=22" "-D__clang_minor__=1" "-D__clang_patchlevel__=8"
          "-D__GNUC__=4" "-D__GNUC_MINOR__=2" "-D__GNUC_PATCHLEVEL__=1" "-U" "true" "-U" "false" "-U" "bool"
          "-D__uint128_t=unsigned __int128" "-D__int128_t=__int128" "-I" (here + "/overlay")]
   ; flags mooncc refuses that change nothing it lays: the endianness and target it already has,
   ; and an -march for the assembler
   (drop? a) (a = "-mlittle-endian" || starts? a "--target=" || starts? a "-Wa,-march=")
   ; clang's words -> [mooncc's words, the -include headers]; the source and -o are laid apart
   (spell ws a inc)
    (? (atom? ws) [(rev a) (rev inc)]
       (: x <ws  r >ws
          (? (x = "-c" || drop? x || x = <srcs) (spell r a inc)
             (x = "-o") (spell >r a inc)
             (x = "-include" && two? r) (spell >r a (<r . inc))
             (x = "-isystem" && two? r) (spell >r (<r . "-I" . a) inc)
             (elem x ["-I" "-D" "-U"] && two? r) (spell >r (<r . x . a) inc)
             (spell r (x . a) inc))))
   (log why) (getenv "HEARTS_KCC_LOG" @ f
               (string? f ? (cite 'posix 'open f "a" @ h (hot? h ? (say h (tg + "\t" + why + "\n"), cite 'posix 'close h) 0)) 0))
   (first s) (filter (l \ 0 < #l) (lines s) @ () "" l <l)
   (? !(moon? 0) (clang 0)
      (: sp (abs <srcs)
         s (spell av () ())
         ; -include as a wrapper that includes each header and then the source, beside the object
         w (? (atom? (s 1)) sp
              (: f (tg + ".kcc" + snip sp (#sp - 2) #sp)
                 _ (uwrite f (join "" (map (h \ "#include \"" + h + "\"\n") (s 1)) + "#include \"" + sp + "\"\n"))
                 f))
         r (hark (["sh" "-c" "\"$@\" 2>&1" "kcc" love "timeout" "900" love "mooncc" "-t" "a64" "-c"]
                  + ident + <s + (two? (s 1) ? ["-I" (dir sp)] ()) + ["-o" tg w]))
         (? (two? r && <r = 0) (quit 0)
            (: _ (log (? (two? r && <r = 124) "timeout 900s"
                         ("rc " + show (two? r ? <r -1) + " " + first (two? r ? >r ""))))
               (clang 0))))))
