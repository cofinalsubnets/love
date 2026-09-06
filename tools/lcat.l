; lcat: the love source a frontend bakes, laid as C. two doors:
;
;   love tools/lcat.l          > out/lib/baked.h   the full love's one header, the roster below
;   love tools/lcat.l FILE.l   > FILE.h            one file as one C string literal (the ports, test/front)
;
; each top-level form is re-printed via show (canonical), the forms are joined into one
; string, and that string is minified -- a space is dropped wherever removing it does not
; change how the reader parses. The boundary test is empirical, not a hardcoded delimiter
; set: the left token (bytes since the last HARD boundary) and the whole next form are
; re-parsed with and without the space, and the space is redundant iff both spellings
; yield the same datums (`o(` reads the same as `o (`, but `-5` and `- 5` do not, and
; `two? s` must keep its space -- `two?s` is one name token). Two things make this
; reader-change-proof, where a count over one byte was not: the probe reaches the whole
; next form (so a quote sees its operand -- `ev'ev` vs `ev 'ev`), and it compares the
; datums themselves, not a count (a re-tokenization can keep the count yet change the
; parse). Spaces inside a string literal are data and never touched.
;
; the baked header lays every text DEFLATED, so a blob the binary reads once and only at
; bake time costs its compressed size in .rodata: SYM the bytes (sizeof - 1 their length),
; SYM_raw what they inflate to. every byte goes out as a three-digit octal escape -- always
; three, so a following digit cannot extend it, and no byte value needs a case of its own.

