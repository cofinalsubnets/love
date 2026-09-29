; --- test/host/cb.l: a vttest-lite for quay's console screen (love/cb.c + love/quay/quay.c) ---
; held out of the corpus, and not for its nifs: love0 links screen/scribe/glass/gaze/reply
; as surely as the final `love` does, and these laws pass twice on their own and beside
; the other movers. inside the whole corpus love0's second evaluation stops. which
; member it is quarrelling with is not known -- the corpus resists subsetting, since
; the roster is an ordering and a half of it is not a corpus. standalone, then:
;
;   cat test/00-init.l test/host/cb.l | out/love      ; exits 1 on fail, prints cb: ok
;
; the same struct cb is the kernel's framebuffer console, so every law asserted
; here holds under inle too -- this file is the emulator's executable spec.

; --- the little vocabulary ---
; a cell is three words (love/quay/quay.h): the glyph -- codepoint, width, picture,
; face -- then the fg and bg, each a kind in its top byte over a 24-bit value
(: (mkscr r c) (screen (cask (screen () r c)) r c)   ; the ctor: size protocol + open
   (chat s i) (2097151 & glass s i 0)              ; the codepoint of cell i
   (cface s i) (glass s i 0 >> 24)                 ; the face byte
   (cink k) ((k >> 24) @- 'def                      ; a colour: 'def, an index, or [r g b]
              1 (k & 255)
              2 [(k >> 16 & 255) (k >> 8 & 255) (k & 255)])
   (cfg s i) (cink (glass s i 1))
   (cbg s i) (cink (glass s i 2))
   (cur s) (gaze s 0)
   (rowtx s r)                                       ; row r's chars, blanks as spaces
    (: c (gaze s 2)
       (foldl (\ a i (a + string (: ch (chat s ((r * c) + i)) (0 = ch ? 32 ch)))) "" (jot c))))

; --- 1. the ctor and the size protocol ---
(: n (screen () 4 10)
 _ (test
    (charm? n)                   ; a non-cask first arg answers the byte count
    (40 < n)                     ; at least the 160 cell bytes + a header
    !(screen (cask 8) 4 10)   ; a too-small cask is refused
    !(screen (cask n) 0 10)   ; silly geometry is refused
    !(scribe 5 "x")           ; feeding a non-screen is nothing
    !(glass (cask 8) 0 0))    ; glassing a non-screen is nothing
 s (mkscr 4 10)
 _ (test
    (4 = gaze s 1) (10 = gaze s 2)   ; rows, cols
    (0 = gaze s 4) (3 = gaze s 5)    ; the scroll region opens full
    (3 = (3 & gaze s 3))               ; cursor shown + autowrap on
    (0 = cur s)
    (0 = chat s 0)
    !(glass s 40 0)                   ; off the grid: nothing
    !(glass s 0 3)))                  ; a cell has three words

; --- 2. plain text, the byte lanes, and controls ---
(: s (mkscr 4 10)
 _ (scribe s "hi")
 _ (test
    (104 = chat s 0) (105 = chat s 1)
    ('def = cfg s 0) ('def = cbg s 0)  ; the default pen: the screen's own colours
    (2 = cur s))
 _ (scribe s 33)                         ; a bare charm is one byte
 _ (test (33 = chat s 2))
 b (cask 2)
 _ (pin b 0 63) _ (pin b 1 63)
 _ (scribe s b)                          ; a cask pours its bytes
 _ (test ("hi!??" = snip (rowtx s 0) 0 5))
 _ (scribe s "\r")
 _ (test (0 = cur s))                ; cr homes the column
 _ (scribe s "ab\x08\x08")               ; (\b is no reader escape: \x08 is the byte)
 _ (test (0 = cur s))
 _ (scribe s "\x08")
 _ (test (0 = cur s)))               ; bs at column 0 stays (no row crossing)
(: s (mkscr 4 10)
 _ (scribe s "ab\ncd")
 _ (test
    (99 = chat s 12) (100 = chat s 13)   ; bare \n keeps the column (LNM off)
    (14 = cur s)))

; --- 3. tabs ---
(: s (mkscr 4 20)
 _ (scribe s "\ta")
 _ (test (97 = chat s 8))             ; tab stops every 8
 _ (scribe s "\tb")
 _ (test (98 = chat s 16))
 _ (scribe s "\t")
 _ (test (19 = cur s)))               ; ... clamped at the last column

; --- 4. autowrap, deferred (the DECAWM pending-wrap law) ---
(: s (mkscr 4 10)
 _ (scribe s "0123456789")
 _ (test
    (9 = cur s)                         ; ten glyphs: cursor stays on the last column
    (16 = (16 & gaze s 3))              ; ... wrap pending
    (57 = chat s 9))
 _ (scribe s "A")
 _ (test
    (65 = chat s 10)                    ; the eleventh glyph carried to a fresh row
    (11 = cur s))
 _ (scribe s "\e[?7l")                    ; autowrap off
 _ (scribe s "\e[1;10H")
 _ (scribe s "XYZ")
 _ (test
    (90 = chat s 9)                     ; X, Y, Z overwrote in place: Z holds
    (9 = cur s)
    (65 = chat s 10))                   ; the next row untouched
 _ (scribe s "\e[?7h"))

; --- 5. absolute addressing + relative moves, clamped ---
(: s (mkscr 4 10)
 _ (scribe s "\e[2;5H")
 _ (test (14 = cur s))                ; cup is 1-based
 _ (scribe s "\e[9;99H")
 _ (test (39 = cur s))                ; ... and clamps to the grid
 _ (scribe s "\e[H")
 _ (test (0 = cur s))
 _ (scribe s "\e[2B") _ (test (20 = cur s))    ; cud
 _ (scribe s "\e[3C") _ (test (23 = cur s))    ; cuf
 _ (scribe s "\e[2A") _ (test (3 = cur s))     ; cuu
 _ (scribe s "\e[9A") _ (test (3 = cur s))     ; clamped at the top
 _ (scribe s "\e[2D") _ (test (1 = cur s))     ; cub
 _ (scribe s "\e[9C") _ (test (9 = cur s))     ; clamped in the row
 _ (scribe s "\e[5G") _ (test (4 = cur s))     ; cha: column 5
 _ (scribe s "\e[3d") _ (test (24 = cur s))    ; vpa: row 3, column kept
 _ (scribe s "\e[E")  _ (test (30 = cur s))    ; cnl: next row home
 _ (scribe s "\e[2F") _ (test (10 = cur s)))   ; cpl: two up, home

