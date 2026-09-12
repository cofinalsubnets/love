; ink -- quay's screensaver: a chromatophore shimmer for the terminal.
;
; the cuttlefish paints its skin: four drifting sine waves (three linear, one
; radial ripple) sampled over the window grid by galaxy broadcasting -- C does
; every cell -- then quantized onto a 256-color ocean ramp and said to the
; terminal as painted cells. any key returns you to shore.
;
; run: love ink
; the shimmer core is pure love -- ink-field builds the skin(t) tray and ink-pal
; pre-renders a ramp, so another caller brings its own colours and its own frame
; (a/rove/slop.l does); only the tty runner (ink) ties raw / tty / cue?, which
; ride i/posix.c, so ink never joins the test corpus (love0 links no host nifs)
; -- t/host/tty.l gives it a pty instead.
(module (ink ink-main ink-scene ink-field ink-pal)
; posix is OPTIONAL: the page's seat (i/wasm) links none of it, and this file runs
; there. ask before splicing -- an absent module is a scare, and the names below that
; want a tty go missing on that seat exactly as they did before there was a module.
(? (cite 'posix) (borrow 'posix) ())
(: esc (string 27)

   ; a ramp pre-rendered as SGR background runs, so a frame is pure lookup. the cell
   ; itself is the caller's, which is what lets one collapse a run of equal cells into
   ; a single pen. show: decimal digits (string of a charm is its CHAR)
   (ink-pal rs) (: (pen n) (esc + "[48;5;" + show n + "m")
                   (dab t i l) (? !l t (pin t i (pen <l), dab t (i + 1) >l))
                   (dab {0 (pen <rs)} 0 rs))
   ; the ocean: 24 chromatophores, deep blue out to pale pink and back
   ramp [17 18 19 20 26 32 38 44 45 51 87 123 159 195 189 183 147 111 75 69 63 57 25 24]
   pal (ink-pal ramp)

   ; the skin at size (r c): the grid built once, closed into a field(t) answering
   ; a tray of the whole window. (r 1) + (1 c) broadcasts to (r c); cy doubles y so
   ; the ripple is round in cell aspect (a cell is about twice as tall as wide).
   ; the net of the four waves lands in [-4, 4]
   (ink-field r c) (:
     ycol (star-tray [r 1] ^r)
     xrow (star-tray [1 c] ^c)
     y2 (ycol * 1.0 + xrow * 0.0)
     x2 (ycol * 0.0 + xrow * 1.0)
     cx (x2 - c / 2.0)
     cy ((y2 - r / 2.0) * 2.0)
     rr (1 / 2 $ cx * cx + cy * cy)
     (field t) (sin (x2 * 0.09 + t) +
                sin (y2 * 0.16 - t * 0.7) +
                sin ((x2 + y2) * 0.06 + t * 0.4) +
                sin (rr * 0.11 - t))
     field)

   ; the scene: the ocean ramp over the skin, as a frame(t) that runs headless
   ; into a jug -- the wasm console drives it. quantize to 24 ramp indices, say
   ; every cell, slurp it back as one write (home first; reset + newline per row)
   (ink-scene r c) (:
     field (ink-field r c)
     (row j k i q) (? (q < c) (: _ (say j (pal (int (peep k [i q] 0))), say j " ") (row j k i (+ q 1))) ())
     (rows j k i) (? (i < r) (: _ (row j k i 0) _ (say j (+ esc "[0m\n")) (rows j k (+ i 1))) ())
     (frame t) (: k (((field t + 4.001) * 2.9) // 1)
                  j (jug 0)
                (say j (+ esc "[H"),
                 rows j k 0,
                 slurp j))
     frame)

   ; ink -- the shimmer on the tty. the swim: paint, rest a beat, listen for a
   ; cue from shore. the frame goes out say's bulk lane -- one write(2) per frame.
   (ink _) (: ws (tty 1)
              rv (two? ws ? (<ws - 1) 0)          ; spare the last line: no scroll
              cv (two? ws ? >ws 0)
              r (1 < rv ? rv 23)                  ; a sizeless tty paints 23x80
              c (1 < cv ? cv 80)
              frame (ink-scene r c)
              (swim tick) (? (cue? 0) ()
                             (: f (frame (* tick 0.06))
                              (say out f,
                               rest 33,
                               swim (tick + 1))))
              _ (raw 1)
              _ (say out (+ esc (+ "[?1049h" (+ esc (+ "[?25l" (+ esc "[2J"))))))   ; alt screen, no cursor
              _ (swim 0)
              _ (see in)                                                            ; drink the cue
              _ (say out (+ esc (+ "[0m" (+ esc (+ "[?25h" (+ esc "[?1049l"))))))    ; shore
              _ (flush out)
              (raw 0))
   ink-usage "usage: love ink   (no options; any key returns you to shore)"
   (ink-main as) (? !(two? as) (ink ())
                     (say err ("ink: takes no arguments, not " + <as + "\n"), flush err, 2))
   _ (pins (cite 'verbs 'tab) 'ink (udoor 'ink ink-main ink-usage 1 1)))
) ; module ink
