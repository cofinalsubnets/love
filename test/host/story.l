; --- test/host/story.l: rove's fiction engine, headless ---
; not in the test/*.l corpus (it loads a crew file and reads the tree). the engine is
; pure love, so everything but the tty runner gates here: a turn (look, go, read, a bare
; exit, a refusal), the frame (title bar, the log, the prompt, wrapping), and the
; library lifted from src/apps -- a room per wing, a book per file, a book's text
; libra's lift of its header. the runner, vi through the door and the hatch stay
; live probes: `love -l src/apps/rove/story.l -e '(library-story ())'`.
;   cat test/00-init.l test/host/story.l | out/love

(reads (open "src/apps/rove/story.l" "r"))

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   ; the text under the escapes: an ESC and its CSI sequence, up to the final letter, drop
   (plain s) ((: (g i acc esc) (? (i < #s)
                                  (: c (s i)
                                     (? esc (g (i + 1) acc (? (65 <= c < 91 || 97 <= c < 123) 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0)))
                                  acc)) 0 "" 0)

   ; --- turns on the demo level ---
   g (story-new demo-level)
   _ (describe g)
   _ (assert ('lamp = (g 'at)) (has? <(g 'log) "exits: down") (has? (g 'log 1) "the lamp"))
   _ (story-turn g "down")
   _ (assert ('stair = (g 'at)) (has? <(g 'log) "exits: down, up"))
   _ (story-turn g "read sign")
   _ (assert (has? <(g 'log) "no sign here"))
   _ (story-turn g "down")
   _ (story-turn g "read sign")
   _ (assert ('door = (g 'at)) (has? <(g 'log) "KEEPER OUT"))
   _ (story-turn g "open sign")
   _ (assert (has? <(g 'log) "does not open"))
   _ (story-turn g "dance")
   _ (assert (has? <(g 'log) "cannot dance"))
   _ (story-turn g "go sideways")
   _ (assert (has? <(g 'log) "cannot go sideways"))
   _ (story-turn g "up")
   _ (assert ('stair = (g 'at)) !(g 'over))
   _ (story-turn g "q")
   _ (assert ('quit = (g 'over)))

   ; --- the frame: a title bar, the log with the newest at the foot, the prompt ---
   f (plain (story-frame g 40 8))
   rows (split "\r\n" f)
   _ (assert (8 = tally rows)
             (has? (rows 0) "the lighthouse -- the stair")
             (40 = tally (rows 0))                                 ; the bar spans the width
             (has? (rows 7) "> ")                                  ; the prompt is the last row
             (has? f "> q"))
   ; wrapping: a long line breaks at the width, never mid-word
   w (wrap "the quick brown fox jumps over the lazy dog" 12)
   _ (assert (4 = tally w) ("the quick" = <w) (all (l \ #l <= 12) w))

   ; --- the library: this tree's crew ---
   L (library "src/apps")
   rooms (L 'rooms)
   _ (assert ('hall = (L 'start)) (10 < tally (keys rooms)) (peep rooms 'rove 0) (peep rooms 'lapiz 0))
   g2 (story-new L)
   _ (describe g2)
   _ (assert (has? (g2 'log 2) "lapiz"))                          ; the hall's text names its wings
   _ (story-turn g2 "rove")
   _ (assert ('rove = (g2 'at)) (has? <(g2 'log) "exits: out") (has? (g2 'log 1) "story"))
   _ (story-turn g2 "read story")
   _ (assert (has? <(g2 'log) "fiction engine"))                   ; libra's lift of this file's header
   _ (story-turn g2 "out")
   _ (assert ('hall = (g2 'at)))
   _ (test_fin ())
   _ (puts "story: ok -- turns, the frame, and the library lifted from the tree\n")
   0)
