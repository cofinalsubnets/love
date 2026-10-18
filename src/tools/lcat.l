; lcat: the love source a frontend bakes, laid as C. two doors:
;   love src/tools/lcat.l          > out/lib/baked.h   the full love's one header, the roster below
;   love src/tools/lcat.l FILE.l   > FILE.h            one file as one C string literal (the ports, test/front)
; each top-level form is re-shown, the forms joined, and the string minified: a space is
; dropped wherever the reader parses the same without it, tested empirically (`o(` = `o (`,
; but not `-5` and `- 5`, nor `two?s`).
; the baked header lays every text deflated: SYM the bytes, SYM_raw the inflated length,
; every byte a three-digit octal escape so a following digit cannot extend it.

(borrow 'posix)
(borrow 'gz)

(: (die m) (say err ("lcat: " + m + "\n"), quit 1)
   (s2cl s) ((: (g i) (i < #s ? (s i . g (i + 1)))) 0)  ; string -> charlist
   ; the datums readable from s (read answers the port itself at eof or a torn form), whole:
   ; a re-tokenization can keep the count yet change the parse (name'(a b) vs name '(a b)).
   (datums s) ((: (g x a) (sound x @ r (two? r ? (g >r (<r . a)) (rev a)))) s 0)
   ; the next complete form of a charlist, re-shown; 0 if none reads cleanly
   (form1 cs) (sound cs @ r (two? r ? (show <r) 0))
   ; a hard token boundary: whitespace, delimiters, quote, comment, and ' ` , which skip
   ; whitespace to their datum. not @ # ~: those read glue (@ x vs @x), so the probe must
   ; weigh them, and opb? keeps their space outright. a chain, not elem: runs on every byte.
   (hardb c) (? (c = 32) 1 (c = 10) 1 (c = 9) 1
                (c = 40) 1 (c = 41) 1 (c = 91) 1 (c = 93) 1 (c = 123) 1 (c = 125) 1
                (c = 34) 1 (c = 59) 1 (c = 39) 1 (c = 96) 1 (c = 44) 1
                0)
   ; an operator-run byte: punct neither hard nor a name char. a run glued to a datum is
   ; monadic mid-list but the probe reads in head position, so that space is kept.
   (opb? c) (? (hardb c) 0
               (48 <= c <= 57) 0
               (65 <= c <= 90) 0
               (97 <= c <= 122) 0
               (c = 95) 0
               1)
   (dstart? b) (? (b = 41) 0 (b = 93) 0 (b = 125) 0 (b = 59) 0
                  (b = 32) 0 (b = 10) 0 (b = 9) 0
                  1)
   ; ctx: the bytes since the last hard boundary, reversed; cs: the charlist after the
   ; space. redundant iff lt+rt reads the same datums as lt rt, rt the whole next form.
   (redundant? ctx cs) (two? ctx && opb? <ctx && dstart? <cs ? 0
                          (: lt (string (rev ctx)) rt (form1 cs)
                             (rt ? (datums (lt + rt) = datums (lt + " " + rt)) 0)))
   ; the minified text of a source. a torn input dies: a header short of its last forms
   ; would pass as fresh and fail somewhere else.
   (minify src)
    (: acc (sounds src @ 'torn (die "unfinished form in input")
                         fs (foldl (\ a f (a = "" ? (show f) (a + " " + show f))) "" fs))
       ; drop redundant spaces outside literals; instr: inside "..." (\ escapes);
       ; out: the survivors, reversed
       (g cs ctx instr out)
        (two? cs
         ? (: c <cs
              (instr
               ? (c = 92 ? (g >>cs 0 1 (<>cs . c . out))
                    (g >cs 0 (c = 34 ? 0 1) (c . out)))
                 (c = 32
                  ; a space between two strings is never redundant: three quotes open a raw text
                  ? (!(two? out && <out = 34 && two? >cs && <>cs = 34) && redundant? ctx >cs
                     ? (g >cs ctx 0 out)                          ; drop it; ctx keeps accruing
                       (g >cs 0 0 (c . out)))                     ; keep it
                    ; a terminal ' is a prime (`x'` is one name), so the space after it stays; only a
                    ; ' at token start reaches across whitespace
                    (g >cs (hardb c && (c != 39 || atom? ctx) ? 0 (c . ctx))
                       (c = 34) (c . out)))))
           (string (rev out)))
       (g (s2cl acc) 0 0 ()))
   ; a string as the body of a C literal: \n, \\ and \" escaped, nothing else
   (clit s) ((: (g cs out)
               (two? cs
                ? (: c <cs (g >cs (? (c = 10) (110 . 92 . out)
                                     (c = 92 || c = 34) (c . 92 . out)
                                     (c . out))))
                  (string (rev out))))
             (s2cl s) ())
   ; a deflated string as octal-escaped C rows, 20 bytes to a row
   (oct c) [92 (48 + c // 64) (48 + c // 8 % 8) (48 + c % 8)]
   (row s i j acc) (j < i ? acc (row s i (j - 1) (oct (s j) + acc)))
   (zrows s i n)
    (n <= i ? 0
     (: e (n < i + 20 ? n (i + 20))
      (say out ("\"" + string (row s i (e - 1) ()) + "\"\n"), zrows s e n)))

   ; the boot files by name; holo's live beside src/love/boot
   home {'holo "src/love/holo/" 'x64 "src/love/holo/" 'a64 "src/love/holo/" 'rv64 "src/love/holo/"}
   (path n) (peep home n "src/love/boot/" + show n + ".l")
   (slurp-file p) (: q (open p "r") _ (!q ? (die ("cannot open " + p))) s (slurp q) (close q, s))
   ; a file's minified text, once: holo rides four blobs
   cache {}
   (file n) (cache n @ s
               (string? s ? s (minify (slurp-file (path n)) @ m (pin cache n m, m))))

   ; the baked source (cats.c): a string lays as is (arch guards); a list is [symbol items],
   ; laid deflated with its _raw twin, items a boot file by name or glue text. a group is ONE
   ; text: evals_ reads it whole before its first form runs, so grouping is meaning.
   rows
    [['cat_egg_z ['egg]]
     ['cat_prel_z ['prel " " 'ev]]                     ; prel carries ev's half spliced after its own
     ['cat_post_z ['post]]
     ; holo, one blob per arch; an arch with no backend leaves LvCatModsH unset. scan lays a
     ; native kernel through holo at load. every other module is post's.
     "#if defined(__x86_64__)" "#define LvCatModsH 1"
     ['cat_lib_h_z ['holo 'x64 'scan]]
     "#elif defined(__aarch64__)" "#define LvCatModsH 1"
     ['cat_lib_h_z ['holo 'a64 'scan]]
     "#elif defined(__riscv)" "#define LvCatModsH 1"
     ['cat_lib_h_z ['holo 'rv64 'scan]]
     ; wasm is gen's rv64 lane under another writer, so its holo machine is rv64's
     "#elif defined(__wasm__)" "#define LvCatModsH 1"
     ['cat_lib_h_z ['holo 'rv64 'scan]]
     "#endif"
     ; the glaze: glaze.l states its own module wrapper. not a module blob: an unglazed build
     ; must not pay for it.
     "#ifdef LvGlazed"
     ['src_glaze_z ['glaze 'holo 'x64 'a64]]
     "#endif"]
   (text items) (foldl (\ a i (a + (string? i ? i (file i)))) "" items)
   (lay-z sym s)
    (deflate s @ z
       (string? z ? 0 (die ("deflate refused " + sym)),
        say out ("static unsigned char const " + sym + "[] =\n"),
        zrows z 0 #z,
        say out (";\nstatic uintptr_t const " + sym + "_raw = " + show #s + ";\n")))
   (lay-row r)
    (string? r ? (say out (r + "\n"))
       (lay-z (show (r 0)) (text (r 1)))))

; argv leads with this script's path: one file after it is the one-file door
(>argv @ as
   (two? as ? (say out ("\"" + clit (minify (slurp-file <as)) + "\"\n"))
      (say out "/* generated by src/tools/lcat.l -- do not edit. LvGlazed is the includer's word. */\n",
       map lay-row rows)))
