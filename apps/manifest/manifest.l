; manifest -- the spreadsheet: a ship's manifest for values.
;
; every cell is a love expression, read repl-style (wrapped in parens, so
; infix goes bare: `a1 * 2`). a cell that names other cells compiles as a
; lambda over its dependencies -- b1 holding "a1 * 7" becomes (\ a1 (a1 * 7))
; applied to a1's worth -- computed on demand, memoized, a visiting set
; standing watch for cycles. an empty cell is (), the unit, so it rides
; through any arithmetic the way nothing should. a bare unknown name is its
; own spelling (labels for free); known globals stay free, so a cell may use
; the whole language -- and a cell may hold a function: g1 = "(+ 2)" and
; h1 = "(g1 40)" is 42. everything is a function, now with a cursor.
;
; the sheet is a little book: slot 0 the sources (nom -> string), slot 1 the
; worth cache (cleared whole on any edit -- the painter refills only what it
; shows), slot 2 the visiting watch.
;
; run: love manifest [FILE]   -- bare, it sails without one
; keys: arrows/hjkl move . enter edits the cell (= starts fresh) . x clears
;       w stows . q stows and steps ashore . ^C abandons ship . eof leaves
;
; the engine is pure core (ev/sound/tap), and every key is a pure step on a state
; tablet and every frame a pure lay into a port -- only `manifest` ties the tty, on
; cli's stage. test/host/manifest.l probes the engine, and the tui end to end through
; a pty with the cb screen as the witness.
;
; the export list is the engine a caller can hold, the headless tui, and the verb;
; the reader and the dep walk are this file's own business. quoted, per prel's note
; on the list head.
(module '(manifest manifest-main manifest-new manifest-frame manifest-key
          sheet cell cell! worth face stow unstow)
