; src/apps/mitty/mooring.l -- the terminal core mitty and pier share: a child opened on its own
; pty with a quay screen to pour into, the moor that pumps it there, and the wait for its end.
;
;   (hopen argv r c)          a pane [box master pid stage name], or tether's nom
;   (moor bx m dirty)         m's bytes through the screen in box bx, its replies back up m,
;                             until m hangs up; dirty (when given) is set at each gulp
;   (moor-to bx m w dirty)    the same, the replies up w: a terminal whose way in is not its
;                             way out (a window's pipes)
;   (waitfor pid)             the child's status pair, or a nom
;   hbox hmas hpid            a pane's box, master and pid
(module '(mooring hopen hname-of moor moor-to waitfor hbox hmas hpid)
(borrow 'posix)
(:
 (hbox p) <p
 (hmas p) <>p
 (hpid p) <>>p

 ; open a child on its own pty at r x c. tether's errno rides back out on a
 ; refusal -- a nom, never two?, which is how the caller tells it from a pane.
 (hopen argv r c) (: _ (setenv "TERM" "xterm-256color")   ; the dialect we actually speak
                     md (tether argv)
                     (atom? md ? md
                      (: m >md
                         s (screen (cask (screen () r c)) r c)
                         bx {s}
                         (settty m r c,
                          [bx m <md () (hname-of argv)]))))
 ; what runs there, for mitty's bar: a program's name (love's verb when it is love)
 (hname-of argv) (: b (: w <argv k (: (go i) (? (i < 0) 0 (w i = 47) (i + 1) (go (i - 1))) (go (#w - 1)))
                         (snip w k #w))
                     (b = "love" && two? >argv ? <>argv b))

 ; --- the moor: pump the master through the screen until the child hangs up.
 ; the screen lives in box bx (a relay swaps it); replies pour straight back;
 ; a dirty box (when given) cues the painter
 ; park on the first byte, then swig the rest of the gulp -- per-byte sees
 ; cap out near a megabyte a second, and a full-screen guest pours six
 ; the box is re-read every gulp on purpose: that is how a resize reaches a
 ; running moor with no signal, and why a pane's screen may be swapped freely.
 (moor bx m dirty) (moor-to bx m m dirty)
 (moor-to bx m w dirty) (see m @ ch
                    (ch = -1 ? ()
                     (: s (peep bx () 0)
                        _ (scribe s ch)
                        b (cask 8192)
                        _ (: (drain x) (swig m b @ n
                                          (charm? n && 0 < n ? (scribe (peep bx () 0) (snip b 0 n), drain ()) 0))
                           (drain ()))
                        rep (reply (peep bx () 0))
                        ; a reply is a byte stream and its order is the whole content
                        ; of it -- and one say beats six puts.
                        (rep ? (say w (foldl (a \ b \ a + string b) "" rep), flush w) 0,
                         dirty ? (pin dirty () 1) 0,
                         moor-to bx m w dirty))))

 (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid)))))
) ; module mooring
