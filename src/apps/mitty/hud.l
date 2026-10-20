; src/apps/mitty/hud.l -- bee's hud over the hive: the queues, the locks and the sessions, and a
; talk to one as the user. bee's core is a tablet of doors; this only paints what it answers and
; hands it the keys.
;
;   (hud-stage k)   the hud as a stage
;   (hud-run k)     the hud on the whole terminal
(module (hud hud-run hud-stage)
(:
 (soil c) (pin (c 'dirt) () 1)
 ; l as lines at most n columns wide, cut anywhere, every character kept
 (hwrap l n) (? (edwide l <= n) [l] (: a (edcut l n) (? (#a = 0) [l] (a . hwrap (snip l #a #l) n))))

 ; the queues, locks and hive, read every (queue-watch N) seconds. it holds the user's card while
 ; open, so it talks to a session as the user
 (hud-to c) (: ps (c 'bee 'peers 0) l (c 'lead) (? (string? l && elem l ps) l (two? ps) <ps ()))
 (hud-log c hd t)
  (: ls (lines t) l2 (two? ls ? ls [""])
     all (c 'log + [(hd + <l2)] + map (l \ "  " + l) >l2)
     (pin c 'log (drop (max 0 (#all - 200)) all)))
 ; the talk under the dashboard: its rule, the log's last rows, and the line being written
 (hud-talk c w n)
  (: e (c 'ed) to (peep c 'to ())
     log (catmap (l \ hwrap l (w - 2)) (c 'log))
     il (? (c 'typing) [((sgr "1" ">") + " " + (: ls (lines (edtext e)) (two? ls ? (ls (#ls - 1)) "")))] ())
     room (max 0 (n - 1 - #il))
     body (drop (max 0 (#log - room)) log)
     ([(sgr "2" (edfit ("── " + (string? to ? ("to " + to + " ") "")) w "─"))]
      + map (l \ " " + l) (map (_ \ "") ^(room - #body) + body) + il))
 (hud-frame c)
  (: w (c 'cols) h (c 'rows) ls (c 'lines) ty (c 'typing)
     th (? (ty || two? (c 'log)) (max 4 (min 12 (h // 3))) 0)
     dh (max 1 (h - 1 - th))
     top (max 0 (min (c 'top) (#ls - dh)))
     win (take dh (drop top ls))
     rows (map (l \ edfit l w " ") (win + map (_ \ "") ^(dh - #win) + (0 < th ? (hud-talk c w th) ())))
     note (peep c 'note "")
     stat (edfit (sgr "2" ((? ty ("  to " + c 'to + " · enter send · tab another session · esc back")
                              ("  bee · read " + c 'bee 'utc-minute (c 'read // 1000) + " · c talk · r read again · ↑↓ scroll · q quit"
                               + (#ls > dh ? ("   " + show (top + 1) + "-" + show (top + #win) + " of " + show #ls) "")))
                           + (0 < #note ? ("   " + note) "")))
                 w " ")
     (cite 'tui 'tui-fresh c h [w h] () rows stat (ty ? (h - 1) h) (ty ? (3 + edcol (c 'ed)) 1)))
 (hud-read c)
  (: k (c 'bee) qs (k 'queues 0)
     _ (pins c 'lines (k 'hud-lines qs) 'read (clock 0) 'lead (two? qs ? (k 'q-leader (<qs 1)) ()))
     (soil c))
 ; mail for the user, into the log, about once a second while this hud holds the card
 (hud-inbox c)
  (: ms (c 'bee 'user-mail 0)
     (? (two? ms) (: _ (map (m \ hud-log c ((sgr "1" <m) + ": ") (m 1)) ms) (soil c)) 0))
 (hud-open c)
  (: why (peep c 'why "") to (hud-to c)
     (? (0 < #why) (: _ (pin c 'note why) (soil c))
        !(string? to) (: _ (pin c 'note "no session to talk to") (soil c))
        (: _ (pins c 'typing 1 'to to 'note "") _ (say out "\e[?25h") (soil c))))
 ; typing: enter sends to the session named, tab names the next, esc goes back to looking
 (hud-type c k)
  (: e (c 'ed)
     (? (k = 27) (: _ (pin c 'typing 0) _ (say out "\e[?25l") (soil c))
        (k = 3) (pin c 'over 1)
        (k = 9) (: ps (c 'bee 'peers 0) i (findsub ps [(c 'to)])
                   _ (? (two? ps) (pin c 'to (ps ((i + 1) % #ps))) 0)
                   (soil c))
        (: _ (edstep e k)
           _ (? (e 'ev = 10)
                (: t (edtext e)
                   (? (#t = 0) 0
                      (: r (c 'bee 'user-post (c 'to) t) _ (edclear e)
                         (? (#r = 0) (hud-log c ((sgr "1" "you") + " → " + c 'to + ": ") t)
                            (hud-log c "" (sgr "31" r))))))
                0)
           (soil c))))
 (hud-key c k)
  (? (c 'typing) (hud-type c k)
     (elem k [113 81 3 4 -7]) (pin c 'over 1)
     (elem k [99 67 13 10]) (hud-open c)
     (elem k [114 82]) (hud-read c)
     (elem k [-9 106 6]) (: _ (pin c 'top (c 'top + (k = 6 ? (c 'rows // 2) 1))) (soil c))
     (elem k [-8 107 2]) (: _ (pin c 'top (max 0 (c 'top - (k = 2 ? (c 'rows // 2) 1)))) (soil c))
     0)
 ; the hud as a stage: the user's mail about once a second, the queues every (queue-watch N)
 (hud-stage k)
  (: c {'bee k 'rows 24 'cols 80 'over 0 'top 0 'lines () 'read 0 'dirt {() 1}
        'typing 0 'log () 'ed (ednew 0) 'note "" 'to () 'lead () 'why "" 'mine 0 'polled 0}
     why (k 'user-settle 0)
     _ (pins c 'why why 'mine (#why = 0))
     _ (hud-read c)
     {'show (\ w h (: _ (pins c 'rows h 'cols w) (hud-frame c)))
      'step (\ n (hud-key c n))
      'over? (\ _ (c 'over))
      'tick (\ _ (: t (clock 0) b (c 'dirt) qw (k 'qwatch)
                    _ (? (c 'mine && 1000 < t - c 'polled) (: _ (pin c 'polled t) (hud-inbox c)) 0)
                    _ (? ((0 < qw ? qw 20) * 1000 < t - c 'read) (hud-read c) 0)
                    (? (peep b () 0) (: _ (pin b () 0) 1) 0)))
      'shut (\ _ (? (c 'mine) (k 'user-card! "away") 0))
      'modes ['hide ['title "bee"]]})
 (hud-run k) (stage-run (hud-stage k)))
) ; module hud