(borrow 'posix)
(borrow 'tui)
(:
 ; --- reading a cell: repl-style, one form, unreadable text is a label ---
 (glean s) (sound (+ "(" (+ s ")")) @ (d . _) (two? d ? d))

 ; --- the cell-name shape: one letter, then digits (a1 .. z999) ---
 (cell? n) (? (name? n) (: s (string n) t (tally s)
            (1 < t < 5 &&
             97 <= s 0 <= 122 &&
             (: (digs i) (i >= t || (48 <= s i <= 57 ? (digs (i + 1))))) 1)))

 ; --- the book of known names, laid once on first use: a name off this
 ; book and off the sheet is a label and binds to its own spelling ---
 known {}
 (knowns _) (0 = #known ?
                  (map (n \ pin known n 1) (names ()),
                   ; the reader-emitted noms ride formulas but sit off the book (the egg mops
                   ; them): @(..) reads as (tuple ..), backtick as (list ..), the printer round-
                   ; trips spread/mono. off `known` they'd be collected as deps and the formula
                   ; lambda would shadow the real constructor -- which only ever worked because
                   ; feel's fold resolved the head shadow-blind at compile (the glaze compiles
                   ; the honest lexical surface and applied the dep's spelling instead).
                   map (n \ pin known n 1) '(tuple list spread mono)),
             known)
 (label? n) (name? n && !(cell? n) && !(peep (knowns ()) n 0) && 97 <= string n 0 <= 122)

 ; --- dependencies: every cell-shaped or label name in the form, deduped,
 ; in first-sight order (quote interiors over-collect; binding is harmless
 ; there -- quoted data keeps its symbols) ---
 (walkdeps f seen acc) (? (two? f)
                           (walkdeps >f seen (walkdeps <f seen acc))
                          ((cell? f || label? f) && !(peep seen f 0))
                           (pin seen f 1, acc + [f])
                          acc)
 (deps f) (walkdeps f (tablet 0) ())

 ; --- the sheet ---
 (sheet _) {0 {} 1 {} 2 {} 3 0}   ; 3: the whirl count
 none (mint 0)     ; the private absent-marker (() is a real worth)
 whirl (mint 0)    ; the cycle's face: unforgeable, nothing, shown "cycle!"

 (cell! sh n s) (#s ? (pin (sh 0) n s) (pull (sh 0) n 0),
                 pin sh 1 {},
                 sh)
 (cell sh n) (peep (sh 0) n ())

 ; --- worth: demand-evaluate, memoize. the formula becomes a lambda over
 ; its deps and is applied to their worths (cells recurse; labels are their
 ; spelling), so nothing global is touched and no missing ever fires ---
 (worth1 sh s) (: f (glean s)
                  (? (one? f) s                        ; unreadable: the text itself
                   (: ds (deps f)
                      lam (ev $ !ds ? f (['\] + ds + [f]))
                      vs (map (d \ cell? d ? (worth sh d) (string d)) ds)
                      (? (foldl (a \ v \ v = whirl || a) 0 vs)
                         whirl                          ; a whirl dep taints (it would ride as the unit)
                         (foldl id lam vs)))))
 ; a visiting-hit bumps the whirl count; any cell whose evaluation window saw
 ; a bump answers whirl itself, so the cycle wears its face at every cell on
 ; the loop (a bare whirl is a mint -- the unit -- and would otherwise ride
 ; through the arithmetic and let a circle quietly converge).
 (worth sh n) (: v (peep (sh 1) n none)
                 (? (v != none) v
                  (peep (sh 2) n 0) (pin sh 3 (1 + peep sh 3 0), whirl)
                  (: s (peep (sh 0) n none)
                     (s = none ? ()                 ; an empty cell is the unit
                      (: _ (pin (sh 2) n 1)
                         c0 (peep sh 3 0)
                         v1 (worth1 sh s)
                         v2 (c0 < peep sh 3 0 ? whirl v1)
                         (pull (sh 2) n 0,
                          pin (sh 1) n v2,
                          v2))))))

 ; --- stow / unstow: the sheet as one readable form ---
 (stow sh path) (: p (open path "w")
                 (lit? p ?
                  (say p "(manifest\n",
                   map (\ n (say p $ " (" + string n + " " + show (peep (sh 0) n "") + ")\n"))
                       (sort (keys (sh 0))),
                   say p ")\n",
                   flush p,
                   close p,
                   1)))
 (unstow sh path) (: p (open path "r")
                     (? !(lit? p) sh
                      (: t (slurp p)
                         r (sound t)
                         d (two? r ? <r)
                         (close p,
                          two? d && <d = 'manifest ?  (map (pr \ cell! sh <pr <>pr) >d),
                          sh))))

 ; --- faces: how a worth looks in its 9 columns ---
 ; cli's edwide counts display columns, so a wide character costs the two it takes
 (padl s w) (: t (edcut s w) ((w - edwide t) (x \ " " + x) t))
 (padr s w) (edfit s w " ")
 (face v) (? (v = whirl) "cycle!"
             (v = ()) ""
             (string? v) v
             (show v))

 ; --- the tui: a state tablet, a pure frame, a pure key -- cli's stage drives ---
 ; {'sh 'path 'cx 'cy 'top 'edit 'over 'w 'h}, the shape lupa and mc hold. the stage
 ; brackets raw mode and the alternate screen, re-reads the tty every keystroke (so a
 ; resize lands), and decodes keys through edkey; eof leaves.
 (upto n f) ((: (go i) (i < n ? (f i, go (i + 1)))) 0)
 (cnom cx cy) (name $ string (97 + cx) + show (cy + 1))
 (min2 a b) (a < b ? a b)
 (max2 a b) (a < b ? b a)
 (mrows h) (max2 1 (h - 3))                    ; the sheet's rows: bar, header and stern take 3
 (mcols w) (max2 1 (min2 26 ((w - 5) // 10)))  ; 26 columns at 10 wide, past the 5-wide gutter

 (manifest-new sh path)
  (pins {} 'sh sh 'path path 'cx 0 'cy 0 'top 0 'edit () 'over () 'w 80 'h 24)

 ; top moves only far enough to keep the cursor on the screen, so a page reads as a page
 (settle d h) (pin d 'top (tui-settle (d 'cy) (d 'top) (mrows h)))

 (drawcell j sh i cy sel) (: v (worth sh (cnom i cy))
                             t (face v)
                             t2 (constellation? v ? (padl t 9) (padr t 9))
                           (sel ? (say j "\e[7m"),
                            say j t2,
                            sel ? (say j "\e[0m"),
                            say j " "))

 (manifest-frame d w h) (:
    _ (pins d 'w w 'h h)
    _ (settle d h)
    sh (d 'sh) path (d 'path) cx (d 'cx) cy (d 'cy) top (d 'top) edit (d 'edit)
    nr (mrows h)
    nc (mcols w)
    cur (cnom cx cy)
    j (jug 0)
    _ (say j "\e[?25l\e[H")
    ; the formula bar: cell name, then the edit line or the stowed source
    src (string $ cell sh cur)
    bar (string cur + (string? edit ? " = " ": ") + (string? edit ? edit src))
    (say j (padr bar (w - 1)),
     say j "\e[K\r\n",
     ; the header row: column letters, the cursor's lit
     say j "    ",
     upto nc (\ i (: t (padl (string (97 + i) + "    ") 7)
                   (i = cx ? (say j "\e[7m"),
                    say j (padr t 9),
                    i = cx ? (say j "\e[0m"),
                    say j " "))),
     say j "\e[K\r\n",
     ; the sheet
     upto nr (\ k (: cy2 (top + k)
                   (say j (padl (show (cy2 + 1)) 3),
                    say j " ",
                    upto nc (i \ drawcell j sh i cy2 (i = cx && cy2 = cy)),
                    say j "\e[K\r\n"))),
     ; the stern: keys, or the editing hint
     say j (padr (string? edit ?
                       "enter commits . esc steps back"
                       ((tally path ? (path + " . ") "") +
                        "arrows move . enter edits . = fresh . x clears . w stows . q quits"))
                    (w - 1)),
     say j "\e[J",
     ; editing: the terminal cursor rides the formula bar's end
     string? edit ?
      (say j (+ "\e[1;" (+ (show (+ (tally (string cur)) (+ 4 (tally edit)))) "H\e[?25h"))),
     (slurp j)))

 ; one key, one step on the tablet. the codes are cli's edkey: arrows are the
 ; negatives, a byte is itself
 (manifest-key d k) (:
    sh (d 'sh) path (d 'path) cx (d 'cx) cy (d 'cy) edit (d 'edit)
    nc (mcols (d 'w))
    cur (cnom cx cy)
    (? (string? edit)
       (k @ (13 || 10) (cell! sh cur edit, pin d 'edit ())
            27 (pin d 'edit ())
            (127 || 8) (pin d 'edit (#edit ? (snip edit 0 (#edit - 1)) edit))
            (pin d 'edit $ edit + (32 <= k < 127 ? (string k))))
       (k @ (-8 || 107) (pin d 'cy (max2 0 (cy - 1)))                 ; up
            (-9 || 106) (pin d 'cy (min2 98 (cy + 1)))                ; down
            (-2 || 108) (pin d 'cx (min2 (nc - 1) (cx + 1)))          ; right
            (-1 || 104) (pin d 'cx (max2 0 (cx - 1)))                 ; left
            13 (pin d 'edit (cell sh cur @ () "" s s))
            61 (pin d 'edit "")                                       ; = : a fresh formula
            120 (cell! sh cur "")                                     ; x : clear
            119 (#path && stow sh path, d)                            ; w : stow
            113 (#path && stow sh path, pin d 'over 1)                ; q : stow, step ashore
            3 (pin d 'over 1)                                         ; ^C: abandon ship
            d)))

 (manifest path) (: sh (sheet 0)
                    _ (tally path ? (unstow sh path))
                    d (manifest-new sh path)
                    (stage (manifest-frame d) (manifest-key d) (_ \ d 'over)))

 manifest-usage "usage: love manifest [FILE]   (arrows move . enter edits . w stows . q quits)"
 (manifest-main as) (? (one? as) (manifest "", 0)
                       (one? >as) (manifest <as, 0)
                       (say err "manifest: one sheet at a time\n", flush err, 2))
 _ (pins (cite 'verbs 'tab) 'manifest
         (udoor 'manifest manifest-main manifest-usage 1 1)))
) ; module manifest
