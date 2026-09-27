; --- test/host/dusk.l: the desert at sunset, headless ---
; not in the test/*.l corpus (it loads a crew module). the scene is pure love, so
; everything but the tty runner gates here: the frame's shape and pens, the sun turning
; with the player and setting behind the garage, the dark coming on, the hole filling
; the screen at the end, the banks repeating, a step, the helm, and the song into a jug.
;   cat test/00-init.l test/host/dusk.l | out/love

(borrow 'dusk)    ; the artifact's module, warm from the tree

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   (pen? s n) (has? s ("38;5;" + show n + ";") || has? s (";48;5;" + show n + "m"))
   (sun? f) (any (p \ pen? f p) sun-pens)
   (at z) (dusk-frame (pins (dusk-new 80 48) 'pz z))
   (sun th z) (sun-at (pins (dusk-new 80 48) 'th th 'pz z)))

; --- the frame: 24 rows of 80 cells, the sky, the sun, the sand and the bed ---
(: st (dusk-new 80 48) f (dusk-frame st)
   wide (dusk-new 120 60) g (dusk-frame wide)
 (test
  (rows f = 24) (count f "▀" = 1920)
  (rows g = 30) (count g "▀" = 3600)
  (wide 'hz = 30) (wide 'foc = 60.0) (wide 'cx = 60.0)
  (sun? f) (pen? f 215)                         ; the sun, and the sky warm at the horizon
  (pen? f 180) (pen? f 137)                     ; the sand, and the bed
  (!(pen? f 244))                               ; no stars while the sun is up
  (f = dusk-frame st)                           ; the same state paints the same frame
  (st 'px = 0.0) (st 'pz = 0.0) (st 'th = 0.0) (st 'hz = 24) (st 'done = 0)))

; --- the sun turns with the player and is off the screen behind them ---
(: a (sun 0.0 0.0) b (sun -0.5 0.0) c (sun 3.0 0.0)
 (test (a 0 < 40.0) (a 1 < 24.0) (a 0 < b 0)   ; ahead and to the left, up; a left turn brings it right
       (0.0 < a 2) (c 0 < -900.0)))              ; a radius; behind, far off the screen

; --- ..and goes where the walking takes it: down toward dead ahead, behind the garage
; --- while it is still over the horizon, and under it by the end of its arc
(: s0 (sun 0.0 0.0) s1 (sun 0.0 60.0) s2 (sun 0.0 112.0) s3 (sun 0.0 126.0) s4 (sun 0.0 arc-z)
 (test (s1 3 < s0 3) (s0 4 < s1 4) (s2 3 < s1 3)      ; lower and nearer ahead as the walk goes on
       (0.0 < s2 3 < garage-top 112.0)                   ; its middle behind the roof, over the horizon
       (sun? (at 112.0))                                 ; ..its top still showing over it
       (0.0 < s3 3 + mang < garage-top 126.0)        ; its top edge over the horizon but under the roof
       (!(sun? (at 126.0)))                              ; ..and not a pixel of it seen
       (s4 3 < 0.0) (s4 4 = 0.0)))

; --- the dusk: dark and starry past the sunset, and at the mouth nothing but the hole ---
(: late (at 190.0) f (at end-z)
 (test (pen? late 244) (pen? late 16) (!(sun? late))
       (rows f = 24) (pen? f 16)
       (!(pen? f 180)) (!(pen? f 137)) (!(pen? f 215))))

; --- the banks repeat: a whole loop down the river stands the same bush again ---
(: b0 (bush-of 3 1) b1 (bush-of (3 + loop) 1) b2 (bush-of 3 -1)
 (test (b0 'ht = b1 'ht) (b0 'wd = b1 'wd) (b1 'z - b0 'z = loop * sp)
       (bed-w < b0 'x) (b2 'x < 0.0 - bed-w)))

; --- a step: on down the bed whichever way the player faces, never back, and at the
; --- mouth the level is done, the view easing back to dead ahead and level
(: st (dusk-new 80 48)
   _ (dusk-step st 107) z1 (st 'pz)
   _ (dusk-step st -9) _ (dusk-step st 106) z2 (st 'pz)
   _ (pins st 'th 1.0 'pz 10.0) _ (dusk-step st 107) z3 (st 'pz)
   e (pins (dusk-new 80 48) 'pz (end-z - 0.3) 'th 0.5 'hz 20 'walk 1)
   _ (dusk-step e 107) ez (e 'pz) ed (e 'done) ew (e 'walk)
   _ (dusk-step e 107) _ (dusk-step e 108) _ (dusk-move e 1.0)
   th0 (e 'th) hz0 (e 'hz)
   _ (dusk-settle e) th1 (e 'th) hz1 (e 'hz)
   _ (each ^60 (i \ dusk-settle e))
 (test (0.0 < z1) (z2 = z1) (abs (z3 - 10.35) < 0.001)    ; on, and the back keys took none
       (ez = end-z) (ed = 1) (ew = 0)                        ; the mouth: done, and the walk with it
       (e 'pz = end-z) (th0 = 0.5) (hz0 = 20)                ; ..no further, no turn
       (abs (th1 - 0.4) < 0.001) (hz1 = 21)                  ; the settle a step at a time
       (abs (e 'th) < 0.001) (e 'hz = 24)))

; --- the helm: turns stop at sixty degrees, tilts clamp, space walks ---
(: st (dusk-new 80 48)
   _ (dusk-step st 108) th1 (st 'th)
   _ (each ^100 (i \ dusk-step st 104)) th2 (st 'th)
   _ (each ^10 (i \ dusk-step st 117)) hz1 (st 'hz)
   _ (each ^20 (i \ dusk-step st 110)) hz2 (st 'hz)
   _ (dusk-step st 32) w1 (st 'walk)
   _ (dusk-step st 32) w2 (st 'walk)
   _ (dusk-step st 120) _ (dusk-step st 'tap) _ (dusk-step st ())
 (test (0.0 < th1) (-1.05 < th2 < 0.0)
       (24 < hz1 <= 36) (12 <= hz2 < 24) (w1 = 1) (w2 = 0)
       (st 'pz = 0.0)
       (: s2 (dusk-size (dusk-new 80 48) 100 40) (s2 'w = 100 && s2 'h = 80 && s2 'hz = 40 && s2 'foc = 50.0))))

; --- the song: ten seconds into a jug, a chime now and then over a gong, never silent ---
(: j (jug 0) s (dusk-song-new j (wheel 7))
   (feed n) (0 < n ? (dusk-song-feed s, feed (n - 1)) s)
   _ (feed 300)
   out (slurp j)
   loud (net (map (i \ (out (i * 97) != 0 ? 1 0)) ^2000))
   s2 (dusk-song-new (jug 0) (wheel 7))
   _ (: (go n) (0 < n ? (dusk-song-feed s2, go (n - 1))) (go 300))
 (test (#out = 4 * song-chunk * 300) (2 <= s 'struck <= 20) (0 < s 'gong)
       (#pelog = 5) (pelog 0 = 0.0)
       (100 < loud) (s 'struck = s2 'struck)))

(test_fin (),
 puts "dusk: ok -- the sun turns, sets behind the garage, the dusk comes on, the banks repeat, a step walks on, the hole takes the screen, and the chimes sound\n")
