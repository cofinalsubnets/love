; greet -- a terminal's greeter: a login box over a lore saver, then the session chosen as a
; child, started as login starts a shell (utmp, the tty, setids, the environment, exec); when
; it ends, its logout recorded and the box again.
;   love greet [-r ROOT] [-s SAVER] [TTY]   ROOT for /etc and /var, SAVER the one behind (life)
; tab or up and down move between the fields, left and right turn the session, enter goes on
; or tries. a failure waits as login's do; the greeter ends only at the end of its input
(module (greet greet-main greet-usage greet-new greet-box greet-key greet-sessions)
(borrow '(posix cli login saver))
(:
 greet-usage "usage: love greet [-r ROOT] [-s SAVER] [TTY]"
 ; a session: a name, () for the user's shell or an argv to exec, and where under home its
 ; output goes, () the terminal. x opens the greeter's own vt, as startx does without
 ; logind: tty0, where it would look for one, is root's
 (greet-sessions love line)
  (: vt (line @ ("tty" + (n && 0 < #n)) ["--" ("vt" + n) "-keeptty"] _ ())
     [["shell" () ()] ["lux" (["xinit" love "lux"] + vt) ".xsession-errors"]])
 ; focus 0 the name, 1 the password, 2 the session
 (greet-new _) {'user "" 'pass "" 'focus 0 'sess 0 'msg "" 'fails 0 'hold 0}
 box-fg 252  box-bg 236  hi 230  warn 210
 gw 44
 (gpad s n) (#s < n ? (s + string (map (_ \ 32) ^(n - #s))) (snip s 0 n))
 ; the box's rows as [text fg]; the password as stars, the focused field's cursor an underscore
 (greet-rows g host names)
  (: (cur i) (g 'focus = i ? "_" "")
     (fg i) (g 'focus = i ? hi box-fg)
     edge ("+" + string (map (_ \ 45) ^(gw - 2)) + "+")
     (row s) ("| " + gpad s (gw - 4) + " |")
     sn (names (g 'sess % #names))
     [[edge box-fg] [(row (gpad "" (max 0 ((gw - 4 - #host) // 2)) + host)) box-fg] [(row "") box-fg]
      [(row ("login     " + g 'user + cur 0)) (fg 0)]
      [(row ("password  " + string (map (_ \ 42) ^#(g 'pass)) + cur 1)) (fg 1)]
      [(row ("session   < " + sn + " >")) (fg 2)]
      [(row "") box-fg] [(row (g 'msg)) warn] [edge box-fg]])
 ; the box centred in rows by cols, through put (y x text fg bg)
 (greet-box g host names rows cols put)
  (: rs (greet-rows g host names) y0 ((rows - #rs) // 2) x0 ((cols - gw) // 2)
     (each ^#rs (i \ put (y0 + i) x0 (rs i 0) (rs i 1) box-bg)))
 ; a key: the state moved, and 'try when enter asks for a login; none while a failure waits
 (greet-key g k n)
  (: f (g 'focus)
     fd (f = 0 ? 'user 'pass)
     (? (clock 0 < g 'hold) ()
        (k = 9 || k = -9) (pin g 'focus ((f + 1) % 3), ())
        (k = -8) (pin g 'focus ((f + 2) % 3), ())
        (f = 2 && k = -1) (pin g 'sess ((g 'sess + n - 1) % n), ())
        (f = 2 && k = -2) (pin g 'sess ((g 'sess + 1) % n), ())
        (k = 13 || k = 10) (f = 0 ? (pin g 'focus 1, ()) 'try)
        (f < 2 && (k = 127 || k = 8)) (: v (g fd) (pin g fd (0 < #v ? (snip v 0 (#v - 1)) v), ()))
        (f < 2 && 32 <= k < 127 && #(g fd) < 64) (pin g fd (g fd + string k), ())
        ()))
 ; --- the terminal ---
 (gr-host _) (uname 0 @ u (two? u && 1 < #u ? (u 1) "localhost"))
 (gr-try g root line ss)
  (: w (login-auth root (g 'user) (g 'pass))
     (? (two? w) (: se (ss (g 'sess % #ss))
                    (ttygive ['hide], say out "\e[2J\e[H", flush out,
                     login-session root w line (se 1) (se 2),
                     line = "" ? 0 (openfd ("/dev/" + line) 6 @ fd (charm? fd ? (dup2 fd 0, dup2 fd 1, dup2 fd 2, close fd) 0)),
                     pins g 'user "" 'pass "" 'focus 0 'msg "" 'fails 0 'hold 0,
                     ttytake ['hide], 'back))
        (: n (g 'fails)
           (pins g 'pass "" 'focus 1 'fails (min 3 (n + 1)) 'msg "login incorrect" 'hold (clock 0 + (2000 << n))))))
 (gr-run root nm line)
  (: ss (greet-sessions (selfpath 0) line) names (map (s \ s 0) ss) host (gr-host 0) g (greet-new 0)
     (fresh z t) (: s (saver-make nm <z (z 1) t ()) (pins s 't0 t 'next t, s))
     (go s)
      (: now (clock 0) z (ttysize 1 1)
         s2 (<z = s 'r && z 1 = s 'c ? s (fresh z now))
         ; the saver's own rate: a frame between its steps would hold one twice
         per (1000 // peep (s2 'd) 'fps 10)
         _ (s2 'next <= now ? (pin s2 'next (s2 'next + per <= now ? (now + per) (s2 'next + per)), say out (saver-over s2 (now - s2 't0) (put \ greet-box g host names <z (z 1) put)), flush out) 0)
         ; the keys waiting, up to the end of input: a terminal gone stays readable
         keys (: (take acc) (cue? 0 ? (edkey in @ k (k = -7 ? (rev (k . acc)) (take (k . acc)))) (rev acc)) (take ()))
         ; a session ended takes the screen: the saver starts over
         back (foldl (a \ k \ (? (k = -7) (uleave 0) (greet-key g k #ss = 'try) (gr-try g root line ss) a)) () keys)
         _ (two? keys ? 0 (rest (max 5 (s2 'next - clock 0))))
         (go (back == 'back ? (fresh (ttysize 1 1) (clock 0)) s2)))
     (ttytake ['hide], go (fresh (ttysize 1 1) (clock 0))))
 (greet-main as)
  (: (opt as root nm tty) (? (atom? as) [root nm tty]
                             (<as = "-r" && two? >as) (opt >>as <>as nm tty)
                             (<as = "-s" && two? >as) (opt >>as root <>as tty)
                             (two? >as || (0 < #<as && <as 0 = 45)) (udie 2 greet-usage)
                             (opt >as root nm <as))
     o (opt as "" "life" "")
     _ (elem (o 1) saver-names ? 0 (udie 2 ("greet: no saver " + o 1)))
     tty (o 2 = "" || o 2 0 = 47 ? (o 2) ("/dev/" + o 2))
     _ (tty = "" ? 0 (: fd (openfd tty 6) (charm? fd ? (dup2 fd 0, dup2 fd 1, dup2 fd 2, setsid 1) (udie 1 ("greet: " + tty + ": " + show fd)))))
     (gr-run (o 0) (o 1) (tty = "" ? "" (snip tty 5 #tty))))
 _ (pins (cite 'verbs 'tab) 'greet (udoor 'greet greet-main greet-usage 1 1)))
) ; module greet
