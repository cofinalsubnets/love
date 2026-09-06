; story -- rove's fiction engine: the zork half over the rogue half.
;
; a level is data: rooms with text, exits and things, and a thing is a book to read
; or a file to open. the turn is a line -- look, go, read, open, quit -- and the
; painter says one frame of the room, its exits, the log and the prompt into any
; port, so turns and frames gate headless (test/host/story.l). no combat, mobs or
; procgen: the crawl (rove.l) is a hatch in the hall, and opening it runs it.
;
; the library: a room per crew module under a root, a book per file in it. a room's
; text is the module's header as libra lifts it, reading a book is its own header,
; and opening one is vi, called in place -- on a seat that has vi.
; the page has no tree to read, so it walks the demo level (src/port/wasm/web.l).
;
; usage: out/love -l src/apps/rove/story.l -e '(library-story ())'   the tree's library
;        out/love -l src/apps/rove/story.l -e '(lighthouse ())'      the demo level
; only the tty runner ties the tty (raw/winsize ride src/host/posix.c); the crew
; modules it reaches for -- vi, libra -- are asked by name at the call, so this file
; loads on a seat that lacks them and says so instead.

(:
 ; --- levels as data ------------------------------------------------------------
 ; room: {'name 'text 'exits {word id ..} 'things {word thing ..}}
 ; thing: {'name 'text 'file}: text is what `read` shows, file what `open` opens
 (room nm txt exits things) {'name nm 'text txt 'exits exits 'things things}
 (thing nm txt f) {'name nm 'text txt 'file f}
 (level title rooms start) {'title title 'rooms rooms 'start start}

 demo-level
  (level "the lighthouse"
   {'lamp  (room "the lamp room" "glass on every side, and the sea below. the lamp turns.\nstairs lead down."
                 {'down 'stair} {'lamp (thing "the lamp" "a fresnel lens the size of a rowboat, humming." ())})
    'stair (room "the stair" "a spiral of iron steps. up is light; down is the door."
                 {'up 'lamp 'down 'door} {})
    'door  (room "the door" "the keeper's door, ajar on the rocks. the stair climbs back up."
                 {'up 'stair} {'sign (thing "the sign" "KEEPER OUT. BACK BY THE NEXT TIDE." ())})}
   'lamp)

 ; --- the state: where you are, what was said ------------------------------------
 (story-new lvl) {'lvl lvl 'at (lvl 'start) 'log () 'over 0 'line ""}
 (here g) (peep (g 'lvl 'rooms) (g 'at) 0)
 (say-to g s) (pin g 'log (s . g 'log))
 (words s) (filter (w \ 0 < #w) (split " " s))
 (joins l sp) (? !(two? l) "" !(two? >l) <l (<l + sp + joins >l sp))
 (exits-of r) (joins (map show (sort (keys (r 'exits)))) ", ")
 (things-of r) (joins (map (k \ (peep (r 'things) k 0) 'name) (sort (keys (r 'things)))) ", ")
 (describe g) (: r (here g)
                 _ (say-to g ("-- " + r 'name + " --"))
                 _ (say-to g (r 'text))
                 _ (keys (r 'things) ? (say-to g ("here: " + things-of r)))
                 (say-to g ("exits: " + exits-of r)))

 ; the crew modules a turn reaches for, by name at the call: () on a seat without them
 (mod nm k) (from nm k)

 ; read: a thing's text, or its file's header as libra lifts it
 (read-thing g t) (: f (t 'file)
                      lift (mod 'libra 'ldoc-md)
                      (? (0 < #(t 'text)) (say-to g (t 'text))
                         !f (say-to g "there is nothing written on it.")
                         !lift (say-to g "you cannot read here.")
                         (: q (open f "r")
                            (? !(hot? q) (say-to g ("the book is missing: " + f))
                               (: s (slurp q) _ (close q) md (lift s)
                                  (say-to g (0 < #md ? md "the pages are blank.")))))))
 ; open: the file in vi, called in place -- it takes the tty and gives it back -- or
 ; the hatch, which is the crawl, called the same way
 (open-thing g t) (: f (t 'file)
                      vi (mod 'vi 'vi-main)
                      (? (= f 'hatch) (: _ ((ev 'rove) ()) (say-to g "you climb back out of the hold."))
                         !f (say-to g "it does not open.")
                         !vi (say-to g "no editor on this seat.")
                         (: _ (vi [f]) (say-to g ("you close " + t 'name + ".")))))

 ; one turn: a line becomes a verb and a noun; the log says what came of it
 (story-turn g ln) (:
   ws (words ln) v (? (two? ws) <ws "") n (? (two? >ws) <>ws "")
   r (here g)
   (go w) (: to (peep (r 'exits) (nom w) 0)
             (? to (pin g 'at to, describe g) (say-to g ("you cannot go " + w + "."))))
   (with w f) (: t (peep (r 'things) (nom w) 0)
                 (? t (f t) (say-to g ("there is no " + w + " here."))))
   _ (0 < #ln ? (say-to g ("> " + ln)))
   _ (v @ "" ()
          ("look" || "l") (describe g)
          ("go" || "walk") (0 < #n ? (go n) (say-to g "go where?"))
          ("read" || "r") (0 < #n ? (with n (t \ read-thing g t)) (say-to g "read what?"))
          ("open" || "o") (0 < #n ? (with n (t \ open-thing g t)) (say-to g "open what?"))
          ("exits" || "x") (say-to g ("exits: " + exits-of r))
          ("help" || "h" || "?") (say-to g "look, go <exit>, read <thing>, open <thing>, exits, quit -- or a bare exit.")
          ("quit" || "q") (pin g 'over 'quit)
          (? (peep (r 'exits) (nom v) 0) (go v) (say-to g ("you cannot " + ln + "."))))
   g)

 ; --- the painter: one frame into a port -----------------------------------------
 ; the title bar, then the log from the top with the newest at the foot, the prompt
 ; last; long lines wrap at the width. the port is any jug, so frames gate headless.
 (wrap s w) (: (go ws cur acc) (? !(two? ws) (rev (cur . acc))
                                  (: nx (0 < #cur ? (cur + " " + <ws) <ws)
                                     (? (#nx <= w) (go >ws nx acc)
                                        (0 < #cur) (go ws "" (cur . acc))
                                        (go >ws "" ((snip nx 0 w) . acc)))))
               (go (words s) "" ()))
 (concat ls) (foldl (\ a l (cat a l)) () ls)               ; cat is the pairwise append
 (lines-of s w) (concat (map (l \ wrap l w) (split "\n" s)))
 (story-frame g w h) (: j (jug 0)
                        r (here g)
                        bar (: t (g 'lvl 'title + " -- " + r 'name) (#t < w ? (t + ((w - #t) (\ s (s + " ")) "")) (snip t 0 w)))
                        body (h - 2)
                        ls (concat (map (s \ lines-of s w) (rev (g 'log))))
                        n #ls
                        shown (n <= body ? ls (drop (n - body) ls))
                        _ (say j ("\e[H\e[0m\e[7m" + bar + "\e[0m\e[K\r\n"))
                        _ (each shown (l \ say j (l + "\e[K\r\n")))
                        _ ((body - #shown) (\ _ (say j "\e[K\r\n")) ())
                        _ (say j ("> " + g 'line + "\e[K"))
                        (slurp j))

 ; --- the library: a room per crew module under root, a book per file -----------
 (base p) (: n #p (go k r) (k < n ? (go (k + 1) (p k = 47 ? (k + 1) r)) (snip p r n)) (go 0 0))
 (ends? s t) (: n #s m #t ((m <= n) && (snip s (n - m) n = t)))
 (first-para md) (: ls (split "\n" md)
                    (go l acc) (? !(two? l) acc
                                  (0 < #(<l) && !(<l 0 = 35)) (go >l (0 < #acc ? (acc + " " + <l) <l))
                                  (0 < #acc) acc
                                  (go >l acc))
                    (go ls ""))
 (head-of f) (: q (open f "r") lift (mod 'libra 'ldoc-md)
                (? (hot? q && lift) (: s (slurp q) _ (close q) (first-para (lift s))) ""))
 (library root) (:
   dirs (sort (filter (d \ two? (readdir (root + "/" + d))) (readdir root)))
   (wing d) (: p (root + "/" + d)
               fs (sort (filter (f \ ends? f ".l") (readdir p)))
               main (p + "/" + d + ".l")
               txt (: t (head-of main) (0 < #t ? t ("the " + d + " wing. shelves of source.")))
               books (foldl (\ t f (pin t (nom (snip f 0 (#f - 2))) (thing f "" (p + "/" + f)))) {} fs)
               (room ("the " + d + " wing") txt {'out 'hall} books))
   rooms (foldl (\ t d (pin t (nom d) (wing d))) {} dirs)
   hall (room "the hall" ("the library of the crew. a door for every wing: " + joins dirs ", " + ".\nunder a grating, a hatch to the hold.")
              (foldl (\ t d (pin t (nom d) (nom d))) {} dirs)
              {'hatch (thing "the hatch" "" 'hatch)})
   _ (pin rooms 'hall hall)
   (level "the library" rooms 'hall))

 ; --- the runner: the story on the tty, a line at a time ----------------------------
 (story lvl) (: ws (winsize 0)
                h (two? ws && 7 < <ws ? <ws 24)
                w (two? ws && 19 < <>ws ? <>ws 80)
                g (story-new lvl)
                _ (raw 1, say out "\e[?1049h\e[?25l\e[2J", describe g)
                (show _) (say out (story-frame g w h))
                (line _) (: c (see in)
                            (? (c = 13 || c = 10) (: l (g 'line) _ (pin g 'line "") l)
                               (c = 27 || c = 3 || c = -1) 'quit
                               (c = 127 || c = 8) (: l (g 'line) _ (0 < #l ? (pin g 'line (snip l 0 (#l - 1)))) (show (), line ()))
                               (32 <= c < 127) (pin g 'line (g 'line + string c), show (), line ())
                               (line ())))
                (sail _) (: _ (show ())
                            l (line ())
                            (? (= l 'quit) () (: _ (story-turn g l) (? (g 'over) () (sail ())))))
                (sail (), say out "\e[0m\e[?25h\e[?1049l", flush out, raw 0, 0))
 (lighthouse _) (story demo-level)                    ; the demo, by the name the page boots it
 (library-story _) (story (library "src/apps"))
 (story-main as) (story (two? as ? (library <as) demo-level)))
