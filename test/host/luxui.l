; test/host/luxui.l -- lux end to end under a headless X: an Xvfb, the real lux driver as one
; child and test/host/luxui-probe.l as another, never sharing a socket so neither can desync the
; other. no Xvfb -> a polite skip, the sentinel still printed.
; run: cat test/00-init.l test/host/luxui.l | out/love

; the display number off Xvfb's -displayfd stdout: take the first line that is
; entirely digits (server chatter shares the pty).
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "640x480x24" "-nolisten" "tcp"])
   (wfx p) (gather p @ g2 (two? g2 ? g2 (rest 2, wfx p)))
   camp {}
   (enlist k pid) (pin camp k pid)
   (strike _) (map (k \ (camp k @ p
                         ((charm? p ? (still p 15, wfx p)), 0)))
                   (keys camp))
   (must tag v) (v ? v (strike (),
                        puts "luxui: FAIL ", putx tag, putc 10,
                        quit 1))
 _ (atom? xv ? (gate-skip "luxui: ok (no Xvfb, skipped)"))
 _ (enlist 'xv <xv)
 (rdnum p) (:- (go 0 0) (go n st)
            (see p @ -1 () 13 (go n st) 10 (st @ 1 n (go 0 0))
                     c (48 <= c < 58 ? (st @ 2 (go 0 2) (go (10 * n + c - 48) 1))
                                       (go 0 2))))
 dn (rdnum >xv)
 _ (must 'display (charm? dn && atom? (gather <xv)))
 dpy ("/tmp/.X11-unix/X" + show dn)

 ; a dead moor socket -- what an exec'd restart or a dead Xephyr session leaves,
 ; bound and closed so it refuses connects -- must fall to lux's sweep at moor start
 rdir (getenv "XDG_RUNTIME_DIR" @ rd (1 < #rd ? rd "/tmp"))
 stale "lux-luxui-stale.sock"
 _ (listen ['unix (rdir + "/" + stale)] @ p (hot? p ? (close p)))
 _ (must 'stale-planted (any (= stale) (readdir rdir)))

 ; the real driver, the same modules bin/lux ships. HOME rides a scratch seat so
 ; the box's own ~/.love/etc/lux.l cannot reach a gate driving stock-layout chords
 ; every path this lays is the pid's own, so two runs over one out/ keep apart
 luxhome ("out/.luxui-home-" + show (getpid 0))
 _ (mkdir luxhome 493)
 ph (tether ["env" ("DISPLAY=:" + show dn) ("HOME=" + luxhome)
           "out/love" "-l" "src/apps/lux/core.l" "-l" "src/apps/lux/layout.l"
           "-l" "src/apps/lux/wire.l" "-l" "src/apps/lux/ewmh.l"
           "-l" "src/apps/lux/manage.l" "-l" "src/apps/lux/keys.l"
           "-l" "src/apps/lux/config.l" "-l" "src/apps/lux/lux.l"])
 _ (must 'lux-up (two? ph))
 _ (enlist 'ph <ph)

 ; the probe: its own process and streams, waiting on _NET_SUPPORTED before it
 ; drives. its pty is echoed either way, so a red run tells its story here
 pr (tether ["out/love" "-l" "src/apps/lux/core.l" "-l" "src/apps/lux/layout.l"
           "-l" "src/apps/lux/wire.l" "-l" "test/host/luxui-probe.l"
           "-e" ("(probe \"" + dpy + "\")")])
 _ (must 'probe-up (two? pr))
 _ (enlist 'pr <pr)
 g (wfx <pr)
 _ (pull camp 'pr 0)
 (echo p) (see p @ -1 0 c (putc c, echo p))
 (echo >pr,
  close >pr,
  must 'probe-clean (0 = <g),
  must 'swept !(any (= stale) (readdir rdir)),

  strike (),
  close >ph, close >xv,
  hark ["rm" "-rf" luxhome],
  test_fin (),
  puts "luxui: ok"))
