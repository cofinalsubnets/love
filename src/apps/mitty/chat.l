; src/apps/mitty/chat.l -- bee's two screens: the chat with a model, on the full screen or as a
; mitty's pane, and the hud over the hive. neither knows the wire, the hive's files or the
; queues: a session is bee's core (src/apps/bee.l, bee-core), a tablet of doors, and these
; only paint what it answers and hand it the keys.
;
;   (chat-stage k key yes)   the chat as a stage (cli's stage-run shape): a mitty's pane
;   (chat-tui k key yes)     the same stage on the whole terminal
;   (hud-stage k)            the hud: queues, locks and sessions, and a talk to one as the user
;   (chat-hud k)             the hud on the whole terminal
;
; host-only: the chat's commands run on a pty of their own (tether, screen). the saver is mitty's.
(module (chat chat-tui chat-stage chat-hud hud-stage)
(:
 (soil c) (pin (c 'dirt) () 1)
 (push c b) (pins c 'blocks (b . c 'blocks) 'scroll 0 'mails (peep c 'mails 0 + (b 'k = 'mail)))

 ; --- the chat. the state c: 'bee the core, 'blocks newest first, 'ed the input buffer,
 ; 'scroll lines up from the bottom, 'dirt a box the main loop repaints on, 'busy the turn's
 ; task, 'asking the tool block awaiting y/n, 'msgs the conversation, 'sock the open wire, 'over

 ; words of l as lines at most n wide; a word wider than n stands alone, cut at paint
 (wrap l n)
  (: (go ws cur acc)
      (? (atom? ws) (rev (cur . acc))
         (: w <ws
            (? (#cur = 0) (go >ws w acc)
               (edwide cur + 1 + edwide w <= n) (go >ws (cur + " " + w) acc)
               (go >ws w (cur . acc)))))
     (go (words l) "" ()))
 ; l as lines at most n columns wide, cut anywhere, every character kept
 (hwrap l n) (? (edwide l <= n) [l] (: a (edcut l n) (? (#a = 0) [l] (a . hwrap (snip l #a #l) n))))

 ; a unified diff, coloured, at most n lines
 (diffs a b n)
  (: ls (lines (cite 'kore 'udiff "a" "b" a b))
     body (drop 2 ls)                                 ; the --- +++ pair says nothing here
     (paint l) (? (#l = 0) l
                  (l 0 = 43) (sgr "32" l) (l 0 = 45) (sgr "31" l) (l 0 = 64) (sgr "36" l)
                  (sgr "2" l))
     (map (\ l ("     " + paint l)) (#body <= n ? body (take n body + [("… " + show (#body - n) + " more")]))))
 ; what a tool will do, shown while it asks: an edit or a write as its diff
 (preview k name in) (: d (k 'change name in) (? !(two? d) () <d (diffs (d 1) (d 2) 16) [(sgr "31" (d 1))]))

 ; --- a command on a pty, its screen live in its block ---
 pty-rows 24
 ; the child's bytes into the screen, its queries answered, the painter cued per gulp
 (pump c b m s)
  (: bf (cask 8192)
     (go _) (: ch (see m)
               (? (ch < 0) 0
                  (: _ (scribe s ch)
                     (drain _) (: n (swig m bf) (? (charm? n && 0 < n) (: _ (scribe s (snip bf 0 n)) (drain 0)) 0))
                     _ (drain 0)
                     rep (reply s)
                     _ (? rep (: _ (say m (foldl (\ a x (a + string x)) "" rep)) (flush m)) 0)
                     _ (pin b 'v (b 'v + 1))
                     _ (soil c)
                     (go 0))))
     (go 0))
 ; the used rows run from the oldest held in history (negative) to the cursor's
 (scr-span s) (: w (gaze s 2) k (gaze s 0) cr (k // w)
                 [(0 - (gaze s 9)) (k % w = 0 ? (cr - 1) cr)])
 ; the last n used rows, painted as limn paints a pane
 (scr-rows s n)
  (: sp (scr-span s) hi (sp 1) lo (max <sp (hi - n + 1)) w (gaze s 2)
     (map (\ i (: j (jug 0) _ (cite 'limn 'limn-row j s w i 0 -1 0) (slurp j + "\e[0m")))
          (map (\ d (lo + d)) ^(max 0 (hi - lo + 1)))))
 ; everything the command wrote, as text, for the model
 (scr-text s) (: w (gaze s 2) (copied s -(gaze s 9 * w) (gaze s 0)))

 ; lines in a rounded box n wide, its border in pen
 (boxed pen ls n)
  (: d (\ s (sgr pen s)) rule (edfit "" (n - 2) "─")
     (d ("╭" + rule + "╮") . (map (\ l (d "│" + " " + edfit l (n - 4) " " + " " + d "│")) ls
                                + [(d ("╰" + rule + "╯"))])))
 ; the first line after ⎿, the rest under it
 (hang ls) (? (atom? ls) () (sgr "2" "  ⎿  " + <ls . map (l \ "     " + l) >ls))
 ; lapiz sets a body at five columns; the gutter here is two
 (unindent l) (: (go i) (? (i < 3 && i < #l && l i = 32) (go (i + 1)) i) (snip l (go 0) #l))
 ; a tool as the screen names it
 (title k name) (name @ "read_file" "Read" "write_file" "Write" "edit_file" "Update" "shell" (k 'shell-name)
                        "list_sessions" "Hive" "send_message" "Message" "start_job" "Job"
                        "check_job" "Check" "stop_job" "Stop" "spawn_bee" "Spawn" "stop_bee" "Stop" "queue_row" "Queue" "lock_acquire" "Lock" "lock_release" "Unlock" "lock_list" "Locks"
                        name)

 spin ["·" "✢" "✳" "✶" "✻" "✽" "✻" "✶" "✳" "✢"]
 hums ["buzzing" "foraging" "waggling" "humming" "pollinating" "hovering" "combing"
       "gathering nectar" "making honey" "dancing"
       "hopping" "nibbling" "twitching its nose" "burrowing" "binkying" "thumping"
       "munching clover" "flopping" "grooming its ears" "zooming"]
 (spinner c)
  (: ms (clock 0 - c 't0) n (ms // 120)
     (sgr (c 'bee 'look 'ink) (spin (n % #spin) + " " + c 'hum + "…")
      + sgr "2" (" (" + show (ms // 1000) + "s · esc to interrupt)")))
 ; the gauge: the last request's tokens against the window, or a count when it is unknown
 (kilo n) (n < 1000 ? (show n) (show (n // 100 / 10) + "k"))
 (gauge c)
  (: n (c 'used) x (peep c 'cost ()) win (c 'bee 'window 0)
     dollars (? (x = ()) ""
                (: k (int (x * 100 + 0.5))
                   (sgr "2" ("$" + show (k // 100) + "." + (k % 100 < 10 ? "0" "") + show (k % 100) + " · "))))
     (? !(charm? n) dollars
        (win = ()) (dollars + sgr "2" (kilo n + " tokens"))
        (: p (n * 100 // win)
           (dollars + sgr (? (p < 70) "2" (p < 90) "33" "31") (show p + "% context")))))

 ; a block's lines at width w, cached on the block by [w its version]
 (blines c b w)
  (: key [w (peep b 'v 0) (c 'bee 'look 'name)]
     (? (peep b 'lk () = key) (b 'lines)
        (: ls (blines0 c b w) _ (pins b 'lk key 'lines ls) ls)))
 (blines0 c b w)
  (: k (c 'bee) look (k 'look)
     (b 'k @
      'hello (: t [(sgr ("1;" + look 'ink) "bee")
                   (k 'model + sgr "2" (" · " + k 'api))
                   (sgr "2" (k 'cwd))
                   (sgr "2" ("session " + k 'me 0 + " · enter send · ^d quit"))]
                (boxed (look 'ink) (map (\ i ((look 'face) i + "   " + t i)) ^4) (min w 72)))
      'you (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
              (map (\ l (sgr "2" l)) ("> " + <ls . map (l \ "  " + l) >ls)))
      'bee (: md (map unindent (lines (cite 'lapiz 'md->tty (b 'text) (w + 2))))
               ls (two? md ? md [""])
               ("⏺ " + lstrip <ls . >ls))
      'note (hang [(sgr "2;3" (b 'text))])
      'lines (b 'ls)
      ; a message from another session, its sender first
      'mail (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
               (sgr (look 'ink) "✉ " + sgr "1" (b 'from) . map (\ l ("  " + l)) ls))
      ; thinking streams dim while it runs, its last eight lines; done, it folds to one line
      ; unless ^t has them all open
      'think (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
                n #(words (b 'text))
                body (map (\ l (sgr "2;3" ("  " + l))) ls)
                (? (b 'open) (sgr (look 'ink) "✻ thinking…" . (8 < #body ? (drop (#body - 8) body) body))
                   (b 'x) (sgr "2;3" ("✻ thought · " + show n + " words") . body)
                   [(sgr "2;3" ("✻ thought · " + show n + " words  ^t"))]))
      'tool (: st (b 'st)
               dot (sgr (st @ 'ask "1;33" 'ok "32" 'err "31" "2") "⏺")
               head (dot + " " + sgr "1" (title k (b 'name)) + sgr "2" ("(" + b 'brief + ")"))
               out (peep b 'out "")
               ; an ask shows all of what runs, wrapped by column, never cut
               tail (? (st = 'ask)
                       (catmap (\ l (hwrap l (w - 6))) (k 'ask-lines (b 'name) (b 'in))
                        + [(sgr "1;33" (peep b 'tall 0 ? "taller than the screen: ↑↓ to read it all, then y / n"
                                          "run it?  y / n"))])
                       (st = 'cut) [(sgr "2" "interrupted")]
                       (st = 'err) [(sgr "31" (: l (lines out) (two? l ? <l out)))]
                       (b 'name @
                        "shell" (? (peep b 'scr () != ()) (scr-rows (b 'scr) 12)
                                   (: ls (filter (\ l (0 < #l)) (lines out)) n #ls
                                      (map (sgr "2") (8 < n ? (drop (n - 8) ls) ls))))
                        "read_file" (? (st = 'ok) [(sgr "2" ("read " + show #(lines out) + " lines"))] ())
                        ()))
               (head . ((st = 'ask ? () (peep b 'pre ())) + hang tail)))
      [""]))

 ; the transcript, oldest first, a blank line between blocks
 (tlines c w) (catmap (\ b ("" . blines c b w)) (rev (c 'blocks)))

 ; the transcript's rows: the screen's less the spinner, the input box and the hints
 (room c) (c 'rows - 4 - min 6 (max 1 #(lines (edtext (c 'ed)))))
 ; the transcript, a spinner row while a turn runs, the input boxed with the gauge
 ; right-aligned on its first row, and the hints under it
 (frame c)
  (: w (c 'cols) h (c 'rows) e (c 'ed)
     il (lines (edtext e)) il2 (two? il ? il [""])
     bh (min 6 #il2)
     top (max 0 (#il2 - bh))
     iw (w - 6)                                           ; inside "│ > " and " │"
     g (gauge c) gw (edwide g)
     (row i) (: l (edcut (il2 (top + i)) iw)
                (? (i = 0 && 0 < gw && edwide l + gw + 2 <= iw) (edfit l (iw - gw) " " + g) l))
     box (boxed "2" (map (\ i ((i = 0 && top = 0 ? (sgr "1" ">") " ") + " " + row i)) ^bh) w)
     th (room c)
     all (tlines c w)
     end (max 0 (#all - c 'scroll))
     win (drop (max 0 (end - th)) (take end all))
     pad (map (\ _ "") ^(th - #win))
     busy (c 'busy != ())
     sp (busy && !(tablet? (c 'asking)) ? (spinner c) "")
     ; the session's name leads the hints, always: it is how other sessions address this one
     stat (sgr (c 'bee 'look 'ink) ("  " + c 'bee 'me 0) + sgr "2" (? (tablet? (c 'asking)) " · y run · n decline"
                                                                busy " · esc interrupt · ↑↓ scroll"
                                                                " · enter send · alt-enter newline · ↑↓ scroll · ^t thoughts · /whoami · ^d quit"))
     rows (map (\ l (edfit l w " ")) (win + pad + [sp] + box))
     cr (h - 1 - bh + #(e 'u) - top)
     cc (5 + edcol e)
     (cite 'tui 'tui-fresh c h [w h] () rows (edfit stat w " ") cr cc))

 ; the face the turn reports through (bee.l, the turn, told to a face): its reports become blocks
 (tface c)
  (: k (c 'bee)
     {'yes (c 'yes)
      'text (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                    _ (? (tablet? b && b 'k = 'bee && b 'open)
                       (pins b 'text (b 'text + x) 'v (b 'v + 1))
                       (push c {'k 'bee 'text x 'v 1 'open 1}))
                    (soil c)))
      'think (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                     _ (? (tablet? b && b 'k = 'think && b 'open)
                          (pins b 'text (b 'text + x) 'v (b 'v + 1))
                          (push c {'k 'think 'text x 'v 1 'open 1 'x (c 'thinkall)}))
                     (soil c)))
      'break (\ _ (: b (? (two? (c 'blocks)) <(c 'blocks))
                     (? (tablet? b) (: _ (pins b 'open 0 'v (peep b 'v 0 + 1)) (soil c)) 0)))
      'note (\ s (push c {'k 'note 'text s}, soil c))
      'mail (\ from t (push c {'k 'mail 'from from 'text t}, soil c))
      'wire (\ s (pin c 'sock s))
      'usage (\ n (pin c 'used n, soil c))
      'cost (\ x (pin c 'cost (peep c 'cost 0 + x), soil c))       ; claude's own reckoning, summed
      'tool (\ name in (: b {'k 'tool 'name name 'in in 'brief (k 'brief name in) 'st 'run 'v 0
                              'pre (? (name = "edit_file" || name = "write_file") (preview k name in) ())}
                         (push c b, soil c, b)))
      'ask (\ b (: _ (pins b 'st 'ask 'v (b 'v + 1)) _ (pins c 'asking b 'scroll 0) _ (soil c)
                   _ (k 'state! "asking")
                   (wait _) (? (charm? (peep b 'ans ())) (b 'ans) (: _ (rest 30) (wait 0)))
                   a (wait 0)
                   _ (k 'state! "busy")
                   _ (pins b 'st 'run 'v (b 'v + 1)) _ (pin c 'asking ()) _ (soil c)
                   a))
      'done (\ b r (pins b 'st (<r ? 'ok 'err) 'out (r 1) 'v (b 'v + 1), soil c))
      ; on a pty of its own, its screen in the block as it runs; the pipe when no pty opens
      'shell (\ b cmd (: w (max 20 (c 'cols - 8)) r pty-rows
                        _ (setenv "TERM" "xterm-256color")
                        md (tether (k 'argv cmd))
                        (? (atom? md) (k 'shell-out cmd)
                           (: pid <md m >md
                              s (screen (cask (screen () r w)) r w)
                              _ (settty m r w)
                              _ (pins b 'scr s 'v (b 'v + 1))
                              _ (pins c 'kid pid 'kidm m)
                              _ (pump c b m s)
                              code (k 'reap pid)
                              _ (close m)
                              _ (pins c 'kid () 'kidm ())
                              (scr-text s + "\n[exit " + show code + "]")))))})

 ; a line sent: its block, and the turn as a task of its own
 (send c s) (: _ (push c {'k 'you 'text s}) (launch c s))
 ; the turn as a task of its own, the card busy until it ends
 (launch c s)
  (: k (c 'bee) m0 (c 'msgs)
     _ (pins c 't0 (clock 0) 'hum (hums (clock 0 % #hums)))
     _ (k 'state! "busy")
     t (twirl (\ _ (: m (k 'turn (c 'key) (c 'face) (k 'user s . m0))
                      _ (pins c 'msgs (two? m ? m m0) 'busy ())
                      _ (k 'state! "idle")
                      (soil c))) 0)
     (pin c 'busy t))
 ; idle, a message starts a turn of its own: its blocks, then the model reads it
 (wake c)
  (: k (c 'bee)
     _ (k 'self-tell 0)
     ms (k 'take-mail 0)
     (? (two? ms)
        (: _ (map (\ m (push c {'k 'mail 'from <m 'text (m 1)})) ms)
           (launch c (k 'mail-text ms)))
        0))
 ; esc: the wire shut and the turn's task frozen; the conversation stays as it was
 (halt c)
  (: s (c 'sock) t (c 'busy)
     _ (? (hot? s) (close s) 0)
     _ (? (c 'kid != ()) (still (c 'kid) 15) 0)             ; a running command dies with its turn
     _ (? (hot? (c 'kidm)) (close (c 'kidm)) 0)
     _ (map (\ b (? (b 'k = 'tool && (b 'st = 'run || b 'st = 'ask)) (pins b 'st 'cut 'v (b 'v + 1)) 0))
            (c 'blocks))
     _ (? (t != ()) (freeze t) 0)
     _ (pins c 'busy () 'sock () 'asking ())
     _ (c 'bee 'halt 0)                                     ; the next turn resumes the session
     _ (c 'bee 'state! "idle")
     (push c {'k 'note 'text "interrupted"}))

 (onkey c k)
  (: a (c 'asking) e (c 'ed) busy (c 'busy != ())
     ; y runs only once every row of the ask has been on the screen; ↑↓ and ^b ^f scroll it
     (? (tablet? a) (? (k = 121 || k = 89)
                        (? (#(blines c a (c 'cols)) + 1 <= room c + peep a 'seen 0) (pin a 'ans 1)
                           (: _ (pins a 'tall 1 'v (a 'v + 1)) (soil c)))
                       (k = 110 || k = 78 || k = 27) (pin a 'ans 0)
                       (k = -8 || k = 2)
                        (: s (c 'scroll + (k = 2 ? (room c) 1))
                           _ (pin c 'scroll s)
                           (pin a 'seen (max s (peep a 'seen 0))))
                       (k = -9 || k = 6) (pin c 'scroll (max 0 (c 'scroll - (k = 6 ? (room c) 1))))
                       0)
        (busy && (k = 27 || k = 3)) (halt c)
        (k = 20)                                             ; ^t: every thought open, or folded
         (: x (!(c 'thinkall) ? 1 0)
            _ (pin c 'thinkall x)
            (map (\ b (? (b 'k = 'think) (pins b 'x x 'v (b 'v + 1)) 0)) (c 'blocks)))
        (k = 3 || k = -7) (pin c 'over 1)
        (k = 269) (ednl e)                                   ; alt-enter
        (: _ (edstep e k) v (e 'ev) page (c 'rows // 2)
           (v @ 10 (: s (edtext e)
                      (? (busy || #s = 0) 0
                        (s = "/whoami") (: _ (edclear e) (push c {'k 'note 'text (c 'bee 'whoami 0)}))
                        (<(words s) = "/avatar") (: _ (edclear e) (push c {'k 'lines 'ls ((c 'bee 'avatar s (c 'cols)) 1)}))
                        (: _ (edclear e) (send c s))))
                4 (? (#(edtext e) = 0) (pin c 'over 1) 0)
                -8 (pin c 'scroll (c 'scroll + 1))
                -9 (pin c 'scroll (max 0 (c 'scroll - 1)))
                2 (pin c 'scroll (c 'scroll + page))
                6 (pin c 'scroll (max 0 (c 'scroll - page)))
                0))))
 (tnew k key yes)
  (: c {'bee k 'blocks () 'ed (ednew 0) 'scroll 0 'dirt {() 1} 'busy () 'asking () 'msgs ()
        'sock () 'over 0 'key key 'yes yes 'rows 24 'cols 80}
     _ (pin c 'face (tface c))
     _ (k 'on-news (\ t (push c {'k 'note 'text t}, soil c)))   ; a new binary, a note here
     _ (push c {'k 'hello})
     c)
 ; the chat on the whole terminal: the stage below, run by cli's stage-run
 (chat-tui k key yes)
  (stage-run (pins (chat-stage k key yes) 'modes ['paste ['title ("bee: " + k 'me 0)]]))

 ; the full screen as a pane of a mitty (mitty.l), which owns the tty, the keys' reader and
 ; the clock. its frame is scribed into the pane's own screen, so tui-fresh diffs against
 ; what that screen holds. the saver is the mitty's
 (chat-stage k key yes)
  (: c (tnew k key yes)
     stop (k 'loops 0)                                    ; the queues and locks, mailed here as they move
     _ (pins c 'woke (clock 0) 'spun (clock 0))
     {'name ("bee " + k 'me 0)
      'show (\ w h (? (w < 20 || h < 8) "" (: _ (pins c 'rows h 'cols w) (frame c))))
      'step (\ n (: _ (onkey c n) (soil c)))
      'over? (\ _ (c 'over))
      ; a frame when the turn or the inbox moved: the spinner's beat, mail about once a second
      'tick (\ _ (: t (clock 0) b (c 'dirt)
                    _ (? (c 'busy != () && 130 < t - c 'spun) (: _ (pin c 'spun t) (soil c)) 0)
                    _ (? (c 'busy = () && 1000 < t - c 'woke) (: _ (pin c 'woke t) (wake c)) 0)
                    (? (peep b () 0) (: _ (pin b () 0) 1) 0)))
      'shut (\ _ (: _ (? (c 'busy != ()) (halt c) 0) _ (stop 0)
                    _ (k 'halt 0)
                    (k 'unsettle 0)))})

 ; --- the hud: the queues, the locks and the hive as the core lays them out, read again
 ; every (queue-watch N) seconds; no model and no key. it holds the user's card while it is
 ; open, so c talks to a session as the user and the answers show here ---
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
 (chat-hud k) (stage-run (hud-stage k)))
) ; module chat
