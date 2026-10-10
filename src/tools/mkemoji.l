; src/tools/mkemoji.l -- the emoji tables of the unicode floor (moonlibc's ctype/ucd.c), off the
; unicode data.
;   love src/tools/mkemoji.l UCD-DIR > src/apps/moon/lib/moonlibc/ctype/ucdemoji.h
; UCD-DIR holds emoji/emoji-data.txt and emoji/emoji-variation-sequences.txt, as
; https://www.unicode.org/Public/VERSION/ucd/ serves them. two tables, each entry opening and
; closing runs in turn: cpvs, the characters VS16 gives an emoji style, and cpxp, the
; Extended_Pictographic ones, which a ZWJ joins into the cluster before it.
(borrow 'posix)
(: (rd p) (uread p @ [1 s] (s + "") (die ("cannot read " + p)))
   (die m) (udie 1 ("mkemoji: " + m))
   (hex s) (foldl (a \ c \ a * 16 + hexv c) 0 (chars s))
   (sub? h n) (: (go i) (i + #n <= #h ? (n = snip h i (i + #n) ? 1 (go (i + 1))) 0) (go 0))
   (data file) (filter (ln \ #ln && !(ln 0 = 35)) (lines (rd (dir + "/emoji/" + file))))
   ; a data line's first field as its words
   (seq ln) (words <(split ";" <(split "#" ln)))
   (span f) (split ".." f @ p [(hex <p) (hex (two? >p ? <>p <p))])
   dir (two? >argv ? <>argv (die "usage: love src/tools/mkemoji.l UCD-DIR"))
   vs (map (s \ hex <s @ c [c c])
           (filter (s \ two? >s && <>s = "FE0F")
                   (map seq (filter (ln \ sub? ln "emoji style") (data "emoji-variation-sequences.txt")))))
   xp (map (ln \ span <(seq ln))
           (filter (ln \ split ";" <(split "#" ln) @ f (two? >f && <(words <>f) = "Extended_Pictographic"))
                   (data "emoji-data.txt")))
   ; [lo hi] spans as toggles: each run's first and one past its last, touching runs joined
   (toggles l)
    (: (go l acc) (atom? l ? (rev acc)
                     (: lo <<l hi (<><l + 1)
                        (two? acc && <acc = lo ? (go >l (hi . >acc)) (go >l (hi . lo . acc)))))
       (go (sort l) ()))
   ; a C array, ninety-odd columns a line
   (clay l ln) (atom? l ? (puts (ln + " };\n"))
                  (show <l + (two? >l ? "," "") @ e
                     (#ln + #e > 92 ? (puts (ln + "\n"), clay l "  ") (clay >l (ln + " " + e)))))
   (arr ty nm l) (clay l ("static " + ty + " const " + nm + "[" + show #l + "] = {"))
   (puts "// ucdemoji.h -- the emoji tables, as runs each entry opening or closing in turn: the\n",
    puts "//   characters VS16 gives an emoji style, and the Extended_Pictographic ones. generated\n",
    puts "//   by src/tools/mkemoji.l off unicode's emoji data; do not edit\n",
    arr "uint32_t" "uc_vs" (toggles vs),
    arr "uint32_t" "uc_xp" (toggles xp)))
