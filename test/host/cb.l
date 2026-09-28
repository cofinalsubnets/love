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

; --- 14. the one-grid alternate screen ---
(: s (mkscr 3 10)
 _ (scribe s "ground\e[35m")
 _ (scribe s "\e[?1049h")
 _ (test
    (0 = chat s 0)                          ; a clean page for the full-screen guest
    (0 = cur s))
 _ (scribe s "guest")
 _ (scribe s "\e[?1049l")
 _ (test
    (0 = chat s 0)                          ; the ground is not repainted (one grid,
    (6 = cur s)                             ;  the honest price) -- but the cursor
    (5 = cfg s 8)))                         ;  and pen come back as saved

; --- 15. replies: dsr, da, and the drain-once law ---
(: s (mkscr 4 10)
 _ (scribe s "\e[3;7H\e[6n")
 _ (test (= [27 91 51 59 55 82] (reply s))     ; "\e[3;7R"
           !(reply s))                        ; drained: quiet
 _ (scribe s "\e[c")
 _ (test ("\e[?62;4;22c" = string (reply s)))     ; a vt220, sixel (4) and ansi colour (22)
 _ (scribe s "\eZ")                              ; DECID: the vt102 answer it always gave
 _ (test (= [27 91 63 54 99] (reply s)))
 _ (scribe s "\e[5n")
 _ (test (= [27 91 48 110] (reply s))))        ; "\e[0n": all well

; --- 15b. the asks a line editor waits on: colour queries, secondary da ---
; (silence here cost a real second of buffered keystrokes at zsh startup)
(: s (mkscr 4 20)
 _ (scribe s "\e]11;?\x07")
 _ (test (= [27 93 49 49 59 114 103 98 58 48 48 48 48 47 48 48 48 48 47 48 48 48 48 7]
              (reply s)))                        ; bg: rgb:0000/0000/0000, bel-terminated
 _ (scribe s "\e]10;?\e\\")                      ; st-terminated ask, same answer lane
 _ (test (= [27 93 49 48 59 114 103 98 58 99 48 99 48 47 99 48 99 48 47 99 48 99 48 7]
              (reply s)))                        ; fg: rgb:c0c0/c0c0/c0c0
 _ (scribe s "\e]0;just a title\x07")
 _ (test !(reply s))                        ; a title is not a question
 _ (scribe s "\e[>c")
 _ (test (= [27 91 62 48 59 48 59 48 99] (reply s)))     ; secondary da
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
