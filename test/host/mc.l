; test/host/mc.l -- the two-pane browser, headless: every key a pure step, every frame a pure
; lay, every row exactly the screen's width even when a name wears colour
; run: cat test/00-init.l test/host/00-host.l test/host/mc.l | out/love

(borrow 'posix)
(borrow 'mc)

(: R "/tmp/mctest"
   (blurt p s) (open p "w" @ q (hot? q && (say q s, close q, 1)))
   (scrub _) (each ["/sub/deep.txt" "/plain.txt" "/run.sh" "/good" "/bad" "/zeta.txt"]
                        (n \ unlink (R + n)),
              rmdir (R + "/sub"),
              rmdir R)

   ; one of each class mc paints
   _ (scrub ())
   _ (mkdir R 493)
   _ (mkdir (R + "/sub") 493)
   _ (blurt (R + "/sub/deep.txt") "deep\n")
   _ (blurt (R + "/plain.txt") "hello\n")
   _ (blurt (R + "/run.sh") "#!/bin/sh\n")
   _ (chmod (R + "/run.sh") 493)
   _ (symlink "sub" (R + "/good"))
   _ (symlink "nowhere" (R + "/bad"))

   ; the listing: "..", the directories, then the rest, each by name
   es (mc-read R)
   _ (test ([".." "sub" "bad" "good" "plain.txt" "run.sh"] = map cap es))
   _ (test !(mc-read (R + "/plain.txt")))
   _ (test !(mc-read (R + "/nosuch")))
   _ (test (".." != <(<(mc-read "/"))))             ; the root owes no ".."

   (cellof n) (mc-cell R <(filter (e \ <e = n) es) 30 0)
   _ (test (starts? (cellof "sub") "\e[1;34m")
             (starts? (cellof "good") "\e[36m")     ; a link that resolves
             (starts? (cellof "bad") "\e[31m")      ; ..and one that does not
             (starts? (cellof "run.sh") "\e[32m")
             (starts? (cellof "plain.txt") " "))
   _ (each ["sub" "good" "bad" "run.sh" "plain.txt"] (n \ test (30 = #(h-plain (cellof n)))))
   ; a long name is cut, not wrapped
   _ (test (30 = #(h-plain (mc-cell R [(80 (s \ (s + "x")) "n") 33188 7] 30 0))))
   _ (test (has? (mc-cell R ["n" 16384 0] 30 0) "<dir>"))

   p (mc-pane R)
   _ (test (0 = p 'cur) (0 = p 'top) (R = p 'dir) (".." = <(mc-at p)))
   _ (mc-goto p 3 4, test (3 = p 'cur) (0 = p 'top))      ; still on a 4-row screen
   _ (mc-goto p 5 4, test (5 = p 'cur) (2 = p 'top))      ; top slides just enough
   _ (mc-goto p 0 4, test (0 = p 'cur) (0 = p 'top))
   _ (mc-goto p 99 4, test (5 = p 'cur))                    ; neither end runs off
   _ (mc-goto p -9 4, test (0 = p 'cur))

   ; every key arm answers the state, which the stage loop takes back
   s (mc-new R R)
   _ (test (0 = s 'act) (0 = s 'over))
   _ (test (s = mc-key s 122))                    ; an idle key answers the state
   _ (mc-key s 106, test (1 = s 'l 'cur))
   _ (mc-key s -9, test (2 = s 'l 'cur))
   _ (mc-key s 107, test (1 = s 'l 'cur))
   _ (mc-key s 71, test (5 = s 'l 'cur))          ; G
   _ (mc-key s 103, test (0 = s 'l 'cur))         ; g
   _ (mc-key s 9, test (1 = s 'act))              ; tab crosses
   _ (mc-key s 9, test (0 = s 'act))
   _ (mc-key s 106, test ("sub" = <(mc-at (s 'l))))
   _ (mc-key s 10, test (R + "/sub" = s 'l 'dir) (0 = s 'l 'cur))
   _ (mc-key s 117, test (R = s 'l 'dir))         ; u climbs back
   _ (mc-key s 103, mc-key s 106, mc-key s 106, mc-key s 106)
   _ (test ("good" = <(mc-at (s 'l))))
   _ (mc-key s 10, test (R + "/good" = s 'l 'dir))
   _ (mc-key s 117, test (R = s 'l 'dir))
   ; a broken link and a plain file leave the pane alone
   _ (mc-key s 103, mc-key s 106, mc-key s 106)
   _ (test ("bad" = <(mc-at (s 'l))))
   _ (mc-key s 10, test (R = s 'l 'dir))
   _ (mc-key s 71, test ("run.sh" = <(mc-at (s 'l))))
   _ (mc-key s 10, test (R = s 'l 'dir))
   ; r re-reads
   _ (blurt (R + "/zeta.txt") "z\n")
   _ (test (6 = #(s 'l 'es)))
   _ (mc-key s 114, test (7 = #(s 'l 'es)))
   _ (unlink (R + "/zeta.txt"), mc-key s 114, test (6 = #(s 'l 'es)))
   _ (test (0 = s 'over))
   s2 (mc-new R R) _ (mc-key s2 113, test (1 = s2 'over))
   s3 (mc-new R R) _ (mc-key s3 -7, test (1 = s3 'over))
   ; enter on a file goes to 'open when the runner lent one
   s4 (mc-new R R) got {0}
   _ (pin s4 'open (f \ pin got () f))
   _ (each ^4 (_ \ mc-key s4 106), mc-key s4 13, test ((peep got () 0) = (R + "/plain.txt")) (R = s4 'l 'dir))
   ; / : the files under the pane's directory, no link followed
   s6 (mc-new R R)
   _ (mc-key s6 47, test (!(nil? (s6 'seek))) (((s6 'seek) 'items) = [(R + "/plain.txt") (R + "/run.sh") (R + "/sub/deep.txt")]))
   _ (test (has? (h-plain (mc-frame s6 70 14)) "sub/deep.txt"))
   _ (each (map (i \ "deep" i) ^4) (c \ mc-key s6 c), mc-key s6 13)
   _ (test (nil? (s6 'seek)) ((R + "/sub") = s6 'l 'dir) (1 = s6 'l 'cur))
   _ (mc-key s6 47, mc-key s6 27, test (nil? (s6 'seek)) ((R + "/sub") = s6 'l 'dir))
   s5 (mc-new R R)
   _ (each ^4 (_ \ mc-key s5 106), mc-key s5 13, test (R = s5 'l 'dir) (0 = s5 'over))

   f (mc-frame (mc-new R R) 70 14)
   rows (split "\r\n" f)
   _ (test (14 = #rows))
   _ (each rows (r \ test (70 = #(h-plain r))))
   _ (test (has? (h-plain (rows 0)) R))
   _ (test (has? (h-plain (rows 1)) "..")
             (has? (h-plain (rows 2)) "sub") (has? (h-plain (rows 2)) "<dir>"))
   _ (test (has? (h-plain (last rows)) "q quit"))
   ; the active pane's cursor reversed, the idle pane's underlined
   _ (test (has? (rows 1) "\e[7m") (has? (rows 1) "\e[4m"))
   ; a screen too short for the furniture still lays one listing row
   _ (test (4 = #(split "\r\n" (mc-frame (mc-new R R) 40 4))))

   ; quick view: the other pane looks inside the cursor's entry
   ; width in columns: the half block is three bytes, one column
   (wid s) (: t (h-plain s) (g i a) (#t <= i ? a (g (i + 1) (a + (128 <= t i < 192 ? 0 1)))) (g 0 0))
   (lawful f w) (each (split "\r\n" f) (r \ test (w = wid r)))
   (any? f s) (two? (filter (r \ has? r s) (split "\r\n" f)))
   P "/tmp/mctest-pic"
   (pscrub _) (each ["/a.png" "/b.gif" "/c.txt" "/d.bin"] (n \ unlink (P + n)), rmdir P)
   (rgba w h) (cask (4 * w * h) @ c
               ((each ^(w * h) (i \ pins c (4 * i) (i * 37 % 256) (4 * i + 1) (i * 11 % 256)
                                            (4 * i + 2) 200 (4 * i + 3) 255)),
                string c))
   _ (pscrub ())
   _ (mkdir P 493)
   _ (blurt (P + "/a.png") (cite 'png 'png-encode 8 6 (rgba 8 6)))
   _ (blurt (P + "/b.gif") (cite 'gif 'gif-encode 5 4 (rgba 5 4)))
   _ (blurt (P + "/c.txt") ("one" + string 9 + "tab" + string 1 + "\nsecond line\n"))
   _ (blurt (P + "/d.bin") (string 127 + "ELF" + string 0 + string 2))
   q (mc-new P P)
   _ (test ([".." "a.png" "b.gif" "c.txt" "d.bin"] = map cap (q 'l 'es)))
   _ (mc-key q 106, mc-key q 118)
   _ (test (1 = q 'qv))
   f1 (mc-frame q 70 16)
   _ (test (16 = #(split "\r\n" f1)))
   _ (lawful f1 70)
   _ (test (any? f1 "▀") (any? f1 " a.png") (any? f1 "8x6  png"))
   _ (test (has? (h-plain <(split "\r\n" f1)) "view a.png"))
   _ (test (has? (h-plain ((split "\r\n" f1) 1)) ".."))  ; the active pane still lists
   _ (test (two? (filter (r \ has? r "▀" && has? <(split "▀" r) "|") (split "\r\n" f1))))
   _ (mc-key q 106) f2 (mc-frame q 70 16)                ; a gif
   _ (lawful f2 70, test (any? f2 "▀") (any? f2 "5x4  gif"))
   _ (mc-key q 106) f3 (mc-frame q 70 16)                ; text: a tab laid out, ^A shown
   _ (lawful f3 70, test (any? f3 "one     tab^A") (any? f3 "second line") !(any? f3 "▀"))
   _ (mc-key q 106) f4 (mc-frame q 70 16)                ; a nul: a dump
   _ (lawful f4 70, test (any? f4 "000000  7f 45 4c 46 00 02") (any? f4 ".ELF.."))
   _ (mc-key q 103) f5 (mc-frame q 70 16)                ; a directory: its count
   _ (lawful f5 70, test (any? f5 " entr"))
   _ (mc-key q 118, test (0 = q 'qv))
   f6 (mc-frame q 70 16)
   _ (lawful f6 70, test !(any? f6 "▀") (any? f6 "b.gif") (any? f6 "d.bin"))
   ; tab while viewing: the view moves to the pane just left
   _ (mc-key q 17, mc-key q 9, mc-key q 106)
   f7 (mc-frame q 70 16)
   _ (lawful f7 70, test (any? f7 "▀"))
   _ (test (two? (filter (r \ has? r "▀" && !(has? <(split "▀" r) "|")) (split "\r\n" f7))))
   _ (mc-key q 17, mc-key q 9)
   ; thumbnails: the pictures as tiles, the cursor's name reversed
   _ (mc-key q 106, mc-key q 116, test (2 = q 'qv))
   g1 (mc-frame q 70 16)
   _ (lawful g1 70)
   _ (test (any? g1 "▀") (any? g1 "a.png") (any? g1 "b.gif") (any? g1 "\e[7m a.png"))
   _ (test (any? g1 "thumbnails /tmp/mctest-pic"))
   _ (mc-key q 116, test (0 = q 'qv))
   ; a dear decode waits: no budget shows "..." and owes it
   q2 (pins (mc-new P P) 'cheap 0 'budget 0)
   _ (mc-key q2 106, mc-key q2 118)
   f8 (mc-frame q2 70 16)
   _ (test (any? f8 "...") !(any? f8 "▀") (1 = q2 'owe))
   _ (pin q2 'budget 1) f9 (mc-frame q2 70 16)
   _ (test (any? f9 "▀") (0 = q2 'owe) (0 = q2 'budget))
   _ (pin q2 'budget 0, test (any? (mc-frame q2 70 16) "▀"))      ; ..and the cache keeps it
   ; past the cap a picture is named and not decoded
   q3 (pins (mc-new P P) 'cap 10)
   _ (mc-key q3 106, mc-key q3 118)
   _ (test (any? (mc-frame q3 70 16) "too big to show") (any? (mc-frame q3 70 16) "8x6  png"))
   ; sixel and kitty lay the picture after the text; kitty drops the old one only when it
   ; changed or the view closes
   q4 (pins (mc-new P P) 'gm "sixel" 'cw 2 'ch 4)
   _ (mc-key q4 106, mc-key q4 118)
   s1 (mc-frame q4 70 16)
   _ (test (has? s1 "P0;1;0q") !(any? s1 "▀"))
   _ (each (take 15 (split "\r\n" s1)) (r \ test (70 = wid r)))
   q5 (pins (mc-new P P) 'gm "kitty" 'cw 2 'ch 4)
   _ (mc-key q5 106, mc-key q5 118)
   k1 (mc-frame q5 70 16) k2 (mc-frame q5 70 16)
   _ (test (has? k1 "\e_Ga=d") (has? k1 "\e_Ga=T") (has? k2 "\e_Ga=p,i=7") !(has? k2 "\e_Ga=T") !(has? k2 "\e_Ga=d"))
   _ (mc-key q5 118) k3 (mc-frame q5 70 16)
   (test (has? k3 "\e_Ga=d") !(has? k3 "\e_Ga=T"),
    test ("one     " = mc-vis ("one" + string 9)) ("^A^?" = mc-vis (string 1 + string 127)),
    pscrub (),

    scrub (),
    test_fin ()))
(puts "mc: ok -- the listing and its hues, the cursor, tab, enter and its refusals, and a frame whose every row is the screen's width\n")
