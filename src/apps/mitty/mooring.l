; src/apps/mitty/mooring.l -- the terminal core mitty and synth share: a child on its own
; pty with a quay screen, the moor that pumps it there, and the wait for its end.
;   (hopen argv r c)          a pane [box master pid stage name], or tether's nom
;   (moor-to bx m w dirty)    m through the screen in box bx, replies up w, until m hangs up;
;                             dirty (when given) is set at each gulp. moor: w is m
(module '(mooring hopen hname-of moor moor-to hpour waitfor hbox hmas hpid)
(borrow 'posix)
(:
 (hbox p) <p
 (hmas p) <>p
 (hpid p) <>>p

 ; tether's errno rides back out on a refusal: a nom, never two?
 (hopen argv r c) (: _ (setenv "TERM" "xterm-256color")   ; the dialect we actually speak
                     md (tether argv)
                     (atom? md ? md
                      (: m >md
                         s (screen (cask (screen () r c)) r c)
                         bx {s}
                         (settty m r c,
                          [bx m <md () (hname-of argv)]))))
 ; a program's name, or love's verb when it is love
 (hname-of argv) (: b (: w <argv k (: (go i) (? (i < 0) 0 (w i = 47) (i + 1) (go (i - 1))) (go (#w - 1)))
                         (snip w k #w))
                     (b = "love" && two? >argv ? <>argv b))

 ; a queue that fills stops the feed, and the rest goes in once the replies are
 ; said; the first drain tells the screen its replies are heard
 (hpour s x w) (: (said _) (: rep (reply s) (two? rep ? (say w (foldl (a \ b \ a + string b) "" rep), flush w) 0))
                  _ (said 0)
                  r (scribe s x)
                  _ (said 0)
                  (charm? r ? (hpour s (snip x r #x) w) 0))

 ; park on the first byte, then swig the rest of the gulp. the box is re-read
 ; every gulp: that is how a resize or a swapped screen reaches a running moor
 (moor bx m dirty) (moor-to bx m m dirty)
 (moor-to bx m w dirty) (see m @ ch
                    (ch = -1 ? ()
                     (: _ (hpour (peep bx () 0) ch w)
                        b (cask 8192)
                        _ (: (drain x) (swig m b @ n
                                          (charm? n && 0 < n ? (hpour (peep bx () 0) (snip b 0 n) w, drain ()) 0))
                           (drain ()))
                        (dirty ? (pin dirty () 1) 0,
                         moor-to bx m w dirty))))

 (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid)))))
) ; module mooring
