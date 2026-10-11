; flicker -- how bright a light is over time: each a number at t seconds, 1 its full
; light, for a lamp, a window, a flame, anything that glows.
;
;   (flicker-stammer t sd)               a tube failing: mostly on, now and then off in a
;                                        burst of stutters; sd keeps two out of step
;   (flicker-buzz t)                     a tube's buzz, never far from full
;   (flicker-pulse t mid amp rate ph)    a breath, mid give or take amp, rate radians a
;                                        second, ph its phase
;   (flicker-blink t per on edge)        a beacon: on for on seconds of every per, up and
;                                        down over edge
;   (flicker-tv t key k)                 a room lit by a television, k of it the screen;
;                                        key keeps two screens apart
(module (flicker flicker-stammer flicker-buzz flicker-pulse flicker-blink flicker-tv)
(borrow 'view)                          ; throw, clamp, flo, min2
(:
 (flicker-stammer t sd) (: s (int (t * 12.0)) burst (throw (int (t / 3.0)) sd 151 5 = 0)
   (burst && throw s (sd + 2) 157 3 != 0 ? (0.05 * throw s 3 163 4) (throw s (sd + 4) 167 90 = 0 ? 0.3 1.0)))
 (flicker-buzz t) (0.93 + 0.07 * sin (t * 53.0) * sin (t * 7.0))
 (flicker-pulse t mid amp rate ph) (mid + amp * sin (t * rate + ph))
 (flicker-blink t per on edge) (: ph (t - per * flo (t / per))
   (clamp (min2 (ph / edge) ((on - ph) / edge)) 0.0 1.0))
 (flicker-tv t key k) (1.0 - k * (0.3 + 0.25 * sin (t * 1.7 + key * 2.1) * sin (t * 0.61 + key)))))
