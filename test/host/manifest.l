; test/host/manifest.l -- the spreadsheet: the engine probed, the tui driven over a pty and
; its screen read back through a scribed screen
; run: cat test/00-init.l test/host/00-host.l test/host/manifest.l | out/love

(borrow 'manifest)

; formulas, the unit, labels, functions as cargo
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

; the whole language in a cell
(sheet 0 @ sh
 (cell! sh (\ a1) "3",
  cell! sh (\ i1) "@(1 2 3)",
  cell! sh (\ j1) "net i1",
  cell! sh (\ n1) "(: x 3 (x * a1))",     ; a local x shadows its label
  cell! sh (\ o1) "(map (+ a1) [1 2])",
  test (6 = worth sh (\ j1))
       (9 = worth sh (\ n1))
       ([4 5] = worth sh (\ o1))))

; cycles flag every cell on the loop and taint what reads them (a bare whirl is the unit)
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

; stow / unstow round-trip
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

; the tui over a pty: a1, then b1 reading it, watched on the screen
(: (findi h n i) (i + #n < #h + 1 ? (n = snip h i (i + #n) ? i (findi h n (i + 1))) -1)
   (rowtx s r) (gaze s 2 @ c
                (foldl (a \ i \ (a + (2097151 & glass s (r * c + i) 0 @ ch (0 = ch ? " " (utf8 ch)))))
                       "" (jot c)))
 md (tether ["out/love" "manifest"])
 m >md
 ; keys sent before the first raw-mode frame land cooked (ICRNL eats the \r commit)
 buf {""}
 rd (twirl (_ \ (: (pump x) (see m @ ch
                              (ch = -1 ? () (pin buf () (peep buf () "" + string ch),
                                pump ())))
                  (pump ()))) 0)
 (await s tries) (: (aw t) (? (has? (peep buf () "") s) 1
                              (t < 1) 0
                              (rest 30, aw (t - 1)))
                    (aw tries))
 _ (test (await "\e[?25l" 300))         ; the first frame: raw mode is up
 _ (say m "=10\r", flush m)
 _ (test (await "a1: 10" 300))          ; committed: the bar shows the source
 _ (say m "\e[C", flush m)
 _ (test (await "b1" 300))
 _ (say m "=a1 * 7\r", flush m)
 _ (test (await "70" 300))
 _ (say m "q", flush m)
 st (: (wf p2) (gather p2 @ g2 (two? g2 ? g2 (rest 2, wf p2))) (wf <md))
 _ (catch rd)
 outb (peep buf () "")
 scr (h-mkscr 24 80)
 ; scribe up to the alt screen's leave, which would bring the main grid back
 shore (findi outb "\e[?1049l" 0)
 _ (scribe scr (-1 < shore ? (snip outb 0 shore) outb))
 row1 (rowtx scr 2)                       ; screen line 2 = sheet row 1
 (test (two? st) (0 = <st)
       (has? outb "\e[?1049h")
       (has? outb "\e[?1049l")
       (has? row1 "10")
       (has? row1 "70")
       (has? (rowtx scr 0) "b1"),       ; the formula bar rode the cursor
  close m))

(test_fin ())
(puts "manifest: ok")
