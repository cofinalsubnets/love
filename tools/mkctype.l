; tools/mkctype.l -- the character classes and case maps of post.l's 'text module, off the
; unicode data.
;   love tools/mkctype.l UCD-DIR
; UCD-DIR holds UnicodeData.txt and DerivedCoreProperties.txt, as
; https://www.unicode.org/Public/VERSION/ucd/ serves them. the rules are glibc's
; (localedata/unicode-gen/unicode_utils.py): alpha is Alphabetic and every digit past 0-9;
; upper has a lowercase or is Uppercase, lower has an uppercase or is Lowercase or is U+00DF;
; print is named and not a control, Zl Zp or a surrogate (utf-8 cannot carry one); space is
; \t..\r, ' ', Zl Zp and a Zs without <noBreak>; blank is \t and that Zs; cntrl is a control
; or Zl Zp. prints each class as a tray whose entries open and close runs in turn, and each
; case map as runs of start count stride delta.
(borrow 'posix)
(: (rd p) (uread p @ [1 s] (s + "") (die ("cannot read " + p)))
   (die m) (say err ("mkctype: " + m + "\n"), quit 1)
   (hex s) (foldl (a \ c \ a * 16 + hexv c) 0 (chars s))
   (data ln) <(split "#" ln)
   dir (two? >argv ? <>argv (die "usage: love tools/mkctype.l UCD-DIR"))
   ; UnicodeData as rows [lo hi name cat decomp upper lower]; a First/Last pair is one row
   (ud ls acc)
    (? (atom? ls) (rev acc)
       (: f (split ";" <ls) c (hex <f) nm (f 1)
          (? (ends? nm "First>") (: g (split ";" <>ls)
                                   (ud >>ls ([c (hex <g) nm (f 2) (f 5) "" ""] . acc)))
             (ud >ls ([c c nm (f 2) (f 5) (f 12) (f 13)] . acc)))))
   rows (ud (filter (l \ #l) (lines (rd (dir + "/UnicodeData.txt")))) ())
   ; DerivedCoreProperties' ranges for one property
   (dcp prop)
    (catmap (l \ (: f (map strip (split ";" (data l)))
                    (? (two? >f && <>f = prop)
                       (: p (split ".." <f) [[(hex <p) (hex (two? >p ? <>p <p))]]))))
            (lines (rd (dir + "/DerivedCoreProperties.txt"))))
   ; the rows a test passes, as ranges
   (pick ok) (map (r \ [<r <>r]) (filter ok rows))
   (nobreak? r) (starts? (r 4) "<noBreak>")
   (zs? r) (r 3 = "Zs" && !(nobreak? r))
   (zlp? r) (r 3 = "Zl" || r 3 = "Zp")
   (ctl? r) (r 2 = "<control>")
   ; ranges sorted and joined where they touch or overlap
   (merge rs)
    (: (go l acc) (? (atom? l) (rev acc)
                     (two? acc && <l 0 <= <acc 1 + 1)
                      (go >l ([(<acc 0) (max (<acc 1) (<l 1))] . >acc))
                     (go >l (<l . acc)))
       (go (sort rs) ()))
   (toggles rs) (catmap (r \ [<r (<>r + 1)]) (merge rs))
   alpha (cat (dcp "Alphabetic") (pick (r \ r 3 = "Nd" && 57 < <r)))
   upper (cat (dcp "Uppercase") (pick (r \ #(r 6))))
   lower (cat (dcp "Lowercase") (cat [[223 223]] (pick (r \ #(r 5)))))
   print (pick (r \ !(ctl? r) && !(zlp? r) && r 3 != "Cs"))
   space (cat [[9 13] [32 32]] (pick (r \ zlp? r || zs? r)))
   blank (cat [[9 9]] (pick zs?))
   cntrl (pick (r \ ctl? r || zlp? r))
   ; a map's pairs (c . to) as runs [start count stride delta]: a run grows while the delta
   ; holds and the stride keeps
   (maps k) (map (r \ (<r . hex (r k))) (filter (r \ #(r k)) rows))
   (runs ps)
    (: (go l acc)
        (? (atom? l) (rev acc)
           (: c <<l d (><l - c)
              (acc @ ([s n st dd] . more)
                 (? (dd = d && (n = 1 ? (c - s <= 2) (c = s + n * st)))
                    (go >l ([s (n + 1) (n = 1 ? (c - s) st) d] . more))
                    (go >l ([c 1 1 d] . acc)))
                 (go >l [[c 1 1 d]]))))
       (catmap 1 (go ps ())))
   ; a line of entries at a time, ninety-odd columns wide
   (lay l ln) (? (atom? l) (puts (ln + ")\n"))
                 (: s (show <l)
                    (#ln + #s > 92 ? (puts (ln + "\n"), lay l "     ")
                       (lay >l (ln + (ln (#ln - 1) = 32 || ln (#ln - 1) = 40 ? "" " ") + s)))))
   (tray nm l) (puts ("   " + nm + "\n"), lay l "   @(")
   _ (tray "cpalpha" (toggles alpha))
   _ (tray "cpupc" (toggles upper))
   _ (tray "cplowc" (toggles lower))
   _ (tray "cpprint" (toggles print))
   _ (tray "cpspace" (toggles space))
   _ (tray "cpblank" (toggles blank))
   _ (tray "cpcntrl" (toggles cntrl))
   _ (tray "cptou" (runs (maps 5)))
   (tray "cptol" (runs (maps 6))))
