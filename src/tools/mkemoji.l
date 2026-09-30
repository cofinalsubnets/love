; src/tools/mkemoji.l -- the emoji tables of post.l's 'text module and of quay, off the unicode data.
;   love src/tools/mkemoji.l UCD-DIR       the trays, for post.l
;   love src/tools/mkemoji.l UCD-DIR c     the same as C, src/love/quay/cpemoji.h
; UCD-DIR holds emoji/emoji-data.txt and emoji/emoji-variation-sequences.txt, as
; https://www.unicode.org/Public/VERSION/ucd/ serves them. two tables, each entry opening and
; closing runs in turn: cpvs, the characters VS16 gives an emoji style, and cpxp, the
; Extended_Pictographic ones, which a ZWJ joins into the cluster before it. one tool laying
; both is what keeps 'text's clusters and quay's ?2027 ones the same.
(borrow 'posix)
(: (rd p) (uread p @ [1 s] (s + "") (die ("cannot read " + p)))
   (die m) (udie 1 ("mkemoji: " + m))
   (hex s) (foldl (a \ c \ a * 16 + hexv c) 0 (chars s))
   (sub? h n) (: (go i) (? ((i + #n) <= #h) (? (n = snip h i (i + #n)) 1 (go (i + 1))) 0) (go 0))
   (data file) (filter (ln \ #ln && !((ln 0) = 35)) (lines (rd (dir + "/emoji/" + file))))
   ; a data line's first field as its words
   (seq ln) (words <(split ";" <(split "#" ln)))
   (span f) (: p (split ".." f) [(hex <p) (hex (two? >p ? <>p <p))])
   dir (two? >argv ? <>argv (die "usage: love src/tools/mkemoji.l UCD-DIR [c]"))
   c? (two? >>argv && <>>argv = "c")
   vs (map (s \ : c (hex <s) [c c])
           (filter (s \ two? >s && <>s = "FE0F")
                   (map seq (filter (ln \ sub? ln "emoji style") (data "emoji-variation-sequences.txt")))))
   xp (map (ln \ span <(seq ln))
           (filter (ln \ (: f (split ";" <(split "#" ln)) (two? >f && <(words <>f) = "Extended_Pictographic")))
                   (data "emoji-data.txt")))
   ; [lo hi] spans as toggles: each run's first and one past its last, touching runs joined
   (toggles l)
    (: (go l acc) (? (atom? l) (rev acc)
                     (: lo <<l hi (<>(<l) + 1)
                        (? (two? acc && <acc = lo) (go >l (hi . >acc)) (go >l (hi . lo . acc)))))
       (go (sort l) ()))
   ; a line of entries at a time, ninety-odd columns wide
   (lay l ln) (? (atom? l) (puts (ln + ")\n"))
                 (: s (show <l)
                    (#ln + #s > 92 ? (puts (ln + "\n"), lay l "     ")
                       (lay >l (ln + (ln (#ln - 1) = 32 || ln (#ln - 1) = 40 ? "" " ") + s)))))
   (tray nm l) (puts ("   " + nm + "\n"), lay l "   @(")
   ; ..or a C array, the same ninety-odd columns
   (clay l ln) (? (atom? l) (puts (ln + " };\n"))
                  (: e (show <l + (two? >l ? "," ""))
                     (#ln + #e > 92 ? (puts (ln + "\n"), clay l "  ") (clay >l (ln + " " + e)))))
   (arr nm l) (clay l ("static uint32_t const " + nm + "[" + show #l + "] = {"))
   (? c? (: _ (puts "// cpemoji.h -- the emoji tables, as runs each entry opening or closing in turn: the\n")
            _ (puts "//   characters VS16 gives an emoji style, and the Extended_Pictographic ones. generated\n")
            _ (puts "//   by src/tools/mkemoji.l off unicode's emoji data, as post.l's cpvs and cpxp are; do not edit\n")
            _ (arr "cpvs" (toggles vs))
            (arr "cpxp" (toggles xp)))
      (: _ (tray "cpvs" (toggles vs))
         (tray "cpxp" (toggles xp)))))
