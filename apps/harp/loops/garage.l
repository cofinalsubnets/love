; garage -- machinery: a plant throbbing under a compressor, a servo, a ratchet, a
; scrape and a bin lid. a love form over harp's names, every layer a line of the
; stack: a ; at its front silences one, and the lines under the stack are spares to
; swap in. drawn at :cps 0.55.
;   love synth apps/harp/loops/garage.l     :send plays it, :w keeps it
;   love harp -n 8 -c 0.55 "$(cat apps/harp/loops/garage.l)"
(stack [
 ; the plant: a low throb, two saws a hair apart beating against each other
 (pset (pset (pset (hit (mini "saw*8")) (note (mini "[-31, -30.9]"))) (legato (pure 0.32))) (gain (pure 0.14)))
 ; the compressor: a long hiss let go on the one, a shorter one answering off the beat
 (pset (pset (hit (mini "oh ~ ~ [~ oh]")) (speed (mini "0.12 ~ ~ [~ 0.3]"))) (gain (mini "0.5 ~ ~ [~ 0.3]")))
 ; the servo: a run of short square notes up a ramp, and every third cycle down it
 (every 3 (\ q (pset q (note (range 14 -10 (fast (qi 4) saw)))))
  (pset (pset (pset (hit (mini "~ ~ sqr*12 ~")) (note (range -10 14 (fast (qi 4) saw))))
              (legato (pure 0.045))) (gain (pure 0.26))))
 ; the ratchet: rim pings, the pitch set by speed -- low is a bolt, high a tick
 (pset (pset (hit (mini "<rim(5,16) rim(5,16,3) rim(5,16,5)>")) (speed (mini "<0.35 0.5> 3.2 0.7 4.5 0.35"))) (gain (pure 0.55)))
 ; the scrape: a grain cloud of hats at random gains, the fourth bar of four
 (whenmod 4 3 (\ q (pset (pset (hit (mini "hh*48")) (speed (pure 0.4))) (gain (range 0.05 0.45 rand)))) hush)
 ; the plate: a chime an octave or two up, inharmonic, cut short -- a bin lid
 (pset (pset (pset (hit (mini "~ chime ~ ~ ~ ~ [chime ~ chime] ~")) (note (mini "~ 19 ~ ~ ~ ~ [26 ~ 23] ~")))
             (legato (pure 0.35))) (gain (pure 0.22)))
])
; spares --
; the servo as one whine: a square note sliding two octaves over the beat instead of stepping
;  (pset (pset (pset (pset (hit (mini "~ ~ sqr ~")) (note (pure -10))) (slide (pure 24))) (legato (pure 0.4))) (gain (pure 0.26)))
; the press: a kick slowed to a stamp, every other cycle, the plate stuttered after it
;  (pset (pset (hit (mini "<bd ~> ~ ~ ~")) (speed (pure 0.55))) (gain (pure 0.7)))
;  (ply 3 (pset (pset (hit (mini "~ ~ ~ chime")) (note (pure 31))) (legato (pure 0.08))))
; the alarm: two triangles a quarter tone apart, held, wandering by a semitone a cycle
;  (pset (pset (pset (hit (mini "tri tri")) (note (mini "<[7, 7.5] [8, 8.5] [6, 6.5]>"))) (legato (pure 0.9))) (gain (pure 0.12)))
; the belt: the ratchet's figure on the snare's noise, dropped a third of the time
;  (pset (pset (hit (mini "sn(7,16)?0.35")) (speed (pure 2.5))) (gain (pure 0.3)))