; --- 6. erase: display and line, all three shapes ---
(: s (mkscr 3 10)
 _ (scribe s "0123456789012345678901234567")   ; fill (the last two pend)
 _ (scribe s "\e[2;5H\e[K")
 _ (test ("0123      " = rowtx s 1))       ; el 0: to end of row
 _ (scribe s "\e[1;5H\e[1K")
 _ (test ("     56789" = rowtx s 0))       ; el 1: from start, cursor inclusive
 _ (scribe s "\e[3;5H\e[2K")
 _ (test ("          " = rowtx s 2)))      ; el 2: the whole row
(: s (mkscr 3 10)
 _ (scribe s "aaaaaaaaaabbbbbbbbbbcccccccc")
 _ (scribe s "\e[2;5H\e[J")
 _ (test
    ("aaaaaaaaaa" = rowtx s 0)
    ("bbbb      " = rowtx s 1)
    ("          " = rowtx s 2))              ; ed 0: cursor to the end
 _ (scribe s "\e[1;5H\e[1J")
 _ (test ("     aaaaa" = rowtx s 0))       ; ed 1: start to cursor
 _ (scribe s "\e[2J")
 _ (test ("          " = rowtx s 0)))      ; ed 2: everything

; --- 7. edit: insert/delete characters, erase characters ---
(: s (mkscr 2 10)
 _ (scribe s "abcdefghij")
 _ (scribe s "\e[1;3H\e[2@")
 _ (test ("ab  cdefgh" = rowtx s 0))       ; ich: room made, tail slides off
 _ (scribe s "\e[2P")
 _ (test ("abcdefgh  " = rowtx s 0))       ; dch: closed back up
 _ (scribe s "\e[3X")
 _ (test ("ab   fgh  " = rowtx s 0)
           (2 = cur s)))                     ; ech blanks in place, cursor still

; --- 8. insert/delete lines ---
(: s (mkscr 4 10)
 _ (scribe s "aaaa\e[2;1Hbbbb\e[3;1Hcccc\e[4;1Hdddd")
 _ (scribe s "\e[2;1H\e[L")
 _ (test
    ("aaaa      " = rowtx s 0)
    ("          " = rowtx s 1)               ; il opened a blank row
    ("bbbb      " = rowtx s 2)
    ("cccc      " = rowtx s 3))              ; ... and dddd fell off
 _ (scribe s "\e[M")
 _ (test
    ("bbbb      " = rowtx s 1)               ; dl took the blank back out
    ("cccc      " = rowtx s 2)
    ("          " = rowtx s 3)))

; --- 9. the scroll region: decstbm, region-bound feeds, su/sd, RI ---
(: s (mkscr 5 10)
 _ (scribe s "top\e[2;1Haa\e[3;1Hbb\e[4;1Hcc\e[5;1Hbot")
 _ (scribe s "\e[2;4r")
 _ (test
    (1 = gaze s 4) (3 = gaze s 5)          ; the region took
    (0 = cur s))                             ; ... and decstbm homes
 _ (scribe s "\e[4;1H\n")                      ; \n at the region's bottom margin
 _ (test
    ("top       " = rowtx s 0)               ; above the region: untouched
    ("bb        " = rowtx s 1)               ; the region scrolled up
    ("cc        " = rowtx s 2)
    ("          " = rowtx s 3)
    ("bot       " = rowtx s 4))              ; below the region: untouched
 _ (scribe s "\e[2;1H\eM")                     ; RI at the region's top margin
 _ (test
    ("          " = rowtx s 1)               ; the region scrolled down
    ("bb        " = rowtx s 2)
    ("top       " = rowtx s 0))
 _ (scribe s "\e[2S")                          ; su by two
 _ (test ("cc        " = rowtx s 1))
 _ (scribe s "\e[T")                           ; sd by one
 _ (test ("cc        " = rowtx s 2))
 _ (scribe s "\e[r")                           ; the region opens back up
 _ (test (0 = gaze s 4) (4 = gaze s 5)))

; --- 10. scroll at the screen's own bottom (the classic teletype law) ---
(: s (mkscr 3 10)
 _ (scribe s "one\r\ntwo\r\nthree\r\n")
 _ (test
    ("two       " = rowtx s 0)               ; one scrolled off the top
    ("three     " = rowtx s 1)
    ("          " = rowtx s 2)
    (20 = cur s)))

