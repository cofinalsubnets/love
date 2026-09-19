; --- test/host/luxui.l: lux end to end under a headless X ---
; not in the test/*.l corpus (connectu/tether are inle/*.c). spawns an Xvfb,
; sails the real lux driver (the same eight modules `make install` cats into
; bin/lux) as one child, then a probe (test/host/luxui-probe.l) as another: the
; probe drives synthetic input -- xtest FakeInput for the super+drags, SendEvent
; ClientMessages for the EWMH requests -- and asserts every effect off
; GetGeometry/GetProperty/GetInputFocus, exiting 0 iff all held. two processes
; on purpose: lux's stream and the probe's never share a socket, so neither
; can desync the other.
;
;   cat test/00-init.l test/host/luxui.l | out/love
;
; no Xvfb on the box -> a polite skip (the sentinel still prints).

; the display number off Xvfb's -displayfd stdout: take the first line that is
; entirely digits (server chatter shares the pty).
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "640x480x24" "-nolisten" "tcp"])
   (wfx p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wfx p)))
   camp {}
   (enlist k pid) (pin camp k pid)
   (strike _) (map (k \ (: p (camp k)
                           _ (charm? p ? (still p 15, wfx p)) 0))
                   (keys camp))
   (must tag v) (v ? v (strike (),
                        puts "luxui: FAIL ", putx tag, putc 10,
                        quit 1))
 _ (!(two? xv) ? (puts "luxui: ok (no Xvfb, skipped)", quit 0))
 _ (enlist 'xv <xv)
 (rdnum p) (:- (go 0 0)
               (go n st) (: c (see p)
                            (? (c = -1) ()
                               (c = 13) (go n st)
                               (c = 10) (st = 1 ? n (go 0 0))
                               (48 <= c < 58)
                                (st = 2 ? (go 0 2) (go (10 * n + c - 48) 1))
                               (go 0 2))))
 dn (rdnum >xv)
 _ (must 'display (charm? dn && !(two? (gather <xv))))
 dpy ("/tmp/.X11-unix/X" + show dn)

 ; a dead moor socket -- what an exec'd restart or a dead Xephyr session leaves,
 ; bound and closed so it refuses connects -- must fall to lux's sweep at moor start
 rdir (: rd (getenv "XDG_RUNTIME_DIR") (1 < #rd ? rd "/tmp"))
 stale "lux-luxui-stale.sock"
 _ (: p (shore (rdir + "/" + stale)) (hot? p ? (close p)))
 _ (must 'stale-planted (any (n \ n = stale) (readdir rdir)))

 ; the real driver, the same modules bin/lux ships. HOME rides a scratch seat so
 ; the box's own ~/.love/etc/lux.l cannot reach a gate driving stock-layout chords
 luxhome "out/.luxui-home"
 _ (mkdir luxhome 493)                                                          ; already there -> -EEXIST, which is the same good news
 ph (tether ["env" ("DISPLAY=:" + show dn) ("HOME=" + luxhome)
           "out/love" "-l" "apps/lux/core.l" "-l" "apps/lux/layout.l"
           "-l" "apps/lux/wire.l" "-l" "apps/lux/ewmh.l"
           "-l" "apps/lux/manage.l" "-l" "apps/lux/keys.l"
           "-l" "apps/lux/config.l" "-l" "apps/lux/lux.l"])
 _ (must 'lux-up (two? ph))
 _ (enlist 'ph <ph)

 ; the probe: its own process and streams, waiting on _NET_SUPPORTED before it
 ; drives. its pty is echoed either way, so a red run tells its story here
 pr (tether ["out/love" "-l" "apps/lux/core.l" "-l" "apps/lux/layout.l"
           "-l" "apps/lux/wire.l" "-l" "test/host/luxui-probe.l"
           "-e" ("(probe \"" + dpy + "\")")])
 _ (must 'probe-up (two? pr))
 _ (enlist 'pr <pr)
 g (wfx <pr)
 _ (pull camp 'pr 0)
 (echo p) (: c (see p) (c = -1 ? 0 (putc c, echo p)))
 _ (echo >pr)
 _ (close >pr)
 _ (must 'probe-clean (0 = <g))
 _ (must 'swept !(any (n \ n = stale) (readdir rdir)))

 _ (strike ())
 _ (close >ph) _ (close >xv)
 _ (test_fin ())
 (puts "luxui: ok"))
