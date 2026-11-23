; the sky's air and clouds: src/love/air.c under src/apps/lore/sky.l
(borrow '(sky lore vec world))
(: we (sky-weather 0) a air-earth lay (air-lay a) w 64 h 32
   (sk y) (air-sky a lay w h y) (at t i j) (map (k \ t (3 * (j * w + i) + k)) ^3)
   (near? e x y) (mag (x - y) < e) (near3 e x y) (all (k \ near? e (x k) (y k)) ^3)
   noon (sk 1.0) set (sk 0.03) low (sk -0.05) night (sk -0.3)
   ; the sun overhead through the air: beer's law down each layer's depth from 300 m, the ozone's
   ; tent 15 km of it
   beer (map (k \ exp -(a k * a 3 * (exp (-0.3 / a 3) - exp (-100.0 / a 3)) + a 5 * a 6 * exp (-0.3 / a 6) + a (7 + k) * a 11)) ^3)
   sun (y \ map (c \ c 0) (air-sun lay y)))
 (test (near3 0.01 (sun 1.0) beer))
 ; ..redder and dimmer the lower, and below the horizon as at it
 (test (: ys [1.0 0.5 0.2 0.1 0.04 0.0] qs (map sun ys)
          (all (i \ all (k \ qs (i + 1) k <= qs i k) ^3 && qs (i + 1) 2 / qs (i + 1) 0 < qs i 2 / qs i 0) ^5)))
 (test (near3 1e-12 (sun -0.5) (sun -0.9)))
 ; the sky: none of it negative, blue overhead, white by the horizon at noon
 (test (all (t \ aall (0.0 <= t)) [noon set low night]))
 (test (: s (sk 0.7) z (at s 0 (h - 1)) g (at s (w - 1) 1) (2.0 * z 0 < z 2 && g 2 / g 0 < 1.8)))
 ; ..alike all round under an overhead sun, all round at the zenith under any
 (test (all (j \ near3 1e-9 (at noon 0 j) (at noon (w - 1) j)) ^h))
 (test (near3 1e-9 (at set 0 (h - 1)) (at set (w - 1) (h - 1))))
 ; ..red toward a low sun, the shadow of the ground dim across from it, and dark by night
 (test (: t (at set 0 2) (3.0 * t 2 < t 0 && net (at set (w - 1) 2) < net t)))
 (test (: t (at low 0 0) o (at low (w - 1) 0) (4.0 * net o < net t)))
 (test (net night < 1e-5 * net noon && 0.0 < net low && net low < net set && net set < net noon))
 ; more dust, a whiter sky; an air not as said, nothing
 (test (: d (map (k \ a k * (k = 4 || k = 5 ? 8.0 1.0)) ^14) t (air-sky d (air-lay d) w h 0.7) z (at t (w - 1) (h - 1)) y (at (sk 0.7) (w - 1) (h - 1))
          (z 2 / z 0 < y 2 / y 0)))
 (test (air-lay [1 2] = ()) (air-sky a (gem-tray [2] [0.0 1.0]) w h 1.0 = ()) (air-sky a lay 1 h 1.0 = ()) (air-sun noon 1.0 = ()))
 ; the table down rays: a node's own colour at its ray, both sides of the sun alike, between two
 ; nodes the colours between, and clamped below the horizon; under a turn the same above as below
 (: (ray j c s) (: mu (2 (1.0 * j / (h - 1))) q (sqrt (1.0 - 2 mu)) (map (x \ gem-tray [1] [x]) [(q * c) mu (q * s)]))
    (look t d) (map (c \ c 0) (air-look set [w h 2.0 0.0 t] d))
    cz (1.0 - 2.0 * 2 (1.0 * 9 / (w - 1))) sz (sqrt (1.0 - 2 cz)))
 (test (near3 1e-9 (look 0 (ray 5 cz sz)) (at set 9 5)) (near3 1e-9 (look 0 (ray 5 cz -sz)) (at set 9 5)))
 (test (: m (2 (5.5 / (h - 1))) q (sqrt (1.0 - 2 m)) g (look 0 (map (x \ gem-tray [1] [x]) [q m 0.0]))
          (near3 1e-9 g (map (k \ (at set 0 5 k + at set 0 6 k) / 2.0) ^3))))
 (test (near3 1e-12 (look 0 (map (x \ gem-tray [1] [x]) [0.9 -0.4 0.0])) (look 0 (map (x \ gem-tray [1] [x]) [0.9 0.0 0.0]))))
 (test (: (up y) (look 1 (map (x \ gem-tray [1] [x]) [0.8 y 0.1])) (near3 1e-12 (up 0.3) (up -0.3)) ))
 (test (: x (iota 5000 / 5000.0) r (air-look set [w h 0.3 0.4 0] [x x x]) o (air-look set [w h 0.3 0.4 0] (map (c \ gem-tray [1] [(x 4321)]) ^3))
          (near3 1e-12 (map (c \ c 4321) r) (map (c \ c 0) o))))
 (test (air-look set [w (h + 1) 1.0 0.0 0] (ray 5 cz sz) = ()) (air-look set [w h 1.0 0.0 0] [(iota 3) 1 2] = ()))
 ; a number's ray as a tray's, and the sun's height by steps
 (test (: g (air-at we 0.2 0.5 0.4 0 (gem-tray [1] [0.3]) (gem-tray [1] [0.5]) (gem-tray [1] [-0.2])) n (air-at we 0.2 0.5 0.4 0 0.3 0.5 -0.2) (near3 1e-12 n (map (c \ c 0) g))))
 (test (air-of we 0.2 == air-of we 0.20001))
 ; the clouds' thickness in C as in love, its weights numbers or trays, both sides of nothing
 (: mp (sky-maps ()) wx (sky-weather 1) sim 12345.6 n 5000
    u (iota n * 0.0371 - 90.0) v (iota n * -0.0213 + 20.0) wt (iota n / (1.0 * n)))
 (test (all (W \ amax (sq (thick-t wx mp u v sim W - thick-n wx mp u v sim W)) < 1e-24) [[1.0 1.0 1.0] [0.3 0.7 0.0] [wt (1.0 - wt) 0.5]]))
 (test (tray? (cloud-thick (mp 'cloud) (0.3 . map (k \ 0.0) ^6) u v [1.0 1.0 1.0])) (cloud-thick (mp 'cloud) [0.0] u v [1.0 1.0 1.0] = ())
       (cloud-thick u [0.0 0.0 0.0 0.0 0.0 0.0 0.3] u v [1.0 1.0 1.0] = ()))
 ; the scene's light: the sun's colour the air's, warm, redder the lower; the sky's blue by day,
 ; as bright as the day is, and no step as the sun moves
 (: (lit y) (sky-lit [0.0 y (sqrt (1.0 - 2 y))] (sky-weather 0) 0.0 0.0) (mean c) (net c / 3.0))
 (test (: s (map (y \ lit y 'sunc) [0.9 0.4 0.15 0.05]) (all (i \ s i 0 = 1.0 && s i 2 < s i 1 && s i 1 < 1.0 && (i = 0 || s i 1 < s (i - 1) 1)) ^4)))
 (test (: c (lit 0.7 'amb) (c 0 < c 1 && c 1 < c 2 && near? 0.02 (mean c) 0.4833)))
 (test (: c (lit -0.5 'amb) (near3 1e-12 c [0.05 0.055 0.075])))
  ; ..the ambient's hue at any height as a sky laid for that height has it
 (test (all (y \ near3 0.02 (air-amb we y) (map (q \ 1.0 + air-own * (q - 1.0)) (air-hue we y))) [-0.06 0.013 0.11 0.37 0.83]))
 ; a weather's own air: its sky and its light its own, the earth's as they were
 (: wa (pins (sky-weather 0) 'air (map (k \ a (k = 0 ? 2 (k = 2 ? 0 k))) ^14)) s1 [0.0 0.5 (sqrt 0.75)] e0 (air-of we 0.5 0)
    le (sky-lit s1 we 0.0 0.0) la (sky-lit s1 wa 0.0 0.0) zn (gem-tray [1] [0.0]) ze (gem-tray [1] [1.0])
    z (wx \ map (c \ c 0) (air-at wx 0.5 0.0 0.8 0 zn ze zn)))
 (test (z we 0 < z we 2) (z wa 2 < z wa 0))
 (test (le 'amb 0 < le 'amb 2) (la 'amb 2 < la 'amb 0) (la 'sunc 2 > la 'sunc 0) (air-of we 0.5 0 = e0))
 ; a sky painted: a list's ends and middle, dark by night, its hue the ambient's; a function's
 (: wg (pins (sky-weather 0) 'sky [[1.0 0.5 0.0] [0.2 0.2 0.2] [0.0 0.5 1.0]])
    (ry wx sy m) (map (c \ c 0) (air-at wx sy 0.0 0.8 0 (gem-tray [1] [(sqrt (1.0 - 2 m))]) (gem-tray [1] [m]) zn)))
 (test (near3 1e-9 (ry wg 0.6 0.0) [1.0 0.5 0.0]) (near3 1e-9 (ry wg 0.6 1.0) [0.0 0.5 1.0]) (near3 0.02 (ry wg 0.6 0.25) [0.2 0.2 0.2]) (near3 1e-9 (ry wg -0.3 0.5) [0.0 0.0 0.0]) (: f (map (y \ ry wg y 1.0 2) [-0.2 -0.1 0.0 0.1 0.3]) (all (i \ f i < f (i + 1) + 1e-9) ^4 && 0.0 < f 0)))
 (test (near3 1e-9 (sky-lit s1 wg 0.0 0.0 'sunc) (le 'sunc)) (: p (pins (sky-weather 0) 'sky [[0.9 0.1 0.1] [0.9 0.1 0.1]]) c (sky-lit s1 p 0.0 0.0 'amb) (c 1 < c 0)))
 (: wf (pins (sky-weather 0) 'sky (y \ mu \ c \ [mu (0.5 + 0.5 * c) y])))
 (test (near3 1e-3 (ry wf 0.5 0.5) [0.5 0.5 0.5]) (near3 1e-3 (ry wf 0.25 0.8) [0.8 0.5 0.25]))
 (test (all (i \ (: y (0.01 * i - 0.3) p (lit y 'amb) q (lit (y + 0.001) 'amb) (all (k \ mag (p k - q k) < 0.01) ^3))) ^60))
 ; smog's own colour: what it turns the sky and the light toward, a brown none said, as bright
 (: hz (wx \ sky-lit s1 wx 0.0 0.0 'amb) wh (pins (sky-weather 0) 'smog 1.0 'smog-hue [0.2 1.0 0.3]) wb (pins (sky-weather 0) 'smog 1.0)
    g (hz wh) b (hz wb))
 (test (g 0 < g 2 && g 2 < g 1) (b 2 < b 1 && b 1 < b 0) (near? (0.1 * mean b) (mean g) (mean b)))
 (test (near3 1e-9 (map (x \ x / mean g) g) (map (x \ x / 0.5) [0.2 1.0 0.3])))
 ; a dye leaves a painted sky as it is
 (: wd (pins (sky-weather 0) 'sky [[1.0 0.5 0.0] [1.0 0.5 0.0]] 'dye [0.1 0.2 0.9])
    c (wx \ sky-colour-at (sky-lit [0.0 0.5 (sqrt 0.75)] wx 0.0 0.0) wx 0.0 (gem-tray [1] [0.6]) (gem-tray [1] [0.8]) zn 0.0 0.0 0.0))
 (test (: q (c wd) (q 0 0 > 3.0 * q 2 0)) (: q (c (pins (sky-weather 0) 'dye [0.1 0.2 0.9])) (q 0 0 < q 2 0)))
 ; a level's forms: its sky's weather takes them, a wrong one stops the level
 (: (lv f) (world-read ("(: t (texture 8 8 1 '((fill (rgb 1 1 1))))) (level \"t\" (start [0 0 0] 0 180) (room [-3 0 -3] [3 3 3]) (sky 12 'clear) " + f + ")")) (skl f) (lv f 'sky))
 (test (skl "(gradient [(rgb 1 0 0) (rgb 0 0 1)])" 'sky = [[1.0 0.0 0.0] [0.0 0.0 1.0]]) (#(skl "(atmosphere [0.02 0.01 0.005 8 0.02 0.021 2 0 0 0 25 15 0.7 0.2])" 'air) = 14) (skl "" 'sky = ()) (skl "" 'air = ()))
 (test (skl "(smog-hue (rgb 0.2 1 0.3))" 'smog-hue = [0.2 1.0 0.3]) (skl "" 'smog-hue = ()) (string? (lv "(smog-hue (rgb 0 0 0))")) (string? (lv "(gradient [(rgb 1 0 0)])")) (string? (lv "(atmosphere [1 2 3])")))
(test_fin ())
(puts "sky: ok\n")
