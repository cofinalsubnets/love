; --- test/host/mc.l: the two-pane browser, headless ---
; every key is a pure step on the state and every frame a pure lay into a port, so all
; of mc but the tty gates here: the listing and its order, the four hues, the cursor and
; the window that follows it, tab, enter and its two refusals, the climb, and the frame
; -- whose rows must each be exactly the screen's width, which is the law mc leans on
; post.l's edfit for, and the one a byte count gets wrong the moment a name wears
; colour. the runner stays a live probe: `love mc`.
;   cat test/00-init.l test/host/mc.l | out/love

(borrow 'posix)
(borrow 'mc)

(: R "/tmp/mctest"
   ; the text under the escapes: an ESC and its sequence, up to the final letter, drop
   (plain s) ((: (g i acc esc) (i < #s ? (: c (s i)
                                     (? esc (g (i + 1) acc (65 <= c < 91 || 97 <= c < 123 ? 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0))) acc)) 0 "" 0)
   (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (has? h n) (find h n 0)
   (starts? s p) (p = snip s 0 #p)
   (blurt p s) (: q (open p "w") (hot? q && (say q s, close q, 1)))
   (scrub _) (each ["/sub/deep.txt" "/plain.txt" "/run.sh" "/good" "/bad" "/zeta.txt"]
                        (n \ unlink (R + n)),
              rmdir (R + "/sub"),
              rmdir R)

   ; --- the fixture: one of each class mc paints ------------------------------------
   ;   sub/ a directory   plain.txt a file   run.sh executable
   ;   good -> sub (resolves)   bad -> nowhere (does not)
   _ (scrub ())
   _ (mkdir R 493)
   _ (mkdir (R + "/sub") 493)
   _ (blurt (R + "/sub/deep.txt") "deep\n")
   _ (blurt (R + "/plain.txt") "hello\n")
   _ (blurt (R + "/run.sh") "#!/bin/sh\n")
   _ (chmod (R + "/run.sh") 493)
   _ (symlink "sub" (R + "/good"))
   _ (symlink "nowhere" (R + "/bad"))

   ; --- the listing: "..", the directories, then the rest, each by name -------------
   es (mc-read R)
   _ (test (= [".." "sub" "bad" "good" "plain.txt" "run.sh"] (map cap es)))
   _ (test !(mc-read (R + "/plain.txt")))     ; not a directory, so no listing
   _ (test !(mc-read (R + "/nosuch")))
   _ (test (".." != <(<(mc-read "/"))))             ; the root owes no ".."

   ; --- the four hues, off the same lstat the row already holds ---------------------
   (cellof n) (mc-cell R <(filter (e \ <e = n) es) 30 0)
   _ (test (starts? (cellof "sub") "\e[1;34m")      ; a directory
             (starts? (cellof "good") "\e[36m")     ; a link that resolves
             (starts? (cellof "bad") "\e[31m")      ; ..and one that does not
             (starts? (cellof "run.sh") "\e[32m")   ; the x bit
             (starts? (cellof "plain.txt") " "))    ; and a plain file wears nothing
   ; a coloured cell is still exactly its field wide -- the escapes cost no column
   _ (each ["sub" "good" "bad" "run.sh" "plain.txt"] (n \ test (30 = #(plain (cellof n)))))
   ; a name too long for the field is cut, not wrapped, and the size stays on the row
   _ (test (30 = #(plain (mc-cell R [(80 (\ s (s + "x")) "n") 33188 7] 30 0))))
   _ (test (has? (mc-cell R ["n" 16384 0] 30 0) "<dir>"))

   ; --- the cursor, and the window that follows it ----------------------------------
   p (mc-pane R)
   _ (test (0 = (p 'cur)) (0 = (p 'top)) (R = (p 'dir)) (".." = <(mc-at p)))
   _ (mc-goto p 3 4) _ (test (3 = (p 'cur)) (0 = (p 'top)))   ; still on a 4-row screen
   _ (mc-goto p 5 4) _ (test (5 = (p 'cur)) (2 = (p 'top)))   ; top slides just enough
   _ (mc-goto p 0 4) _ (test (0 = (p 'cur)) (0 = (p 'top)))
   _ (mc-goto p 99 4) _ (test (5 = (p 'cur)))                 ; neither end runs off
   _ (mc-goto p -9 4) _ (test (0 = (p 'cur)))

   ; --- the keys: every arm answers the state, which is what the stage loop takes back
   s (mc-new R R)
   _ (test (0 = (s 'act)) (0 = (s 'over)))
   _ (test (s = (mc-key s 122)))                    ; an idle key answers the state
   _ (mc-key s 106) _ (test (1 = ((s 'l) 'cur)))
   _ (mc-key s -9)  _ (test (2 = ((s 'l) 'cur)))
   _ (mc-key s 107) _ (test (1 = ((s 'l) 'cur)))
   _ (mc-key s 71)  _ (test (5 = ((s 'l) 'cur)))    ; G
   _ (mc-key s 103) _ (test (0 = ((s 'l) 'cur)))    ; g
   _ (mc-key s 9)   _ (test (1 = (s 'act)))         ; tab crosses
   _ (mc-key s 9)   _ (test (0 = (s 'act)))
   ; enter: into a directory, and into the one a link resolves to
   _ (mc-key s 106) _ (test ("sub" = <(mc-at (s 'l))))
   _ (mc-key s 10)  _ (test ((R + "/sub") = ((s 'l) 'dir)) (0 = ((s 'l) 'cur)))
   _ (mc-key s 117) _ (test (R = ((s 'l) 'dir)))    ; u climbs back
   _ (mc-key s 103) _ (mc-key s 106) _ (mc-key s 106) _ (mc-key s 106)
   _ (test ("good" = <(mc-at (s 'l))))
   _ (mc-key s 10)  _ (test ((R + "/good") = ((s 'l) 'dir)))
   _ (mc-key s 117) _ (test (R = ((s 'l) 'dir)))
   ; ..and the two it refuses: a broken link and a plain file leave the pane alone
   _ (mc-key s 103) _ (mc-key s 106) _ (mc-key s 106)
   _ (test ("bad" = <(mc-at (s 'l))))
   _ (mc-key s 10)  _ (test (R = ((s 'l) 'dir)))
   _ (mc-key s 71)  _ (test ("run.sh" = <(mc-at (s 'l))))
   _ (mc-key s 10)  _ (test (R = ((s 'l) 'dir)))
   ; r re-reads: a file made behind mc's back shows on the next read and not before
   _ (blurt (R + "/zeta.txt") "z\n")
   _ (test (6 = #((s 'l) 'es)))
   _ (mc-key s 114) _ (test (7 = #((s 'l) 'es)))
   _ (unlink (R + "/zeta.txt")) _ (mc-key s 114) _ (test (6 = #((s 'l) 'es)))
   ; q and ^D set over, and nothing else does
   _ (test (0 = (s 'over)))
   s2 (mc-new R R) _ (mc-key s2 113) _ (test (1 = (s2 'over)))
   s3 (mc-new R R) _ (mc-key s3 -7)  _ (test (1 = (s3 'over)))

   ; --- the frame: every row exactly the screen's width -----------------------------
   f (mc-frame (mc-new R R) 70 14)
   rows (split "\r\n" f)
   _ (test (14 = #rows))                            ; a row per screen line
   _ (each rows (r \ test (70 = #(plain r))))
   _ (test (has? (plain (rows 0)) R))               ; the header names the directory
   _ (test (has? (plain (rows 1)) "..")
             (has? (plain (rows 2)) "sub") (has? (plain (rows 2)) "<dir>"))
   _ (test (has? (plain (last rows)) "q quit"))
   ; the active pane's cursor is reversed, the idle pane's underlined, so tab comes back
   ; to where it left without either claiming the eye the other has
   _ (test (has? (rows 1) "\e[7m") (has? (rows 1) "\e[4m"))
   ; a screen too short for the furniture still lays one listing row
   _ (test (4 = #(split "\r\n" (mc-frame (mc-new R R) 40 4))))

   _ (scrub ())
   (test_fin ()))
(puts "mc: ok -- the listing and its hues, the cursor, tab, enter and its refusals, and a frame whose every row is the screen's width\n")
