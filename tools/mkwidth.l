; tools/mkwidth.l -- the column-width table of post.l's 'text module, off the unicode data.
;   love tools/mkwidth.l UCD-DIR
; UCD-DIR holds EastAsianWidth.txt UnicodeData.txt HangulSyllableType.txt and
; DerivedCoreProperties.txt, as https://www.unicode.org/Public/VERSION/ucd/ serves them. the rules are glibc's (localedata/unicode-gen/utf8_gen.py),
; the ones a host terminal keeps: W and F are 2; Mn, Me, NSM, conjoining jamo V and T and
; Default_Ignorable_Code_Point are 0; U+00AD stays 1; U+115F, U+3248..U+324F and
; U+4DC0..U+4DFF are 2; the rest is 1. prints the tray, each entry cp * 4 + w opening a
; run of width w that lasts to the next entry.
(borrow 'posix)
(: (rd p) (: q (open p "r") (hot? q ? (: s (slurp q) (close q, (s + ""))) (die ("cannot read " + p))))
   (die m) (: _ (say err $ "mkwidth: " + m + "\n") (quit 1))
   (hex s) (foldl (a \ c \ a * 16 + hexv c) 0 (chars s))
   ; a data line as its fields, the comment gone and each field cut to its first word
   (fields ln) (map (f \ (: w (words f) (two? w ? <w ""))) (split ";" <(split "#" ln)))
   (span f) (: p (split ".." f) [(hex <p) (hex (two? >p ? <>p <p))])
   ; every data line of file as its fields
   (rows file) (filter (r \ two? r && #<r) (map fields (lines (rd (dir + "/" + file)))))
   (fill t lo hi w) (? (hi < lo) t (fill (pin t lo w) (lo + 1) hi w))
   (fillf t f w) (: s (span f) (fill t (s 0) (s 1) w))
   dir (two? >argv ? <>argv (die "usage: love tools/mkwidth.l UCD-DIR"))
   t {}
   _ (each (rows "EastAsianWidth.txt")
       (r \ (r 1 = "W" || r 1 = "F") ? (fillf t <r 2) 0))
   _ (each (rows "UnicodeData.txt")
       (r \ (r 2 = "Mn" || r 2 = "Me" || r 4 = "NSM") ? (pin t (hex <r) 0) 0))
   _ (each (rows "HangulSyllableType.txt")
       (r \ (r 1 = "V" || r 1 = "T") ? (fillf t <r 0) 0))
   _ (each (rows "DerivedCoreProperties.txt")
       (r \ r 1 = "Default_Ignorable_Code_Point" ? (fillf t <r 0) 0))
   _ (pin t 173 1)
   _ (fill t 4447 4447 2)
   _ (fill t 12872 12879 2)
   _ (fill t 19904 19967 2)
   ; the runs: an entry wherever the width changes, a gap in the keys reading as 1
   (go ks prev pw acc)
    (? (one? ks) (rev (pw = 1 ? acc ((prev + 1) * 4 + 1 . acc)))
       (: k <ks w (t k)
          gap (k > prev + 1 && pw != 1)
          acc1 (gap ? ((prev + 1) * 4 + 1 . acc) acc)
          pw1 (gap ? 1 pw)
          (go >ks k w (w = pw1 ? acc1 (k * 4 + w . acc1)))))
   runs (go (sort (keys t)) -1 1 [1])
   ; a line of entries at a time, ninety-odd columns wide
   (lay l ln) (? (one? l) (puts (ln + ")\n"))
                 (: s (show <l)
                    (#ln + #s > 92 ? (puts (ln + "\n"), lay l "     ")
                       (lay >l (ln + (ln (#ln - 1) = 32 || ln (#ln - 1) = 40 ? "" " ") + s)))))
   (: _ (puts ("; " + show #runs + " runs\n")) (lay runs "   @(")))
