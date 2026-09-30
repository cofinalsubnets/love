; src/tools/fatpack.l -- lay the fat container: one file, every text.
;
;   love src/tools/fatpack.l out arch file [arch file ..]
;
; arch is uname -m's spelling (x86_64, aarch64, ..). the members land at page-aligned block
; offsets behind a one-block #!/bin/sh prefix that picks the machine's member, lays it under
; ~/.love/fat once (named by the members' sha), and execs it. deterministic: same members in,
; same bytes out. the distributed bytes stay immutable; a bake belongs to the extraction.

(borrow 'posix)
(: (fp-die m) (udie 1 ("fatpack: " + m))
   (fp-read p) (uread p @ [1 s] [1 (s + "")] ())
   (fp-write p s) (: q (open p "w") (!(hot? q) ? (fp-die ("cannot write " + p)), say q s, close q))
   bs 4096
   (fp-blocks n) ((n + bs - 1) // bs)              ; // outranks +, so the sum keeps its parens
   (fp-pad n) ("\x00" * (fp-blocks n * bs - n))
   ; the members' sha, 16 hex -- the cache name's content half
   (fp-id16 h) (: (go i a) (i < 16 ? (go (i + 1) (a + string (h i))) a) (go 0 ""))
   ; `uname -m` is not the ISA word (amd64 on the BSDs, arm64 on freebsd), so each case arm
   ; takes every spelling of its ISA, common.mk's table. an arch with no row would refuse
   ; a text the prefix is carrying.
   fp-unames '((x64 "x86_64|amd64") (a64 "aarch64|arm64") (rv64 "riscv64"))
   (fp-uname arch)
    (assoc (nom arch) fp-unames @ r
       (two? r ? (r 1) (fp-die ("no uname spelling for " + arch))))
   ; (arch size) -> one case arm; b/n in blocks, s the exact byte count
   (fp-arm arch b n s)
    (fp-uname arch + ") b=" + show b + " n=" + show n + " s=" + show s + ";;\n")
   (fp-prefix id arms)
    ("#!/bin/sh\n"
     + "# love -- one file, every text\n"
     + "m=$(uname -m)\ncase \"$m\" in\n" + arms
     + "*) echo \"love: no text aboard for $m\" >&2; exit 2;;\nesac\n"
     + "d=\"${HOME:-/tmp}/.love/fat\"\n"
     + "mkdir -p \"$d\" 2>/dev/null || d=\"${TMPDIR:-/tmp}\"\n"
     + "c=\"$d/love-" + id + "-$m\"\n"
     + "if [ ! -x \"$c\" ]; then\n"
     + "  dd if=\"$0\" of=\"$c.$$\" bs=" + show bs + " skip=$b count=$n 2>/dev/null || exit 3\n"
     + "  head -c \"$s\" \"$c.$$\" > \"$c.h.$$\" && chmod +x \"$c.h.$$\" && mv \"$c.h.$$\" \"$c\"\n"
     + "  rm -f \"$c.$$\"\nfi\n"
     + "exec \"$c\" \"$@\"\n")
   ; args -> ((arch . bytes) ..), in argv order (the order is the make rule's, fixed)
   (fp-members l)
    (? (atom? l) ()
       (atom? >l) (fp-die "ARCH with no FILE")
       (fp-read <>l @ g
          (atom? g ? (fp-die ("cannot read " + <>l)), (<l . <>g) . fp-members >>l)))
   (fp-main av)
    (: _ (#av < 3 ? (fp-die "usage: fatpack OUT ARCH FILE [ARCH FILE ..]"))
       out <av
       ms (fp-members >av)
       id (fp-id16 (sha256 (foldl (a \ m \ a + >m) "" ms)))
       ; lay the arms and the body: member k starts at block 1 + blocks-before-it
       arms (: (go l b) (atom? l ? ""
                 (#><l @ n (fp-arm <<l b (fp-blocks n) n + go >l (b + fp-blocks n))))
               (go ms 1))
       pre (fp-prefix id arms)
       _ (bs < #pre ? (fp-die "prefix outgrew its block"))
       body (foldl (a \ m \ a + >m + fp-pad #>m) (pre + fp-pad #pre) ms)
       (fp-write out body,
        say out $ "FAT\t" + out + " (" + show #ms + " texts, "
                  + show #body + " bytes, id " + id + ")\n"))
   (fp-main >argv))