(: (die m) (say err ("lcat: " + m + "\n"), quit 1)
   (s2cl s) ((: (g i) (i < #s ? (s i . g (i + 1)))) 0)  ; string -> charlist
   ; the datums readable from s (stop on the eof sentinel or an incomplete form,
   ; which read signals by returning the port itself) -- the full forms, compared
   ; structurally, not just counted: a re-tokenization can preserve the count yet
   ; change the parse (name'(a b) and name '(a b) both read two datums).
   (datums s) ((: (g x a) (: r (sound x) (two? r ? (g >r (<r . a)) (rev a)))) s 0)
   ; the next complete form of a charlist, re-shown; 0 if none reads cleanly.
   (form1 cs) (: r (sound cs) (two? r ? (show <r) 0))
   ; a hard token boundary: whitespace, delimiters, string quote, comment, and
   ; the value-surface chars that reach across a space (' ` each skip whitespace
   ; to find their datum, so nothing a token could span survives them).
   ; @ # ~ are not here, though they are sigils: those three read glue, so a
   ; token can end at one (fs@) and gluing can change the parse (@ x is the symbol
   ; @ then x, @x is (tuple x); '# is the sigil's own name, '#x the run around x).
   ; resetting the left context there would hide the very byte the probe has to
   ; weigh -- and opb? then keeps their space outright.
   ; a chain, not a member? over a list: this runs on every byte of every text.
   (hardb c) (? (c = 32) 1 (c = 10) 1 (c = 9) 1
                (c = 40) 1 (c = 41) 1 (c = 91) 1 (c = 93) 1 (c = 123) 1 (c = 125) 1
                (c = 34) 1 (c = 59) 1 (c = 39) 1 (c = 96) 1 (c = 44) 1
                0)
   ; an operator-run byte: punct that is neither a hard boundary nor a name
   ; char -- \ included, though it never fuses. under the valence law a run
   ; glued to a datum is monadic, and the probe below tests in isolation --
   ; head position, where fusion is suppressed -- so a space between a run's
   ; end and a datum start is kept conservatively: it is semantic mid-list.
   (opb? c) (? (hardb c) 0
               (48 <= c <= 57) 0
               (65 <= c <= 90) 0
               (97 <= c <= 122) 0
               (c = 95) 0
               1)
   (dstart? b) (? (b = 41) 0 (b = 93) 0 (b = 125) 0 (b = 59) 0
                  (b = 32) 0 (b = 10) 0 (b = 9) 0
                  1)
   ; ctx = the bytes since the last hard boundary, reversed (the left token);
   ; cs = the remaining charlist after the space. the space is redundant iff
   ; lt+rt re-parses to the same datums as lt rt, where rt is the whole next
   ; form -- a quote reaches its operand, so any lexer rule is honoured, not
   ; just today's. the opb? clause still keeps an operator-then-datum space:
   ; the probe reads in isolation (head position, fusion off) but the run is
   ; monadic mid-list.
   (redundant? ctx cs) (? (two? ctx && opb? <ctx && dstart? <cs) 0
                          (: lt (string (rev ctx)) rt (form1 cs)
                             (rt ? (datums (lt + rt) = datums (lt + " " + rt)) 0)))
   ; the minified text of a source. a torn input dies loudly: a header silently short
   ; of its last forms is the empty-lcat disaster wearing a subtler face -- the build
   ; would take it as fresh and fail somewhere else.
   (minify src)
    (: acc ((: (g acc cl first)
              (: r (sound cl)
                 (? (two? r) (g (first ? (show <r) (acc + " " + show <r)) >r 0)
                    (r = 'torn) (die "unfinished form in input")
                    acc)))
            "" src 1)
       ; walk acc: drop redundant spaces (outside string literals). ctx = bytes since
       ; the last hard boundary (reversed); instr = inside a "..." literal (where \
       ; escapes); out = the survivors, reversed.
       (g cs ctx instr out)
        (? (two? cs)
           (: c <cs
              (? instr
                 (? (c = 92) (g >>cs 0 1 (<>cs . c . out))
                    (g >cs 0 (c = 34 ? 0 1) (c . out)))
                 (? (c = 32)
                    (? (redundant? ctx >cs)
                       (g >cs ctx 0 out)                          ; drop the space; ctx keeps accruing
                       (g >cs 0 0 (c . out)))                     ; keep it: a real boundary
                    ; a terminal ' is a prime, not a quote: `x'` is one name, so the byte
                    ; belongs to the left token and the space after it is load-bearing. Only a
                    ; ' at token start reaches across whitespace for its datum. Reading it as a
                    ; boundary either way emptied ctx, so `redundant?` probed "" against the
                    ; next form -- always equal -- and ate the space in `(ov-look env' x)`.
                    (g >cs (hardb c && (c != 39 || atom? ctx) ? 0 (c . ctx))
                       (c = 34) (c . out)))))
           (string (rev out)))
       (g (s2cl acc) 0 0 ()))
   ; a string as the body of a C literal: \n, \\ and \" escaped, nothing else
   (clit s) ((: (g cs out)
               (? (two? cs)
                  (: c <cs (g >cs (? (c = 10) (110 . 92 . out)
                                     (c = 92 || c = 34) (c . 92 . out)
                                     (c . out))))
                  (string (rev out))))
             (s2cl s) ())
   ; a deflated string as octal-escaped C rows, 20 bytes to a row
   (oct c) [92 (48 + c // 64) (48 + c // 8 % 8) (48 + c % 8)]
   (row s i j acc) (? (j < i) acc (row s i (j - 1) (oct (s j) + acc)))
   (zrows s i n)
    (n <= i ? 0
     (: e (n < i + 20 ? n (i + 20))
      (say out ("\"" + string (row s i (e - 1) ()) + "\"\n"), zrows s e n)))

   ; the boot files by name; the glaze's and holo's live beside src/core/boot
   home {'emit "src/core/boot/glaze/" 'auto "src/core/boot/glaze/"
         'hook "src/core/boot/glaze/" 'walk "src/core/boot/glaze/"
         'holo "src/core/holo/" 'x64 "src/core/holo/" 'a64 "src/core/holo/" 'rv64 "src/core/holo/"}
   (path n) (peep home n "src/core/boot/" + show n + ".l")
   (slurp-file p) (: q (open p "r") _ (!q ? (die ("cannot open " + p))) s (slurp q) _ (close q) s)
   ; a file's minified text, once: holo rides four blobs
   cache {}
   (file n) (: s (peep cache n ())
               (? (string? s) s (: m (minify (slurp-file (path n))) _ (pin cache n m) m)))

   ; the baked source (src/host/cats.c), row by row: a string lays as it is -- the arch
   ; guards -- and a list is [symbol how items], how being z (deflated, with the _raw twin)
   ; or t (a plain literal). an item is a symbol, one boot file by name, or a string, glue
   ; laid between two files. a group is ONE text: ai_evals_ reads a text whole before its
   ; first form runs, so the grouping here is part of the boot's meaning.
   rows
    [['ai_src_cli 't ['cli]]                              ; the CLI driver, evaluated by every unbaked session
     ['ai_cat_egg_z 'z ['egg]]
     ['ai_cat_p1_z 'z ['p1]]
     ['ai_cat_prel_z 'z ['prel " " 'ev]]                  ; prel carries ev's half spliced after its own
     ['ai_cat_post_z 'z ['post]]
     ; the module registry, in dependency order: overlay's body reads (from 'kanren ..) as
     ; it registers, so the blobs go a, holo, b. holo rides a blob per arch because the
     ; backend does; an arch with no backend registers neither, the one shape that leaves
     ; AiCatModsH unset.
     ['ai_cat_mods_a_z 'z ['rng 'q 'glob 'kanren 'overlay 'uu]]
     "#if defined(__x86_64__)" "#define AiCatModsH 1"
     ['ai_cat_mods_h_z 'z ['holo 'x64]]
     "#elif defined(__aarch64__)" "#define AiCatModsH 1"
     ['ai_cat_mods_h_z 'z ['holo 'a64]]
     "#elif defined(__riscv)" "#define AiCatModsH 1"
     ['ai_cat_mods_h_z 'z ['holo 'rv64]]
     "#endif"
     ['ai_cat_mods_b_z 'z ['bao 'verbs 'scan 're 'peg]]
     ; the glaze, one text: emit.l (the native emitter) then auto.l (ev's source
     ; recognizer, which reads emit's names bare), so the order here is the module and the
     ; pair declares it. holo leads because the glaze folds `assemble` at its own compile;
     ; orth and the ala creation hook trail it, and hook.l leaks natjit/fires/fired?/bake
     ; so it stays outside. not a module blob: an unglazed build must not pay for it.
     "#ifdef AiGlazed"
     ['src_glaze_z 'z ["(use 'holo)(module 'glaze " 'emit 'auto ")"
                       "(: ev (from 'glaze 'ev) member? (from 'glaze 'member?))"
                       'hook 'walk 'holo 'x64 'a64]]
     "#endif"]
   (text items) (foldl (\ a i (a + (string? i ? i (file i)))) "" items)
   (lay-z sym s)
    (: z (deflate s)
       _ (string? z ? 0 (die ("deflate refused " + sym)))
       _ (say out ("static unsigned char const " + sym + "[] =\n"))
       _ (zrows z 0 #z)
       (say out (";\nstatic uintptr_t const " + sym + "_raw = " + show #s + ";\n")))
   (lay-t sym s) (say out ("static char const " + sym + "[] =\n\"" + clit s + "\";\n"))
   (lay-row r)
    (? (string? r) (say out (r + "\n"))
       (: sym (show (r 0)) s (text (r 2))
          (? ((r 1) = 'z) (lay-z sym s) (lay-t sym s)))))

; argv leads with this script's own path: one file after it is the one-file door
(: as >argv
   (? (two? as) (say out ("\"" + clit (minify (slurp-file <as)) + "\"\n"))
      (: _ (say out "/* generated by tools/lcat.l -- do not edit. AiGlazed is the includer's word. */\n")
         (map lay-row rows))))
