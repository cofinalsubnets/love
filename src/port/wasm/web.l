; src/port/wasm/web.l -- the page's love side: the quay tty apps on the page's screen.
; repl.js fetches this after rove.l and ink.l and feeds it through ai_eval; the tests
; run it under node the same way (src/port/wasm/screen.mjs).
;
; the tty runners (rove/sail/helm) reference host words the browser image lacks
; (winsize/raw/cue?/rest/flush ride pty.c + bao.l), and a closure captures its free
; globals at creation, so those defs would raise as they bind: the five are stubbed
; (never called). the pure engines are all the page touches.
;
; the screen is quay's, a cask (src/core/quay/nif.c): an app's frame is scribed into
; it and `mirror` (host.c) hands the cells to the page, which lays them as text
; (cells.js). the page never parses an escape. the protocol repl.js pumps:
;   <name>-web-boot cols rows seed  -> mirrors the first frame; rows/cols are the screen
;   <name>-web-key byte             -> mirrors the next / answers the quit sentinel  (key apps)
;   <name>-web-tick ()              -> mirrors the next                             (anim apps)
; `<name> ()` at the repl answers the play sentinel the driver catches.
(: winsize (\ _ ()) raw (\ _ ()) cue? (\ _ 0) rest (\ _ ()) flush (\ _ ())
   (play nm) (: _ (puts ("\e_play:" + nm + "\e\\")) ())
   web-quit "\e_quit\e\\"
   web-scr {} qbox {} sbox {} tbox {}
   ; a fresh screen of the page's size, and a frame onto it
   (web-open r c) (: s (screen (cask (screen () r c)) r c) _ (pin web-scr () s) s)
   (web-show f) (: s (peep web-scr () 0) _ (scribe s f) _ (mirror s) "")
   ; rove keeps two rows for its message line and its bar
   (rove-web-boot c r sd) (: _ (web-open r c)
                             g (crawl-new (c < 100 ? c 100) (r - 2) (wheel sd))
                             _ (pin qbox () g)
                             (web-show (crawl-frame g)))
   (rove-web-key n) (? (n = 113 || n = 27) web-quit
                       (: g (peep qbox () 0) _ (crawl-turn g (helm-dec n -1 -1)) (web-show (crawl-frame g))))
   (ink-web-boot c r sd) (: _ (web-open r c) _ (pin sbox () (ink-scene r c)) _ (pin tbox () 0)
                            (web-show ((peep sbox () 0) 0.0)))
   (ink-web-tick _) (: t (1 + peep tbox () 0) _ (pin tbox () t) (web-show ((peep sbox () 0) (t * 0.06))))
   rove (\ _ (play "rove"))
   ink (\ _ (play "ink")))
