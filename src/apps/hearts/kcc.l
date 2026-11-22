; src/apps/hearts/kcc.l -- the kernel's compiler under hearts: kbuild's clang line, a unit compiled
; by mooncc (and its asm by holo) in mooncc's spelling, for a64, x64 and arm32 (the compat vdso),
; and nothing else. a -E that lays a file is mooncc's too, on its line as it stands. a probe, a -S,
; another target and a unit mooncc refuses or outruns fail, the target and the road said; under
; $HEARTS_KCC_CLANG=1 they are clang's instead, on its own line, each that lays a file, a probe's
; aside, logged to $HEARTS_KCC_LOG as `target<TAB>why`. a line that fails is noted in
; $HEARTS_KCC_REFUSED with its words. a probe is mooncc's with or without the knob: a flag it does
; not honour is refused, assembly is holo's, and the version is the one the units are lent.
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
   ; clang only where it is asked for, logged where lg; else the line fails by name
   (clang lg why)
    (? (getenv "HEARTS_KCC_CLANG" = "1")
        (: _ (lg ? (log why) 0) p (spawn ("clang" . av)) (quit (charm? p && 0 <= p ? (wait p) 127)))
       (: t (string? tg ? tg "no target")
          _ (say err "kcc: \(t): \(why): not mooncc's, and clang is not asked (HEARTS_KCC_CLANG=1)\n")
          _ (flush err)
          _ (note "HEARTS_KCC_REFUSED" (t + "\t" + why + "\t" + join " " av))
          (quit 1)))
   ; the target as mooncc's -t, a line naming none being a64
   arch (? (atom? tgt) "a64" (<tgt = "--target=aarch64-linux-gnu") "a64" (<tgt = "--target=x86_64-linux-gnu") "x64"
              (<tgt = "--target=arm-linux-gnueabi") "arm" ())
   (moon? _) ((elem "-c" av || elem "-S" av) && two? srcs && string? tg && string? arch)
   ; mooncc names no compiler family, and the kernel refuses one it does not know: it is lent the
   ; clang's the .config was made for ($HEARTS_CLANG_VERSION, hk-cc's; else the pinned 22.1.8). it
   ; predefines true, false and bool, which linux/stddef.h declares; it has __int128 but not clang's
   ; typedefs; and the overlay answers _THIS_IP_ without &&label, which mooncc lacks
   cv (split "." (getenv "HEARTS_CLANG_VERSION" @ v (string? v && 0 < #v ? v "22.1.8")))
   ident ["-U" "__GNUC__" "-U" "__GNUC_MINOR__" "-U" "__GNUC_PATCHLEVEL__" "-D__clang__=1" ("-D__clang_major__=" + cv 0) ("-D__clang_minor__=" + cv 1) ("-D__clang_patchlevel__=" + cv 2)
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
          (? (x = "-c" || x = "-S" || drop? x || x = <srcs) (spell r a)
             (x = "-o") (spell >r a)
             (x = "-isystem" && two? r) (spell >r (<r . "-I" . a))
             (elem x ["-I" "-D" "-U" "-include"] && two? r) (spell >r (<r . x . a))
             (spell r (x . a)))))
   ; a line appended to the file an environment word names
   (note e l) (getenv e @ f (string? f ? (cite 'posix 'open f "a" @ h (hot? h ? (say h (l + "\n"), cite 'posix 'close h) 0)) 0))
   (log why) (note "HEARTS_KCC_LOG" (tg + "\t" + why))
   (first s) (filter (l \ 0 < #l) (lines s) @ () "" l <l)
   ; a probe lays /dev/null or kbuild's .tmp_ scratch
   (lays? _) (string? tg && tg != "/dev/null" && !(has? tg ".tmp_"))
   (why _) (? (elem "-E" av) "-E" (elem "-S" av) "-S" (string? arch) "not a -c unit" ("target " + <tgt))
   ; a -E lays as clang does with mooncc's own predefines: the kernel's linker scripts match to the byte
   (cpp? _) (elem "-E" av && !(elem "-S" av) && lays? 0 && string? arch)
   ; a probe asks what the compiler takes: a source of nothing or of stdin, or a word about the
   ; compiler itself. mooncc answers each, the kernel's .config saying what it can do
   (ins l) (? (atom? l) () (<l = "-o") (ins >>l) (<l . ins >l))
   probe (ins av @ w (elem "-" w || elem "/dev/null" w))
   (run l) (: p (spawn l) (charm? p && 0 <= p ? (wait p) 127))
   (pfn _) (filter (a \ starts? a "-print-file-name=") av)
   ; assembly on stdin goes by a file, which holo reads by its name
   (asm? _) (after "-x" = "assembler-with-cpp" && elem "-" av)
   (probed _)
    (: lay (lays? 0 ? tg "/dev/null")
       f (asm? 0 ? (hark ["mktemp" "--suffix=.S"] @ r (two? r && <r = 0 ? (first >r) ())) ())
       _ (string? f ? (run ["sh" "-c" "cat > \"$1\"" "kcc" f]) 0)
       (strip l) (? (atom? l) () (elem <l ["-S" "-"] && string? f || <l = "-S") (strip >l)
                    (<l = "-x" && string? f && two? >l) (strip >>l) (<l . strip >l))
       rc (? (elem "-E" av) (run ([love "mooncc" "-t" arch] + ident + spell av () + (string? tg ? ["-o" tg] ())))
             (run ([love "mooncc" "-t" arch "-c"] + ident + spell (strip av) () + ["-o" lay] + (string? f ? [f] ()))))
       _ (string? f ? (hark ["rm" "-f" f]) 0)
       (quit (rc = 0 ? 0 1)))
   (? (elem "--version" av) (: _ (say out ("mooncc, as clang version " + join "." cv + "\n")) _ (flush out) (quit 0))
      (two? (pfn 0)) (: _ (say out (snip <(pfn 0) 17 #<(pfn 0) + "\n")) _ (flush out) (quit 0))
      (probe && string? arch && (elem "-c" av || elem "-S" av || elem "-E" av)) (probed 0)
      probe (quit 1)                                  ; a link asked of the compiler: kcc links nothing
      (cpp? 0)
       (: r (hark (["sh" "-c" "\"$@\" 2>&1" "kcc" love "timeout" "900" love "mooncc" "-t" arch] + filter (a \ !(drop? a)) av))
          (? (two? r && <r = 0) (quit 0)
             (clang 1 ("-E rc " + show (two? r ? <r -1) + " " + first (two? r ? >r "")))))
      !(moon? 0) (clang (lays? 0) (why 0))
      (: sp (abs <srcs)
         r (hark (["sh" "-c" "\"$@\" 2>&1" "kcc" love "timeout" "900" love "mooncc" "-t" arch (elem "-S" av ? "-S" "-c")]
                  + ident + spell av () + ["-o" tg sp]))
         (? (two? r && <r = 0) (quit 0)
            (clang 1 (? (two? r && <r = 124) "timeout 900s"
                        ("rc " + show (two? r ? <r -1) + " " + first (two? r ? >r ""))))))))
