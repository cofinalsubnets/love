; garage -- machinery: a plant throbbing under a compressor, a servo, a ratchet, a
; scrape and a bin lid. a love form over harp's names, every layer a line of the
; stack: a ; at its front silences one, and the lines under the stack are spares to
; swap in. drawn at :cps 0.55.
;   love synth apps/harp/loops/garage.l     :send plays it, :w keeps it
;   love harp -n 8 -c 0.55 "$(cat apps/harp/loops/garage.l)"
(stack [
 ; the plant: a low throb, two saws a hair apart beating against each other
 (psets (hit "saw*8") (note "[-31, -30.9]") (legato 0.32) (gain 0.14))
 ; the compressor: a long hiss let go on the one, a shorter one answering off the beat
 (psets (hit "oh ~ ~ [~ oh]") (speed "0.12 ~ ~ [~ 0.3]") (gain "0.5 ~ ~ [~ 0.3]"))
 ; the servo: one square note whining up two octaves on the third beat, and every
 ; third cycle down them from the top
 (every 3 (\ q (psets q (note 14) (slide -24)))
  (psets (hit "~ ~ sqr ~") (note -10) (slide 24) (legato 0.4) (gain 0.26)))
 ; the ratchet: rim pings, the pitch set by speed -- low is a bolt, high a tick
 (psets (hit "<rim(5,16) rim(5,16,3) rim(5,16,5)>") (speed "<0.35 0.5> 3.2 0.7 4.5 0.35") (gain 0.55))
 ; the scrape: a grain cloud of hats at random gains, the fourth bar of four
 (whenmod 4 3 (\ q (psets (hit "hh*48") (speed 0.4) (gain (range 0.05 0.45 rand)))) hush)
 ; the plate: a chime an octave or two up, inharmonic, cut short -- a bin lid
 (psets (hit "~ chime ~ ~ ~ ~ [chime ~ chime] ~") (note "~ 19 ~ ~ ~ ~ [26 ~ 23] ~") (legato 0.35) (gain 0.22))
])
; spares --
; the servo as it was: twelve short square notes stepping up a ramp
;  (psets (hit "~ ~ sqr*12 ~") (note (range -10 14 (fast 4 saw))) (legato 0.045) (gain 0.26))
; the press: a kick slowed to a stamp, every other cycle, the plate stuttered after it
;  (psets (hit "<bd ~> ~ ~ ~") (speed 0.55) (gain 0.7))
;  (ply 3 (psets (hit "~ ~ ~ chime") (note 31) (legato 0.08)))
; the alarm: two triangles a quarter tone apart, held, wandering by a semitone a cycle
;  (psets (hit "tri tri") (note "<[7, 7.5] [8, 8.5] [6, 6.5]>") (legato 0.9) (gain 0.12))
; the belt: the ratchet's figure on the snare's noise, dropped a third of the time
;  (psets (hit "sn(7,16)?0.35") (speed 2.5) (gain 0.3))
