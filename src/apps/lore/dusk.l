; dusk -- the level after the apartment: a dry river through the desert at sunset, first
; person. the sun arcs down ahead and sets behind a parking garage; walking into the hole in
; its face ends the level, and the garage (garage.l) takes the screen.
; nothing is stored: a bush hashes its bank and place along the looping river, a mesa its
; bearing. dusk-new/step/move/frame are pure; only dusk-walk and dusk-run touch the tty and
; horn. dusk-walk takes a raised stage, so the apartment hands over. HORN=none plays silent.
(module (dusk dusk-run dusk-walk dusk-main dusk-new dusk-size dusk-step dusk-move dusk-settle
         dusk-frame dusk-tables dusk-song-new dusk-song-feed sun-at bush-of garage-top
         bed-w gz gw gh hole-w hole-h arc-z end-z done-ms sp loop fps pelog song-chunk
         sun-pens sky-ramp mang)
(borrow 'rove)
(borrow 'view)                          ; the screen, its rays, the pens
(borrow 'walk)                          ; the rail
(borrow 'gamelan)                       ; the song
(borrow 'posix)    ; close, for the horn
(:
 eh 1.6                               ; the eye above the bed, standing
 bed-w 2.6                            ; the bed's half width, its banks wandering a little either side
 sp 4.0 loop 48                       ; a bush every so far along a bank; the banks repeat
 far 90.0 near 25.0                   ; sight along a bank; a bush nearer than near is dark, past it haze
 fps 30
 ; the garage across the bed: its face at gz, gw either side of the bed and gh out of the
 ; sand; the hole the bed runs into, hole-w either side and hole-h at its crown
 gz 200.0 gw 60.0 gh 6.5
 hole-w 3.2 hole-h 3.4
 ; the sun's journey, over the first arc-z of the walk: from its bearing and height at the
 ; start to dead ahead and under the horizon, the garage in front of it by then
 arc-z 140.0
 maz -0.5 mel 0.32 mang 0.09          ; bearing and height at the start, and the angular radius
 end-z (gz - 0.4)                     ; inside the hole's mouth: the level done
 done-ms 900                          ; ..and this long in the dark, then the garage
 ; the pens, in the 256-colour palette. the sky from the horizon up, the sun's disc high,
 ; lower, and reddening at the horizon; the sand and the bed near, middling and far
 sky-ramp (star-tray [12] [229 222 215 209 173 168 132 96 60 18 17 16])
 sun-pens [230 214 202]
 sand-pens [180 174 138] bed-pens [137 95 96]
 ripple-pen 173 crack-pen 94 pebble-pen 95 bank-pen 137
 mesa-pen 96 dusk-mesa-pen 60
 wall-pens [59 60 96] seam-pen 238 rim-pen 173 hole-pen 16
 bush-pen 58 haze-pen 95 star-pen 244
 (frac v) (v - floor v)
 ; how far the dusk has come: 0 while the sun is up, 1 at the hole
 (dusk-of pz) (clamp ((pz - arc-z) / (end-z - arc-z)) 0.0 1.0)
 ; where the sun is: [cx cy r el az] -- the disc's centre and radius on the screen, and
 ; its height and bearing in the world; far off the screen when it is behind the player
 (sun-at st) (: th (st 'th) hz (st 'hz) foc (st 'foc) cx (st 'cx)
   u (clamp (st 'pz / arc-z) 0.0 1.0)
   az (maz * (1.0 - u)) el (mel * cos (u * pi / 2.0) - mang * u)
   rel (wrap (az - th)) c (cos rel)
   (abs rel < 1.3 ? [(cx + foc * tan rel) (hz - foc * tan el / c) (foc * tan mang / c) el az]
      [-999.0 -999.0 0.0 el az]))
 ; the garage's top as an angle over the eye, from pz: what the sun sets behind
 (garage-top pz) (atan ((gh - eh) / (gz - pz)))
 ; the skyline: a mesa's height as an angle, by bearing cell, a value noise flattened
 ; at its tops and its feet
 mesa-n 512 mesa-h 0.035
 (mesa-v i) (: k (i // 16) f (i % 16 / 16.0) s (f * f * (3.0 - 2.0 * f))
               a (dice k 3 11 100 / 100.0) b (dice ((k + 1) % (mesa-n // 16)) 3 11 100 / 100.0)
               (mesa-h * clamp ((a + s * (b - a) - 0.5) * 3.5) 0.0 1.0))
 mesas (gem-tray [mesa-n] (map mesa-v ^mesa-n))
 ; a bush by its bank s (-1 or 1) and its index k along the river: where it stands, how
 ; tall and wide; the loop has so many places, and each is hashed once and kept
 bushes {}
 (bush-of k s) (: kk ((k % loop + loop) % loop) key (kk * 2 + (0 < s))
   b (peep bushes key ())
   b2 (two? b ? b
         (: seed (s + 2)
            b3 [(dice kk seed 3 100 / 100.0 * sp)
                (s * (bed-w + 1.5 + dice kk seed 5 100 / 100.0 * 14.0))
                (0.4 + dice kk seed 7 100 / 100.0 * 0.9)
                (0.8 + dice kk seed 9 100 / 100.0 * 1.4)]
            (pin bushes key b3, b3)))
   {'z (k * sp + b2 0) 'x (b2 1) 'ht (b2 2) 'wd (b2 3)})
 ; the frame's tables, trays over the columns: rays and bearings, star and mesa cells, where
 ; each ray meets the garage's face (its top and foot rows, the hole's crown), and the bushes'
 ; top and foot rows, near and far
 (dusk-tables st) (: w (st 'w) hz (st 'hz) foc (st 'foc) px (st 'px) pz (st 'pz)
   xc (iota w + 0.5) us ((xc - st 'cx) / foc)
   rs (view-rays st) vx (rs 0) vz (rs 1)
   ab (st 'th + atan us)
   cell ((floor (ab / tau * mesa-n) % mesa-n + mesa-n) % mesa-n)
   tw ((gz - pz) / max vz 0.000001)
   hx (px + tw * vx)
   ; ..and where the columns' edges meet it, so the columns tile the face exactly
   th (st 'th) ue ((iota (w + 1) - st 'cx) / foc)
   he (px + (gz - pz) / max (cos th - ue * sin th) 0.000001 * (sin th + ue * cos th))
   hxa (peep he (iota w) 0.0) hxb (peep he (iota w + 1) 0.0)
   ; the hole's crown, an arch jagged along the face -- only once a column is narrower than the
   ; jags, which would otherwise shimmer
   jag ((hxb - hxa < 0.4) * (throw (floor (hx * 2.5 + 1000.0)) 0 17 5 * 0.12 - 0.24))
   q (hx / hole-w)
   crown ((q * q < 1.0) * (hole-h * sqrt (max 0.0 (1.0 - q * q)) + jag))
   tb {'xc xc 'ab ab 'vx vx 'vz vz 'qa (cell // 2)
       'mt (hz - foc * peep mesas cell 0.0)
       'tw tw 'hx hx 'hxa hxa 'hxb hxb 'win ((0.0 < vz) * (hx * hx < gw * gw))
       'wt (hz - foc * (gh - eh) / tw) 'wf (hz + foc * eh / tw) 'crown crown
       'dusk (dusk-of pz) 'sun (sun-at st)}
   (lay-bushes st tb))
 ; the bushes within sight, each laid into the columns it covers, its foot on the sand;
 ; none past the garage's face
 (lay-bushes st tb) (: px (st 'px) pz (st 'pz) th (st 'th) hz (st 'hz) sn (sin th) cs (cos th)
   w (st 'w) foc (st 'foc) cx0 (st 'cx)
   tabs {'tops {} 'foots {} 'ntops {} 'nfoots {}}
   (one k s) (: b (bush-of k s)
     dx (b 'x - px) dz (b 'z - pz)
     d (dx * sn + dz * cs) lat (dx * cs - dz * sn)
     (0.5 < d && b 'z < gz - 2.0 ?
        (lat / d @ u
           (abs u < 1.5 ?
              (: cx (cx0 + foc * u) hw (foc * b 'wd / (2.0 * d)) hg (foc * b 'ht / d) by (hz + foc * eh / d)
                 tops (tabs (d < near ? 'ntops 'tops)) foots (tabs (d < near ? 'nfoots 'foots))
                 xa (clamp (flo (cx - hw)) 0 (w - 1)) xb (clamp (flo (cx + hw)) 0 (w - 1))
                 (col x) (x <= xb ? (: q (abs (x + 0.5 - cx) / hw)
                                       hx (q < 1.0 ? (hg * sqrt (1.0 - q * q)) 0.0)
                                       (0.0 < hx ? (pin tops x (min2 (peep tops x 999.0) (by - hx)),
                                                    pin foots x (max2 (peep foots x -999.0) by)),
                                        col (x + 1))))
                 (col xa))))))
   (go k k1) (k <= k1 ? (one k -1, one k 1, go (k + 1) k1))
   (tray-of tab d) (gem-tray [w] (map (x \ peep tab x d) ^w))
   (go (flo ((pz - 2.0) / sp)) (flo ((pz + far) / sp)),
    pins tb 'tops (tray-of (tabs 'tops) 999.0) 'foots (tray-of (tabs 'foots) -999.0)
            'ntops (tray-of (tabs 'ntops) 999.0) 'nfoots (tray-of (tabs 'nfoots) -999.0)))
 ; the sky's row: the ramp by height, warmed toward the sun (the afterglow too) and cooled by
 ; the dusk; a few stars high up once dark enough, and the disc
 (sky-row y st tb) (: foc (st 'foc) e (atan ((st 'hz - y - 0.5) / foc)) dusk (tb 'dusk) sn (tb 'sun)
   i0 (2.0 + 14.0 * e + dusk * (1.5 + 6.0 * e))
   da (tb 'ab - sn 4) de (e - sn 3) dd (sqrt (da * da + de * de))
   warm (max 0.0 (min 3.0 ((0.7 - dd) * 5.0)) * (1.0 - 0.6 * dusk))
   c (peep sky-ramp (floor (max 0.0 (min 11.0 (i0 - warm)))) 16)
   qe (flo (e * foc))
   star ((0.5 < dusk) * (8.5 < i0) * (0 = throw (tb 'qa) qe 7 53))
   c2 (over c star star-pen)
   dx (tb 'xc - sn 0) dy (y + 0.5 - sn 1) r (sn 2)
   disc (sun-pens (? (0.1 < sn 3) 0 (0.04 < sn 3) 1 2))
   (over c2 (dx * dx + dy * dy < r * r) disc))
 ; the sand and the bed at a row, by distance near, middling or far: near, sand rippled and
 ; pebbled, the bed's mud cracked, a bank's edge darker. a crack is at least a pixel wide, and
 ; gone where cracks would stand closer than pixels
 (ground-row y st tb) (: foc (st 'foc) t (foc * eh / (y + 0.5 - st 'hz))
   wx (st 'px + t * tb 'vx) wz (st 'pz + t * tb 'vz)
   be (bed-w + 0.35 * sin (0.23 * wz)) ax2 (wx * wx)
   inbed (ax2 < be * be)
   k (? (t < 10.0) 0 (t < 30.0) 1 2)
   c (over (sand-pens k) inbed (bed-pens k))
   (1 < k ? c
      (: pebble ((1 - inbed) * (0 = throw (floor (wx * 3.0 + 1000.0)) (floor (wz * 3.0 + 1000.0)) 5 29))
         c2 (over c pebble pebble-pen)
         bank ((be * be <= ax2) * (ax2 < (be + 0.3) * (be + 0.3)))
         c3 (over c2 bank bank-pen)
         (0 < k ? c3
            (: rip ((1 - inbed) * (0.75 < sin (2.1 * wz + 0.8 * wx + 0.6 * sin (0.5 * wx))))
               fx (frac (wx * 0.9 + 0.25 * sin (1.3 * wz))) fz (frac (wz * 1.1 + 0.25 * sin (1.7 * wx)))
               ex (t / foc * 0.9) ez (t * t / (foc * eh) * 1.1)      ; a pixel's reach across each
               crack (inbed * (0 < (ex < 0.4) * (fx < max2 0.08 ex) + (ez < 0.4) * (fz < max2 0.08 ez)))
               (over (over c3 rip ripple-pen) crack crack-pen))))))
 ; the garage's face over a row: concrete by distance, a seam every formwork lift and every
 ; bay, the parapet lit until sunset, and the hole. a seam is thinner than a pixel, so it is
 ; laid in the pixel whose stretch of the face holds it, and only while seams stand apart
 (wall-over c y st tb) (: foc (st 'foc) hz (st 'hz) tw (tb 'tw) hx (tb 'hx) dusk (tb 'dusk)
   on (tb 'win * (tb 'wt <= y) * (y < tb 'wf))
   (? !(aany on) c
      (: yw (eh - (y + 0.5 - hz) * tw / foc)
         k (dusk < 0.6 ? 0 1)
         base (over (over (wall-pens k) (60.0 < tw) (wall-pens 1)) (120.0 < tw) (wall-pens 2))
         sy (tw / foc) ya (yw + 0.5 * sy) yb (yw - 0.5 * sy)   ; the pixel's stretch of the face, up and across
         xa (tb 'hxa) xb (tb 'hxb)
         lift ((sy < 0.5) * (floor (ya / 1.2) != floor (yb / 1.2)))
         bay ((xb - xa < 1.5) * (floor (xb / 4.0) != floor (xa / 4.0)))
         seam (0 < lift + bay)
         rim ((gh - 0.18 < ya) * (dusk < 0.5))
         hole ((0.0 < tb 'crown) * (yw < tb 'crown))
         c2 (over (over (over base seam seam-pen) rim rim-pen) hole hole-pen)
         (over c on c2))))
 ; the bushes over a row, the far ones in haze and the near dark
 (bushes-over c y tb) (over (over c ((tb 'tops <= y) * (y <= tb 'foots)) haze-pen)
                            ((tb 'ntops <= y) * (y <= tb 'nfoots)) bush-pen)
 ; a pixel row: above the horizon the sky and the mesas on it, below it the ground; the
 ; garage over either, and the bushes over that
 (pixel-row y st tb) (: hz (st 'hz)
   c (y < hz ? (sky-row y st tb @ s
                  (over s (tb 'mt <= y + 0.5) (0.5 < tb 'dusk ? dusk-mesa-pen mesa-pen)))
        (ground-row y st tb))
   (bushes-over (wall-over c y st tb) y tb))
 (dusk-frame st) (dusk-tables st @ tb
   (view-frame (st 'w) (st 'h) (y \ pixel-row y st tb) {}))
 ; the state: the screen, where the player stands and faces, the tick, whether they walk
 ; on by themselves, and whether they are in the hole
 (dusk-new w h) (view! {'px 0.0 'pz 0.0 'th 0.0 't 0 'walk 0 'done 0} w h (h // 2))
 ; the screen's shape: w cells across and r rows, the horizon off the top and bottom quarter
 (dusk-size st w r) (view-size st w r 4)
 ; a step on down the bed, whichever way the player faces, no further than the hole's
 ; mouth, where the level is done and the walking with it
 (dusk-move st mv) (st 'done ? st
                      (min2 (st 'pz + mv) end-z @ pz2
                         (pin st 'pz pz2,
                          end-z <= pz2 ? (pins st 'done 1 'walk 0) st)))
 ; ..and in the hole, the view eased back to dead ahead and level, a frame at a time
 (dusk-settle st) (: h2 (st 'h // 2) hz (st 'hz)
                     (pins st 'th (0.8 * st 'th) 'hz (hz + (hz < h2) - (h2 < hz))))
 ; turns stay within facing of ahead; there is no walking back
 facing (pi / 3.0)
 (dusk-step st a) (walk-rail st a facing dusk-move)
 ; --- the song: a pelog chime now and then, and a gong under it ------------------------
 ; pelog bem, five of its seven uneven steps, in semitones from middle c
 pelog [0.0 1.2 2.7 6.7 7.85]
 song-chunk (song-rate // fps)                          ; a frame's worth
 ; ..two octaves down, the high one a time in three; the gong a little under the low c
 tune {'scale pelog 'down -24 'high 3 'gain 0.5 'odds 10 'gong -19.3 'gong-gain 0.8 'gong-legato 8.0 'gong-every 9}
 (dusk-song-new h st) (gamelan-new h st)
 (dusk-song-feed s) (gamelan-feed s tune)
 ; --- the walk, on view's loop: walking on by itself, or in the hole settling a frame at a
 ; time, then the garage ---
 (dusk-walk _) (view-walk {'new dusk-new 'size dusk-size 'frame dusk-frame 'key dusk-step 'fps fps
                           'binds (view-bind view-binds walk-binds) 'listed walk-listed
                           'tick (st \ (? (st 'done) (dusk-settle st) (st 'walk) (dusk-move st 0.25)))
                           'song (view-song dusk-song-new dusk-song-feed)
                           'linger done-ms 'next ['garage 'garage-walk]})
 (dusk-run _) (view-run dusk-walk)
 dusk-usage "usage: love play dusk   (h l turn, k walks on, u n look, space walks on to the garage; ? the keys, q or esc leaves)"
 (dusk-main as) (view-main "dusk" dusk-usage (as \ view-words as []) dusk-run as)
 _ ((cite 'lore 'lore-enlist) 'dusk (udoor 'dusk dusk-main dusk-usage 1 1)))
) ; module dusk
