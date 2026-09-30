; test/host/manifest.l -- the spreadsheet, engine and tui, end to end: the engine probed against
; the loaded app, the tui driven over a real pty and its screen read back through the cb glass.
; not in the corpus: init.l reaps by pid where this file holds a pty child.
; run: cat test/00-init.l test/host/manifest.l | out/love

(borrow 'manifest)

; --- formulas, the unit, labels, functions as cargo ---
(sheet 0 @ sh
 (cell! sh (\ a1) "5",
  cell! sh (\ b1) "a1 * 7",               ; infix goes bare, repl-style
  cell! sh (\ c1) "(+ a1 b1)",
  test (5 = worth sh (\ a1))
       (35 = worth sh (\ b1))
       (40 = worth sh (\ c1)),
  cell! sh (\ d1) "(+ a1 z9)",            ; z9 is empty: the unit rides
  test (5 = worth sh (\ d1)),
  cell! sh (\ e1) "hello",                ; a bare unknown name is a label
  cell! sh (\ f1) "\"port of call\"",     ; a string is text
  test ("hello" = worth sh (\ e1))
       ("port of call" = worth sh (\ f1)),
  cell! sh (\ g1) "(+ 2)",                ; a cell may hold a function
  cell! sh (\ h1) "(g1 40)",              ; ... and a neighbour may apply it
  test (42 = worth sh (\ h1)),
  cell! sh (\ a1) "10",                   ; an edit recomputes the dependents
  test (70 = worth sh (\ b1))
       (80 = worth sh (\ c1))))

; --- the whole language in a cell: arrays, scopes, higher order ---
(sheet 0 @ sh
 (cell! sh (\ a1) "3",
  cell! sh (\ i1) "@(1 2 3)",
  cell! sh (\ j1) "net i1",
  cell! sh (\ n1) "(: x 3 (x * a1))",     ; a local x shadows its label
  cell! sh (\ o1) "(map (+ a1) [1 2])",
  test (6 = worth sh (\ j1))
       (9 = worth sh (\ n1))
       ([4 5] = worth sh (\ o1))))

; --- cycles: flagged at every cell on the loop, and taint what reads them
; (a bare whirl is the unit and would otherwise ride quietly through) ---
(sheet 0 @ sh
 (cell! sh (\ k1) "l1 + 1",
  cell! sh (\ l1) "k1 + 1",
  cell! sh (\ m1) "(+ k1 5)",
  cell! sh (\ a1) "3",
  test ("cycle!" = face (worth sh (\ k1)))
       ("cycle!" = face (worth sh (\ l1)))
       ("cycle!" = face (worth sh (\ m1)))
       (3 = worth sh (\ a1))               ; clean cargo stays clean
       ("" = face ())                      ; an empty cell wears nothing
       ("5" = face 5),
  cell! sh (\ l1) "2",                    ; break the circle: all is forgiven
  test (3 = worth sh (\ k1))
       (8 = worth sh (\ m1))))

; --- stow / unstow: the sheet as one readable form, worths surviving ---
(: p "/tmp/manifest-boot-test.l"
 sh (sheet 0)
 _ (cell! sh (\ a1) "5")
 _ (cell! sh (\ b1) "a1 * 7")
 _ (cell! sh (\ e1) "\"line \\e[7m noise\"")   ; escapes must round-trip
 _ (test (stow sh p))
 sh2 (unstow (sheet 0) p)
 _ (test
    (cell sh2 (\ b1) = cell sh (\ b1))
    (35 = worth sh2 (\ b1))
    (worth sh (\ e1) = worth sh2 (\ e1))))

; --- the tui, over a real pty, the cb screen as witness: type a formula,
; sail right, type another that reads the first, watch the paint ---
(: (findi h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? i (findi h n (i + 1))) -1)
   (find h n i) !!(1 + findi h n i)
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (rowtx s r) (gaze s 2 @ c
                (foldl (a \ i \ (a + (2097151 & glass s (r * c + i) 0 @ ch (0 = ch ? " " (utf8 ch)))))
                       "" (jot c)))
 md (tether ["out/love" "manifest"])        ; the verb, as a hand types it
 m >md
 ; a reader task gathers every painted byte into a box, so the test can
 ; handshake: keys sent before the child's raw-mode first frame would land
 ; in a cooked pty (ICRNL eats the \r commit) -- wait for proof, then type
 buf {""}
 rd (twirl (_ \ (: (pump x) (see m @ ch
                              (ch = -1 ? () (pin buf () (peep buf () "" + string ch),
                                pump ())))
                  (pump ()))) 0)
 (await s tries) (: (aw t) (? (find (peep buf () "") s 0) 1
                              (t < 1) 0
                              (rest 30, aw (t - 1)))
                    (aw tries))
 _ (test (await "\e[?25l" 300))         ; the first frame: raw mode is up
 _ (say m "=10\r", flush m)               ; a1 = 10
 _ (test (await "a1: 10" 300))          ; committed: the bar shows the source
 _ (say m "\e[C", flush m)                ; sail right to b1
 _ (test (await "b1" 300))
 _ (say m "=a1 * 7\r", flush m)           ; b1 = a1 * 7
 _ (test (await "70" 300))              ; the worth painted
 _ (say m "q", flush m)                   ; step ashore
 st (: (wf p2) (gather p2 @ g2 (two? g2 ? g2 (rest 2, wf p2))) (wf <md))
 _ (catch rd)                             ; the reader drains to EOF and rests
 outb (peep buf () "")
 scr (mkscr 24 80)
 ; the tail "\e[?1049l" would bring the main grid back over the witness (the
 ; alternate screen's leave) -- scribe only the voyage, not the stepping-ashore
 shore (findi outb "\e[?1049l" 0)
 _ (scribe scr (-1 < shore ? (snip outb 0 shore) outb))
 row1 (rowtx scr 2)                       ; screen line 2 = sheet row 1
 (test (two? st) (0 = <st)              ; a clean exit
       (find outb "\e[?1049h" 0)             ; the alt screen was entered
       (find outb "\e[?1049l" 0)             ; ... and left
       (find row1 "10" 0)                    ; a1 painted
       (find row1 "70" 0)                    ; b1 = a1 * 7 painted
       (find (rowtx scr 0) "b1" 0),       ; the formula bar rode the cursor
  close m))

(test_fin ())
(puts "manifest: ok")
