; tools/mkpsf.l -- a PSF console font laid as a quay bitmap table (love/quay/*.c).
;   love tools/mkpsf.l FONT.psf REF.c SYMBOL OUT.c [NOTE ..]
; REF.c is a quay table already in the tree: its comments carry the page order,
; // [X] (n), and each cell takes the glyph the PSF's unicode table gives that
; codepoint -- so a font in any encoding lands on cp437 with no table here.
; PSF1 and PSF2 both, 8 pixels wide (a row is one byte, as the C type says).
; a .psf.gz is not read: gunzip it first.
(borrow 'posix)
(: (rd p) (: q (open p "r") (hot? q ? (: s (slurp q) (close q, (s + ""))) ()))
   (die m) (: _ (say err $ "mkpsf: " + m + "\n") (quit 1))
   (hd d) (string (d < 10 ? (48 + d) (87 + d)))
   (hx2 v) ("0x" + hd ((v >> 4) & 15) + hd (v & 15))
   (hx v) (v < 16 ? (hd v) ((hx (v >> 4)) + hd (v & 15)))
   (join sep l) (two? l ? (foldl (\ a x ((a + sep) + x)) <l >l) "")
   (le16 s i) ((s i) | ((s (i + 1)) << 8))
   (le32 s i) ((le16 s i) | ((le16 s (i + 2)) << 16))
   (utf8 s) (: b (s 0)                                        ; the first char's codepoint
             (? (b < 128) b
                (b < 224) (((b & 31) << 6) | (s 1 & 63))
                (b < 240) (((b & 15) << 12) | ((s 1 & 63) << 6) | (s 2 & 63))
                (((b & 7) << 18) | ((s 1 & 63) << 12) | ((s 2 & 63) << 6) | (s 3 & 63))))
   (utf8n b) (? (b < 128) 1 (b < 224) 2 (b < 240) 3 4)        ; and how many bytes it wore
   ; --- the header, as [version glyphs-at cell-bytes height table-at has-table width]
   (head s) (? (((s 0) = 54) && ((s 1) = 4))                                   ; PSF1: 0x0436
                (: n ((s 2) & 1 ? 512 256) h (s 3)
                   [1 4 h h (4 + (n * h)) ((s 2) & 2) 8])
              ((((s 0) = 114) && ((s 1) = 181)) && (((s 2) = 74) && ((s 3) = 134)))  ; PSF2
                (: at (le32 s 8) n (le32 s 16) cn (le32 s 20)
                   [2 at cn (le32 s 24) (at + (n * cn)) ((le32 s 12) & 1) (le32 s 28)])
              (die "not a PSF font (neither magic)"))
   ; --- the unicode table: codepoint -> glyph, stored one up so 0 reads as a miss --
   ; the first spelling wins, so a codepoint two glyphs claim keeps the earlier one
   (put t cp g) (: had (peep t cp 0) (? had t (pin t cp (g + 1))))
   (u1 s i n g t) (? ((i + 1) >= n) t
                     (: v (le16 s i)
                        (? (v = 65535) (u1 s (i + 2) n (g + 1) t)
                           (v = 65534) (u1skip s (i + 2) n g t)
                           (u1 s (i + 2) n g (put t v g)))))
   (u1skip s i n g t) (? ((i + 1) >= n) t                     ; the tail of a multi-codepoint spelling
                         ((le16 s i) = 65535 ? (u1 s (i + 2) n (g + 1) t) (u1skip s (i + 2) n g t)))
   (u2 s i n g t) (? (i >= n) t
                     (: b (s i)
                        (? (b = 255) (u2 s (i + 1) n (g + 1) t)
                           (b = 254) (u2skip s (i + 1) n g t)
                           (: k (utf8n b) (u2 s (i + k) n g (put t (utf8 (snip s i (i + k))) g))))))
   (u2skip s i n g t) (? (i >= n) t
                         (: b (s i)
                            (b = 255 ? (u2 s (i + 1) n (g + 1) t) (u2skip s (i + (utf8n b)) n g t))))
   (umap s h) (? (! (h 5)) (die "the font carries no unicode table")
                 ((h 0) = 1) (u1 s (h 4) #s 0 {})
                 (u2 s (h 4) #s 0 {}))
   ; --- the page order, read off the reference table's comments --------------------
   (refcell line) (: ps (split "// [" line)
                     (? (! (two? >ps)) ()
                        (: cmt (ps 1) qs (split "] (" cmt)
                           (two? >qs ? [(utf8 <qs) ("// [" + cmt)] ()))))
   (refcells src) (filter two? (map refcell (lines src)))
   ; --- the lay --------------------------------------------------------------------
   ; quay erases with cell 0 and paints a newline as it, so U+0000 is laid blank
   ; rather than taken from the font, which spells it however it likes
   (cell s h t c) (: rs (<c ? (: g (peep t <c 0)
                                 _ (g ? 0 (die $ "the font has no U+" + (hx <c)))
                                 at ((h 1) + ((g - 1) * (h 2)))
                                 (map (r \ s (at + r)) ^(h 3)))
                              (map (\ _ 0) ^(h 3)))
                     (((("  {" + (join ", " (map hx2 rs))) + "}, ") + <>c) + "\n"))
   (lay s h t cs sym note)
    (((((("#include <stdint.h>\n" + note) + "uint8_t const ") + sym) + "[256][") + (show (h 3)))
     + ("] = {\n" + (cats (map (cell s h t) cs)) + "};\n"))
   (main args)
    (: src (rd <args)
       _ (src ? 0 (die $ "cannot read " + <args))
       h (head src)
       _ ((h 6) = 8 ? 0 (die $ "the glyphs are " + (show (h 6)) + " pixels wide; a quay row is 8"))
       ref (rd (args 1))
       _ (ref ? 0 (die $ "cannot read " + (args 1)))
       cs (refcells ref)
       _ (#cs = 256 ? 0 (die $ (args 1) + " holds " + (show #cs) + " cells, not 256"))
       ns (drop 4 args)
       note (two? ns ? ((join "\n" (map (\ l ("// " + l)) ns)) + "\n") "")
       out (lay src h (umap src h) cs (args 2) note)
       q (open (args 3) "w")
       (hot? q ? (: _ (say q out) (close q)) (die $ "cannot open " + (args 3))))
   (main >argv))