; --- 11. SGR: colours, faces, resets ---
(: s (mkscr 2 12)
 _ (scribe s "\e[31;44;1mx")
 _ (test
    (1 = cfg s 0) (4 = cbg s 0) (1 = cface s 0))   ; red on blue, bold
 _ (scribe s "\e[4;7my")
 _ (test (7 = cface s 1))                            ; + underline + reverse
 _ (scribe s "\e[22;27mz")
 _ (test (2 = cface s 2))                            ; bold and reverse off, underline holds
 _ (scribe s "\e[mw")
 _ (test ('def = cfg s 3) ('def = cbg s 3) (0 = cface s 3))   ; SGR 0: the floor
 _ (scribe s "\e[92ma\e[38;5;196mb\e[38;2;255;0;0mc")
 _ (test
    (10 = cfg s 4)                          ; bright green: the high half
    (196 = cfg s 5)                         ; 256-colour, straight index
    ([255 0 0] = cfg s 6))                  ; truecolour: the rgb itself
 _ (scribe s "\e[48;5;238;39mq")
 _ (test (238 = cbg s 7) ('def = cfg s 7))
 _ (scribe s "\e[48;2;1;2;300mr")
 _ (test ([1 2 255] = cbg s 8))                  ; a channel past 255 holds at 255
 _ (scribe s "\e[0;2;3;5;8;9ms")
 _ (test (248 = cface s 9))                     ; dim 8 italic 16 strike 32 blink 64 hidden 128
 _ (scribe s "\e[23;25;28;29mt")
 _ (test (8 = cface s 10))                       ; ..each with its own off
 _ (scribe s "\e[1;22mu")
 _ (test (0 = cface s 11)))                      ; 22 ends bold and dim both

; --- 12. save/restore (ESC 7/8 and CSI s/u carry cursor + pen) ---
(: s (mkscr 4 10)
 _ (scribe s "\e[2;3H\e[35m\e7")
 _ (scribe s "\e[4;9H\e[m\e[42m")
 _ (scribe s "\e8x")
 _ (test
    (120 = chat s 12)                       ; restored to 2;3 and stamped there
    (5 = cfg s 12)                          ; ... with the saved magenta pen
    ('def = cbg s 12))                      ; ... not the green that came after
 _ (scribe s "\e[1;1H\e[s\e[3;3H\e[u")
 _ (test (0 = cur s)))

; --- 13. modes: cursor visibility, origin ---
(: s (mkscr 6 10)
 _ (test (1 = (1 & gaze s 3)))
 _ (scribe s "\e[?25l")
 _ (test (0 = (1 & gaze s 3)))            ; hidden: the flag renderers read
 _ (scribe s "\e[?25h")
 _ (test (1 = (1 & gaze s 3)))
 _ (scribe s "\e[3;5r\e[?6h")                 ; region rows 3..5, origin on
 _ (test (20 = cur s))                    ; home = the region's top
 _ (scribe s "\e[2;1H")
 _ (test (30 = cur s))                    ; row 2 = one under the region top
 _ (scribe s "\e[9;1H")
 _ (test (40 = cur s))                    ; clamped at the region's bottom
 _ (scribe s "\e[?6l\e[r"))

; --- 14. the alternate screen ---
(: s (mkscr 3 10)
 _ (scribe s "ground\e[35m")
 _ (scribe s "\e[?1049h")
 _ (test
    (0 = chat s 0)                          ; a clean page for the full-screen guest
    (0 = cur s))
 _ (scribe s "guest")
 _ (scribe s "\e[?1049l")
 _ (scribe s "x")
 _ (test
    (103 = chat s 0)                        ; the ground back as it was
    (120 = chat s 6)                        ; ..the cursor where it was saved
    (5 = cfg s 6)))                         ; ..and the pen

; --- 15. replies: dsr, da, and the drain-once law ---
(: s (mkscr 4 10)
 _ (scribe s "\e[3;7H\e[6n")
 _ (test ([27 91 51 59 55 82] = reply s)       ; "\e[3;7R"
           !(reply s))                        ; drained: quiet
 _ (scribe s "\e[c")
 _ (test ("\e[?62;4;22c" = string (reply s)))     ; a vt220, sixel (4) and ansi colour (22)
 _ (scribe s "\eZ")                              ; DECID: the vt102 answer it always gave
 _ (test ([27 91 63 54 99] = reply s))
 _ (scribe s "\e[5n")
 _ (test ([27 91 48 110] = reply s)))          ; "\e[0n": all well

; --- 15b. the asks a line editor waits on: colour queries, secondary da ---
; (silence here cost a real second of buffered keystrokes at zsh startup)
(: s (mkscr 4 20)
 _ (scribe s "\e]11;?\x07")
 _ (test ([27 93 49 49 59 114 103 98 58 48 48 48 48 47 48 48 48 48 47 48 48 48 48 7]
              = reply s))                        ; bg: rgb:0000/0000/0000, bel-terminated
 _ (scribe s "\e]10;?\e\\")                      ; st-terminated ask, same answer lane
 _ (test ([27 93 49 48 59 114 103 98 58 99 48 99 48 47 99 48 99 48 47 99 48 99 48 7]
              = reply s))                        ; fg: rgb:c0c0/c0c0/c0c0
 _ (scribe s "\e]0;just a title\x07")
 _ (test !(reply s))                        ; a title is not a question
 _ (scribe s "\e[>c")
 _ (test ([27 91 62 48 59 48 59 48 99] = reply s))       ; secondary da
 _ (scribe s "\e[c")
 _ (test ("\e[?62;4;22c" = string (reply s))))  ; primary da unchanged

; --- 16. what must be swallowed whole ---
(: s (mkscr 2 10)
 _ (scribe s "\e]0;a title\x07x")                ; osc to bel (\x07 -- \a is no reader escape)
 _ (test (120 = chat s 0))
 _ (scribe s "\e]2;more\e\\y")                   ; osc to st
 _ (test (121 = chat s 1))
 _ (scribe s "\e(B\e)0\e=\e>z")                  ; charsets + keypad chatter
 _ (test (122 = chat s 2))
 _ (scribe s "\e[?2004h\e[>1c\e[0 q!")           ; odd modes, intermediates: junked
 _ (test (33 = chat s 3))
 _ (scribe s "a\x7fb\e[\x7f1D")                  ; del: nothing, anywhere (mid-CSI too)
 _ (test (97 = chat s 4) (98 = chat s 5) (5 = cur s)))

; --- 17. decaln: the adjustment screen ---
(: s (mkscr 3 8)
 _ (scribe s "\e[2;3r\e#8")
 _ (test
    (69 = chat s 0) (69 = chat s 23)         ; E corner to corner
    (0 = gaze s 4) (2 = gaze s 5)            ; region reopened
    (0 = cur s)))

; --- 17b. utf-8 decodes: a cell holds the codepoint, whatever face draws it ---
(: s (mkscr 4 20)
 _ (scribe s "\xc3\xa9")                          ; é
 _ (test (233 = chat s 0))
 _ (scribe s "\xe2\x94\x80\xe2\x94\x82\xe2\x94\x8c\xe2\x95\x90\xe2\x95\x94")   ; ─ │ ┌ ═ ╔
 _ (test (9472 = chat s 1) (9474 = chat s 2) (9484 = chat s 3)
           (9552 = chat s 4) (9556 = chat s 5))
 _ (scribe s "\xe2\x95\xad")                      ; ╭ stays itself: the face aliases it
 _ (test (9581 = chat s 6))
 _ (scribe s "\xe2\x96\x91\xe2\x96\x88")          ; ░ █
 _ (test (9617 = chat s 7) (9608 = chat s 8))
 _ (scribe s "\xce\xb1\xe2\x88\x9e\xc2\xb0")      ; α ∞ °
 _ (test (945 = chat s 9) (8734 = chat s 10) (176 = chat s 11))
 _ (scribe s "\xf0\x9f\x98\x80")                  ; an emoji: wide, held whole
 _ (test (128512 = chat s 12) (0 = chat s 13) (14 = cur s))
 _ (scribe s 226) _ (scribe s 148)                ; a sequence split across feeds
 _ (scribe s 144)                                 ; ... still one ┐
 _ (test (9488 = chat s 14))
 _ (scribe s "\x80")                              ; a stray continuation: U+FFFD
 _ (test (65533 = chat s 15))
 _ (scribe s "\xc3\e[Dx")                         ; torn mid-sequence: a U+FFFD lands,
 _ (test (120 = chat s 16)                    ; the ESC rides on -- cub steps
           (17 = cur s))                        ; back and x overwrites it
 _ (scribe s "\xe2\x96\xba\xe2\x96\xb2\xe2\x99\xaa")   ; ► ▲ ♪: pictures whose cp437 bytes
 _ (test (9658 = chat s 17) (9650 = chat s 18) (9834 = chat s 19)   ; ..are controls
           (19 = cur s))                        ; and act as none: ♪ holds the last column
 _ (scribe s "\xc2\x9b\xed\xa0\x80")              ; a C1 control and a surrogate:
 _ (test (65533 = chat s 20) (65533 = chat s 21)))    ; neither lands as itself
; --- 17c. wide characters: two cells, a lead holding the codepoint and a tail holding 0 ---
(: (cwide s i) (glass s i 0 >> 21 & 3)            ; 0 single, 1 lead, 2 tail
 s (mkscr 3 6)
 _ (scribe s "\u{4e16}a")                          ; 世 then a
 _ (test (19990 = chat s 0) (1 = cwide s 0)
         (0 = chat s 1) (2 = cwide s 1)
         (97 = chat s 2) (3 = cur s))              ; the cursor stepped two, then one
 _ (scribe s "\e[1;2Hx")                           ; x over the tail
 _ (test (0 = chat s 0) (0 = cwide s 0)            ; ..blanks the lead
         (120 = chat s 1) (0 = cwide s 1))
 _ (scribe s "\e[1;1H\u{4e16}\e[1;1Hy")            ; y over the lead
 _ (test (121 = chat s 0) (0 = chat s 1) (0 = cwide s 1))   ; ..blanks the tail
 _ (scribe s "\e[1;6H\u{4e16}")                    ; a wide char at the last column
 _ (test (0 = cwide s 5)                           ; ..leaves it
         (19990 = chat s 6) (1 = cwide s 6)        ; ..and wraps first
         (8 = cur s))
 _ (scribe s "\e[2;5H\u{4e16}")                    ; filling the last two columns
 _ (test (1 = cwide s 10) (2 = cwide s 11)
         (11 = cur s) (16 = (16 & gaze s 3)))      ; ..pends the wrap on the tail
 _ (scribe s "\e[3;1H\u{0301}e\u{0301}")           ; combining marks take no cell
 _ (test (101 = chat s 12) (13 = cur s)))

; --- 17d. an erase or a shift that splits a pair blanks the half left over ---
(: s (mkscr 1 8)
 _ (scribe s "\u{4e16}\u{754c}\u{4e16}\u{754c}")    ; 世界世界: four pairs, the row full
 _ (scribe s "\e[1;2H\e[1X")                       ; ech on the first tail
 _ (test (0 = chat s 0) (0 = cwide s 0))           ; ..the lead goes with it
 _ (scribe s "\e[1;4H\e[1P")                       ; dch on 界's tail: 世 shifts onto col 3
 _ (test (19990 = chat s 3) (1 = cwide s 3) (2 = cwide s 4)
         (0 = cwide s 2))                          ; ..and 界's lead, alone, blanks
 _ (scribe s "\e[1;5H\e[K")                        ; el from 世's tail
 _ (test (0 = chat s 3) (0 = cwide s 3)))          ; ..takes its lead too

; --- 17e. the vt's widths are 'text's: a cursor steps what wcwidth says, on every plane ---
(: _ (borrow 'text)
 cps [161 768 4352 4447 8203 9728 9749 11904 12288 12351 19968 40959 44032 55203
      63744 65024 65040 65281 65377 94176 110592 119648 127744 128512 129280 131072
      173782 194560 917505 917760 983040]
 s (mkscr 1 8)
 (step cp) (: _ (scribe s "\e[1;1H") _ (scribe s (utf8 cp)) (cur s))
 _ (test (foldl (\ a cp (&& a (step cp = max 0 (wcwidth cp)))) 1 cps)))

; --- 17f. a mark joins the cell before the cursor: glass answers the base, and 3 4 5 the
;     marks; a pool of 128 clusters, a slot no cell names taken back when it is full ---
(: (marks s i) (filter (< 0) (map (glass s i) [3 4 5]))
 s (mkscr 3 4)
 _ (scribe s "e\u{301}\u{4e16}\u{300}")           ; é, then 世 with a grave
 _ (test (101 = chat s 0) ([769] = marks s 0) (0 = (glass s 0 0 >> 21 & 3))
         (19990 = chat s 1) ([768] = marks s 1)     ; ..on the lead
         (1 = (glass s 1 0 >> 21 & 3)) (2 = (glass s 2 0 >> 21 & 3))
         (() = marks s 2) (3 = cur s))
 _ (scribe s "\e[2;1Habcd\u{302}")                   ; a pending wrap: the last column's
 _ (test (100 = chat s 7) ([770] = marks s 7) (7 = cur s))
 _ (scribe s "\e[3;1H\u{301}a\u{300}\u{301}\u{302}\u{303}")   ; col 0 has nothing; three fit
 _ (test ([770] = marks s 7) (97 = chat s 8) ([768 769 770] = marks s 8) (9 = cur s))
 _ (scribe s "\e[3;1Hx")                             ; a write takes the cluster away
 _ (test (120 = chat s 8) (() = marks s 8))
 w (mkscr 1 200)
 (clus i) (utf8 (65 + (i // 100)) + utf8 (768 + (i % 100)))   ; 200 distinct clusters
 _ (scribe w (cats (map clus (jot 200))))
 _ (test ([795] = marks w 127) (() = marks w 128)   ; the pool's 128, then bare bases
         (66 = chat w 128) (200 = #(filter (\ i (0 < chat w i)) (jot 200))))
 _ (scribe w ("\e[1;1H" + cats (map (\ i "x") (jot 64))))   ; 64 slots no longer named
 _ (scribe w ("\e[1;130H" + clus 150))              ; ..so a new one finds room
 _ (test ([818] = marks w 129) ([867] = marks w 99)))

; --- 20. sixel: a picture decoded into the store, its tiles laid in cells at the cursor ---
; a 10x12 picture: red, with blue over the first five columns of the first band. 8x16
; cells, so it lands as two tiles on one row, and the cursor steps under it
(: (pic? s i) (1 = (glass s i 0 >> 23 & 1))
   (slot s i) (glass s i 0 >> 16 & 127)
   (tx s i) (glass s i 0 >> 8 & 255)
   red 4294901760 blue 4278190335                    ; 0xff over the rgb: a pixel the picture set
   img "\eP0;1;0q#0;2;100;0;0#1;2;0;0;100#0!10~$#1!5~-#0!10~\e\\"
   s (mkscr 4 10)
   _ (scribe s img)
   _ (test (pic? s 0) (pic? s 1) !(pic? s 2)
           (0 < slot s 0) (slot s 0 = slot s 1)
           (0 = tx s 0) (1 = tx s 1)
           (10 = cur s))                             ; the line under it, at its column
   _ (test (blue = tilepx s 0 0 0) (blue = tilepx s 0 4 5)
           (red = tilepx s 0 5 0) (red = tilepx s 1 1 0)   ; x 9, the last column
           (red = tilepx s 0 0 6)                    ; the second band
           (0 = tilepx s 1 2 0)                      ; x 10: past the picture
           (0 = tilepx s 0 0 12)                     ; y 12: past it
           !(tilepx s 2 0 0))                        ; no tile at all
   _ (scribe s "\e[1;1Hx")                           ; text over a tile replaces it
   _ (test !(pic? s 0) (120 = chat s 0) (pic? s 1)))

; --- 20b. the colour lanes, a scroll, an abort, and a store that sweeps ---
(: (pic? s i) (1 = (glass s i 0 >> 23 & 1))
   s (mkscr 3 10)
   _ (scribe s "\ePq#1;1;120;50;100#1~\e\\")         ; HLS: sixel's 120 degrees is red
   _ (test (4294901760 = tilepx s 0 0 0))
   _ (scribe s "\e[3;1H\ePq#2;2;0;100;0#2~\e\\")     ; on the last row: the screen scrolls
   _ (test !(pic? s 0)                               ; the red one scrolled off the top..
           (pic? s 10) (4278255360 = tilepx s 10 0 0)   ; ..and the green sits above the cursor
           (20 = cur s))
   s2 (mkscr 2 10)
   _ (scribe s2 "\ePq#0;2;100;0;0!10~\x18z")         ; CAN: the picture is dropped
   _ (test !(pic? s2 0) (122 = chat s2 0))
   ; two hundred pictures, each written over at once: the store would hold a few dozen,
   ; so only the sweep keeps the last one coming
   s3 (mkscr 4 10)
   (many n) (? (n < 1) 0 (: _ (scribe s3 "\e[1;1H\ePq#0;2;0;0;100!10~-!10~\e\\\e[1;1Hxy") (many (n - 1))))
   _ (many 200)
   _ (scribe s3 "\e[1;1H\ePq#0;2;0;0;100!10~\e\\")
   _ (test (pic? s3 0) (4278190335 = tilepx s3 0 3 3)))

; --- 20c. the sizes a picture is fitted to, and the graphics asks ---
(: s (mkscr 4 10)
 (ask q) (: _ (scribe s q) (string (reply s)))
 _ (test ("\e[6;16;8t" = ask "\e[16t")                    ; a cell in pixels
         ("\e[4;64;80t" = ask "\e[14t")                   ; the grid in pixels
         ("\e[8;4;10t" = ask "\e[18t")                    ; the grid in cells
         ("\e[?1;0;256S" = ask "\e[?1;1S")                ; 256 registers
         ("\e[?2;0;80;64S" = ask "\e[?2;1S")              ; the geometry
         ("\e[?62;4;22c" = ask "\e[c")))                  ; sixel, in the DA

; --- 21. kitty graphics: APC G key=value,..;base64 ST, a subset -- raw pixels, direct ---
(: (pic? s i) (1 = (glass s i 0 >> 23 & 1))
   (ask s q) (: _ (scribe s q) (string (reply s)))
   red 4294901760 blue 4278190335 green 4278255360
   ; a=T: a 2x2 red placed at the cursor, which then stands beside it on its last row
   s (mkscr 4 10)
   _ (test ("\e_Gi=7;OK\e\\" = ask s "\e_Ga=T,f=24,s=2,v=2,i=7;/wAA/wAA/wAA/wAA\e\\")
           (pic? s 0) !(pic? s 1) (1 = cur s)
           (red = tilepx s 0 1 1) (0 = tilepx s 0 2 0))
   ; chunks: m=1 keeps the transfer open, a chunk's keys past m and q are its first's
   _ (scribe s "\e[2;1H")
   _ (test ("" = ask s "\e_Ga=T,f=32,s=1,v=1,i=8,m=1;AAD/\e\\")   ; half a pixel: no answer yet
           !(pic? s 10)
           ("\e_Gi=8;OK\e\\" = ask s "\e_Gm=0,i=99;/w==\e\\")    ; its i stays 8
           (pic? s 10) (blue = tilepx s 10 0 0))
   ; alpha below half is no pixel: the cell's ground shows
   _ (scribe s "\e[3;1H")
   _ (scribe s "\e_Ga=T,f=32,s=1,v=1,q=2;////Cg==\e\\")
   _ (test (pic? s 20) (0 = tilepx s 20 0 0))
   ; a=t stores by id and places nothing; a=p places it later
   s2 (mkscr 4 10)
   _ (test ("\e_Gi=9;OK\e\\" = ask s2 "\e_Ga=t,f=24,s=1,v=1,i=9;AP8A\e\\")
           !(pic? s2 0) (0 = cur s2)
           ("\e_Gi=9;OK\e\\" = ask s2 "\e_Ga=p,i=9\e\\")
           (pic? s2 0) (green = tilepx s2 0 0 0))
   ; a=q asks and keeps nothing; the errors say which key refused
   _ (test ("\e_Gi=31;OK\e\\" = ask s2 "\e_Ga=q,i=31,s=1,v=1,f=24;AAAA\e\\")
           ("\e_Gi=5;EINVAL:format\e\\" = ask s2 "\e_Ga=T,f=99,i=5;AAAA\e\\")
           ("\e_Gi=5;EBADPNG:png\e\\" = ask s2 "\e_Ga=T,f=100,i=5;AAAA\e\\")   ; no PNG in it
           ("\e_Gi=6;EINVAL:medium\e\\" = ask s2 "\e_Ga=T,f=24,t=f,s=1,v=1,i=6;AAAA\e\\")
           ("\e_Gi=99;ENOENT:no such image\e\\" = ask s2 "\e_Ga=p,i=99\e\\")
           ("\e_Gi=4;EINVAL:short\e\\" = ask s2 "\e_Ga=T,f=24,s=2,v=1,i=4;AAAA\e\\")
           ("" = ask s2 "\e_Ga=T,f=100,i=5,q=2;AAAA\e\\"))           ; q=2: silence
   ; c and r: the placement in cells, nearest pixel; C=1 leaves the cursor
   s3 (mkscr 4 10)
   _ (scribe s3 "\e_Ga=T,f=24,s=2,v=2,c=2,r=1,C=1;/wAA/wAA/wAA/wAA\e\\")
   _ (test (pic? s3 0) (pic? s3 1) !(pic? s3 2) !(pic? s3 10)
           (red = tilepx s3 1 7 15) (0 = cur s3))
   ; a=d: every placement goes; d=i one image's
   _ (scribe s "\e_Ga=d,d=i,i=8\e\\")
   _ (test (pic? s 0) !(pic? s 10))
   _ (scribe s "\e_Ga=d\e\\")
   _ (test !(pic? s 0) !(pic? s 20)))

; --- 22. regrid: a screen laid across into a new geometry -- rows kept as far as the cursor
;     needs, clipped where narrower, a wide char cut in two blanked, clusters whole, and the
;     pictures the new store holds. the old screen is left as it was ---
(: (rmarks s i) (filter (< 0) (map (glass s i) [3 4 5]))
   (rpic? s i) (1 = (glass s i 0 >> 23 & 1))
   (rwide s i) (glass s i 0 >> 21 & 3)
   (re s r c) (regrid s (cask (screen () r c)) r c)
   s (mkscr 4 10)
   _ (scribe s "\e[1;1Habcdefgh\e[2;1Hx\u{301}\e[2;5H\u{4e16}\e[3;3H")
   t (re s 4 5)                                    ; narrower: the rows all fit
   _ (test (4 = gaze t 1) (5 = gaze t 2)
           (101 = chat t 4) (120 = chat t 5) ([769] = rmarks t 5)
           (0 = chat t 9) (0 = rwide t 9)          ; 世's lead, its tail cut away
           (12 = cur t)
           (104 = chat s 7) (19990 = chat s 14) (22 = cur s))   ; the old screen untouched
   u (re s 2 10)                                   ; shorter: up only as far as the cursor's row
   _ (test (120 = chat u 0) ([769] = rmarks u 0) (19990 = chat u 4) (1 = rwide u 4)
           (12 = cur u))
   v (re s 6 12)                                   ; larger: new ground past the old edge
   _ (test (97 = chat v 0) (104 = chat v 7) (0 = chat v 8) (120 = chat v 12) (26 = cur v))
   p (mkscr 4 10)
   _ (scribe p "\eP0;1;0q#0;2;100;0;0#1;2;0;0;100#0!10~$#1!5~-#0!10~\e\\\e[1;1H")
   q (re p 3 8)                                    ; a picture comes along in its tiles
   _ (test (rpic? q 0) (rpic? q 1) !(rpic? q 2)
           (4278190335 = tilepx q 0 0 0) (4294901760 = tilepx q 1 1 0))
   w (re p 1 1)                                    ; a 1x1 store still holds a 10x12 one
   _ (test (rpic? w 0) (4278190335 = tilepx w 0 0 0))
   b (mkscr 4 10)
   _ (scribe b "\eP0;1;0q#0;2;100;0;0#0!20~-#0!20~\e\\\e[1;1H")   ; 20x12: past a 1x1 store
   x (re b 1 1)
   _ (test (rpic? b 0) !(rpic? x 0) (0 = chat x 0))
   _ (test !(regrid s s 4 5) (0 < regrid s () 4 5) !(regrid s (cask 10) 4 5)))

; --- 23. history: rows a scroll pushes off the top are kept, and glass reads them at negative
;     indices, -cols the newest line's first cell. the view looks back through them: the
;     painter's rows move down, and more output keeps the view on the same lines ---
(: (hrow s k c) (cats (map (\ q (: ch (2097151 & glass s (k + q) 0) (0 = ch ? " " (string ch)))) (jot c)))
   s (mkscr 3 4)
   _ (scribe s ("\e[20h" + "aa\nbb\ncc\ndd\nee"))        ; LNM: \n is a newline; five lines on three rows
   _ (test (2 = gaze s 9) (0 = gaze s 8)
           ("aa  " = hrow s -8 4) ("bb  " = hrow s -4 4)  ; oldest first, newest at -cols
           ("cc  " = hrow s 0 4) ("ee  " = hrow s 8 4)
           !(glass s -9 0) !(glass s 12 0))           ; past the history, past the grid
   _ (test (1 = peer s 1) ("bb  " = hrow s -4 4) (1 = gaze s 8)
           (2 = peer s 9) (0 = peer s -1))            ; clamped both ways
   _ (peer s 1)
   _ (scribe s "\nff")                                 ; a line in while looking back
   _ (test (3 = gaze s 9) (2 = gaze s 8))             ; ..the view follows the same line
   _ (scribe s "\e[3J")                                ; ED 3: the history goes, the screen stays
   _ (test (0 = gaze s 9) (0 = gaze s 8) ("ff  " = hrow s 8 4))
   a (mkscr 3 4)
   _ (scribe a ("\e[20h" + "xx\nyy\nzz\nww" + "\e[?1049h" + "1\n2\n3\n4\n5" + "\e[?1049l"))
   _ (test ("xx  " = hrow a -4 4) (1 = gaze a 9))     ; the alternate screen kept nothing
   t (mkscr 3 4)
   _ (scribe t ("\e[20h" + "\e[2;3r" + "\e[2;1H" + "p\nq\nr\ns"))   ; a region below the top
   _ (test (0 = gaze t 9))                             ; ..scrolls keep no history
   w (mkscr 3 4)
   _ (scribe w ("\e[20h" + "e\u{301}\n\u{4e16}\n3\n4\n5"))    ; a cluster and a wide char into history
   _ (test (769 = glass w -8 3) (19990 = 2097151 & glass w -4 0) (1 = (glass w -4 0 >> 21 & 3)))
   r (regrid w (cask (screen () 2 3)) 2 3)             ; regrid: history and the rows shrunk away
   _ (test (3 = gaze r 9) ("e" = snip (hrow r -9 3) 0 1) ("3  " = hrow r -3 3) ("5  " = hrow r 3 3))
   ; the painter looks back too: row 0 one line back paints what a screen with it there does
   (pix sc y) (: px (cask (4 * 32 * 48)) _ (dye sc px 32 y -1 ()) (snip px (y * 2048) ((y + 1) * 2048)))
   p (mkscr 3 4)
   _ (scribe p ("\e[20h" + "aa\nbb\ncc\ndd"))
   q (mkscr 3 4)
   _ (scribe q "aa")
   _ (peer p 1)
   _ (test (pix p 0 = pix q 0) (pix p 1 = pix (scribe (mkscr 3 4) "\nbb") 1))
   _ (peer p 0)
   _ (test !(pix p 0 = pix q 0)))

; --- 24. the alternate screen: the main grid waits in the twin and comes back whole, the
;     cursor with it; its clusters stay named while it waits, and a resize carries it ---
(: (arow s k c) (cats (map (\ q (: ch (2097151 & glass s (k + q) 0) (0 = ch ? " " (string ch)))) (jot c)))
   s (mkscr 3 5)
   _ (scribe s "abc\e[2;2Hd")
   _ (scribe s "\e[?1049hxyz")
   _ (test ("xyz  " = arow s 0 5) ("     " = arow s 5 5))   ; a cleared grid of its own
   _ (scribe s "\e[?1049l")
   _ (test ("abc  " = arow s 0 5) (" d   " = arow s 5 5) (7 = cur s))   ; ..and the main one back
   _ (scribe s "\e[?47hq\e[?47l")                     ; 47 and 1047 the same way
   _ (test ("abc  " = arow s 0 5))
   w (mkscr 2 100)
   (clus i) (utf8 (65 + (i // 100)) + utf8 (768 + (i % 100)))
   _ (scribe w "e\u{301}\e[?1049h")
   _ (scribe w (cats (map clus (jot 200))))           ; the pool full twice over in the alternate
   _ (scribe w "\e[?1049l")
   _ (test (101 = chat w 0) ([769] = filter (< 0) (map (glass w 0) [3 4 5])))
   r (mkscr 3 5)
   _ (scribe r "abcde\e[?1049hzz")
   t (regrid r (cask (screen () 3 3)) 3 3)           ; a resize while the alternate is up
   _ (scribe t "\e[?1049l")
   _ (test ("abc" = arow t 0 3)))

; --- 25. the mouse: the report a pointer event makes, as the program asked for it ---
(: (ml b x y) ("\e[M" + string b + string x + string y)   ; the classic report, each byte +32
   s (mkscr 5 10)
   _ (test ("" = mouse s 0 2 3 0))                        ; nothing asked, nothing said
   _ (scribe s "\e[?1000h")
   _ (test ((ml 32 36 35) = mouse s 0 2 3 0)             ; left pressed at row 2, col 3
           ((ml 35 36 35) = mouse s 0 2 3 1)             ; a release names no button
           ((ml 51 36 35) = mouse s 16 2 3 1)            ; ..but keeps ctrl
           ((ml 36 36 35) = mouse s 4 2 3 0)             ; shift
           ("" = mouse s 0 2 3 2)                        ; moves not asked
           ((ml 96 33 33) = mouse s 64 0 0 0)            ; the wheel up
           ("" = mouse s 64 0 0 1)                       ; and no release of it
           ("" = mouse s 3 2 3 0))                       ; no button, no press
   _ (scribe s "\e[?1002h")
   _ (test ((ml 64 36 35) = mouse s 0 2 3 2) ("" = mouse s 3 2 3 2))   ; a drag, not a hover
   _ (scribe s "\e[?1003h")
   _ (test ((ml 67 36 35) = mouse s 3 2 3 2))            ; every move
   _ (scribe s "\e[?1006h")
   _ (test ("\e[<0;4;3M" = mouse s 0 2 3 0) ("\e[<2;4;3m" = mouse s 2 2 3 1)
           ("\e[<35;10;5M" = mouse s 3 4 9 2) ("\e[<80;1;1M" = mouse s 80 0 0 0))
   _ (test ("\e[<4294967232;4294967295;4294967295M" = mouse s 4294967232 4294967294 4294967294 0))   ; the widest
   _ (scribe s "\e[?1000l")
   _ (test ("" = mouse s 0 2 3 0))                        ; one tracking off is all of it
   _ (scribe s "\e[?1006l\e[?9h")
   _ (test ((ml 32 36 35) = mouse s 4 2 3 0) ("" = mouse s 0 2 3 1))   ; x10: no modifiers, no releases
   w (mkscr 2 250)
   _ (scribe w "\e[?1000h")
   _ (test ((ml 32 255 34) = mouse w 0 1 240 0))         ; a column past a byte's reach
   _ (scribe s "\e[?1000h\ec")
   _ (test ("" = mouse s 0 2 3 0))                        ; ris turns it off
   (pasting s) (0 < ((gaze s 3) & 16384))                 ; ?2004, which a seat reads to bracket a paste
   _ (test !(pasting s))
   _ (scribe s "\e[?2004h")
   _ (test (pasting s))
   _ (scribe s "\e[?2004l")
   _ (test !(pasting s))
   _ (scribe s "\e[?2004h\ec")
   _ (test !(pasting s)))

; --- 26. a paste as a seat sends it, and a picture's tile read back from the history ---
(: s (mkscr 3 10)
   _ (test ("p\rq\tr" = pasted s "p\nq\tr")          ; newlines as returns, a tab kept
           ("a\rb" = pasted s "a\r\nb")                ; a crlf is one return
           ("a[201~b" = pasted s "a\e[201~b")          ; no escape: the bracket can't close early
           ("xy" = pasted s "x\x7fy\x01")             ; nor any other control
           ("" = pasted s "")
           !(pasted s 5))
   _ (scribe s "\e[?2004h")
   _ (test ("\e[200~p\rq\e[201~" = pasted s "p\nq") ("\e[200~\e[201~" = pasted s ""))
   red 4294901760 blue 4278190335
   t (mkscr 2 10)
   _ (scribe t "\eP0;1;0q#0;2;100;0;0#1;2;0;0;100#0!10~$#1!5~-#0!10~\e\\")
   _ (scribe t "\r\n")                                 ; the tiles' row scrolls into the history
   _ (test (1 = (glass t -10 0 >> 23 & 1)) (blue = tilepx t -10 0 0) (red = tilepx t -9 1 0)
           !(tilepx t -11 0 0)))                        ; past what is held

; --- 27. the selection: cells, words and lines, the text they copy, and what ends it ---
(: (sel s) [(gaze s 10) (gaze s 11)]
   s (mkscr 3 10)
   _ (scribe s "hello big\r\nworld")
   _ (select s 1 3 0)
   _ (test ([1 4] = sel s) ("ell" = copied s 1 4))
   _ (select s 7 2 1)                                  ; either order; a word each end
   _ (test ([0 9] = sel s) ("hello big" = copied s 0 9))
   _ (select s 12 12 1)
   _ (test ([10 15] = sel s))
   _ (select s 12 12 2)                                ; the line, its blanks trimmed in the copy
   _ (test ([10 20] = sel s) ("world" = copied s 10 20)
           ("hello big\nworld\n" = copied s 0 30))     ; newlines where rows end
   _ (select s 0 2 0)
   _ (scribe s "\e[3;1Hz")                              ; a write on another row
   _ (test ([0 3] = sel s))
   _ (scribe s "\e[1;9Hx")                              ; ... and on its own: gone
   _ (test ([0 0] = sel s))
   _ (select s 0 2 0)
   _ (select s 0 0 -1)
   _ (test ([0 0] = sel s))
   w (mkscr 3 5)
   _ (scribe w "abcdefgh")                             ; row 0 wraps into row 1
   _ (test ("abcdefgh" = copied w 0 10) (0 = glass w 4 1))   ; one line; glass hides the mark
   _ (select w 7 7 2)
   _ (test ([0 10] = sel w))                           ; the line is both rows
   v (mkscr 2 10)
   _ (scribe v ("a" + utf8 20013 + "b e" + utf8 769))
   _ (test (("a" + utf8 20013 + "b e" + utf8 769) = copied v 0 10))   ; a wide char once, a mark kept
   _ (select v 2 2 0)                                  ; its tail takes the whole of it
   _ (test ([1 3] = sel v))
   t (mkscr 2 5)
   _ (scribe t "ab")
   _ (select t 0 1 0)
   _ (scribe t "\r\n\r\n")                             ; its row scrolls into the history
   _ (test ([-5 -3] = sel t) ("ab" = copied t -5 -3))
   _ (scribe t "\e[3J")                                 ; the history cleared, the selection too
   _ (test ([0 0] = sel t)))

; --- 28. a picture read back out: its size, its gen, and its pixels as base64 rgba ---
(: (slot s i) (glass s i 0 >> 16 & 127)
   s (mkscr 4 10)
   _ (scribe s "\e_Ga=T,f=24,s=2,v=2,i=7,q=2;/wAA/wAA/wAA/wAA\e\\")   ; a 2x2 red
   k (slot s 0)
   _ (test (2 = picture s k 0) (2 = picture s k 1) (1 = picture s k 2)
           ("/wAA//8AAP//AAD//wAA/w==" = picture s k 3)            ; ff 00 00 ff, four times
           !(picture s (k + 1) 0) !(picture s 0 0) !(picture s k 4))
   _ (scribe s "\e[3;1H\e_Ga=T,f=32,s=1,v=1,q=2;AAD/AA==\e\\")      ; another: a new gen
   _ (test (2 = picture s (slot s 20) 2))
   t (regrid s (cask (screen () 4 12)) 4 12)             ; a regrid keeps the gen
   _ (test (1 = picture t (slot t 0) 2)))

; --- 18. ris: back to the floor ---
(: s (mkscr 3 8)
 _ (scribe s "\e[31;44;7mxyz\e[2;2r\e[?25l\e[?7l")
 _ (scribe s "\ec")
 _ (test
    (0 = chat s 0)
    (0 = cur s)
    (3 = (3 & gaze s 3))                       ; shown + wrapping again
    (0 = gaze s 4) (2 = gaze s 5))
 _ (scribe s "w")
 _ (test ('def = cfg s 0) (0 = cface s 0)))

; --- 19. wet: every write names its rows; a read clears the ledger ---
(: s (mkscr 4 10)
 _ (test (15 = (15 & wet s 0)))       ; fresh: every row dirty
 _ (test (0 = wet s 0))               ; read-and-cleared
 _ (scribe s "\e[3;1Hx")
 _ (test (4 = wet s 0))               ; row 2 alone
 _ (scribe s "hi\nyo")
 _ (test (12 = wet s 0))              ; rows 2 and 3 (\n keeps the column)
 _ (scribe s "\e[2J")
 _ (test (15 = wet s 0))              ; erase display: everything
 _ (scribe s "\e[1;5r\e[4;1H\n")             ; a region scroll dirties the region
 _ (wet s 0)
 _ (scribe s "\e[2;1H\e[L")
 _ (test (14 = (14 & wet s 0))))      ; il at row 1: rows 1..3

(test_fin ())
(puts "cb: ok")
