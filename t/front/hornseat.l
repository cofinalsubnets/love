; t/front/hornseat.l -- the horn's SEAT door, and the ring a card pulls it through.
;
; these run under b/frontseat: t/front/main.c built with -D ai_horn_seat=1, where
; i/horn.c asks k_horn_* for the device instead of hunting a kernel's. that is the lane
; inle runs over i/hda.c and the playdate over its SDK, and it is the only one of the
; horn's three kinds no gate could reach -- the other two want a card, or want no card
; at all.
;
; the frontend's k_horn_* ARE the device, over i/hornring.h: the same header
; i/playdate/pdglue.c hands its SDK audio callback. (tapped ()) drains that ring the way
; a card would and lays it back interleaved, so every law here rides a real push, a real
; pull and -- the ring being 1024 frames against writes of a few hundred -- a real wrap.
; a ring is otherwise the one piece of a seat's sound a gate cannot see, because a gate
; has no card to pull with.
;
; the difference worth gating twice is the doubling. i/horn.c's horn_land sits between
; the port and this door and widens a mono port to stereo, a device being always stereo
; -- and the SINK is not a device, so nothing widens there. t/front/horn.l says a mono
; port taps as mono; this file says the same port reaches a seat as stereo. which of the
; two a seat growing sound gets depends only on which door it wired.

(: (ramp n) (string (map (\ i (i % 251)) (jot n))))

; --- a stereo port goes down as it is -------------------------------------------
(: h (horn 44100 2)
   _ (assert (! (nom? h)))
   pcm (ramp 1600)                              ; 400 stereo frames, inside the ring
   _ (say h pcm)
   _ (flush h)
   _ (assert (= 400 (horn-lag h)))              ; the ring's FILL, before anything pulls
   got (tapped ())                              ; ..and the pull that empties it
   _ (assert (= pcm got))
   _ (assert (= 0 (horn-lag h)))                ; drained
   _ (assert (= 44100 (taprate ())))
   (assert (= 2 (tapchans ()))))

; --- ..and a mono one is DOUBLED before it arrives -------------------------------
; the port still calls itself mono; what reached the device is twice the bytes, each
; sample said on both channels. this is the law t/front/horn.l's sink lane inverts.
(: h (horn 44100 1)
   _ (assert (! (nom? h)))
   pcm (ramp 800)                               ; 400 mono frames
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   _ (assert (= 1600 (tally got)))              ; ..400 STEREO frames
   _ (assert (= 2 (tapchans ())))
   ; frame i is mono sample i twice: bytes 2i,2i+1 landing at 4i..4i+3
   (assert (foldl (\ a i (&& a (&& (= (got (4 * i)) (pcm (2 * i)))
                                   (&& (= (got ((4 * i) + 1)) (pcm ((2 * i) + 1)))
                                   (&& (= (got ((4 * i) + 2)) (pcm (2 * i)))
                                       (= (got ((4 * i) + 3)) (pcm ((2 * i) + 1))))))))
                  1 (jot 400))))

; --- the ring WRAPS, and nothing is lost or reordered across it ------------------
; 1024 frames deep, so eight rounds of 400 carry the free-running indices past the end
; three times over. a ring that masked its indices in place, or compared them wrongly at
; the seam, loses a frame exactly here and nowhere in the laws above.
(: h (horn 44100 2)
   _ (assert (! (nom? h)))
   (round i) (: pcm (ramp (1600 + (4 * i)))      ; a different WHOLE-FRAME length each time
                _ (say h pcm)
                _ (flush h)
                got (tapped ())
                (assert (= pcm got)))
   ; `map`, not a `&&` fold: assert answers FALSY when it passes, so a fold over && stops
   ; after round 0 and the seven rounds that cross the seam never run at all. that
   ; spelling passed a ring provably losing a frame from round 1 on.
   (map round (jot 8)))

; --- a starved ring answers silence, not the last frame --------------------------
; nothing has been written since the drain above, so a pull finds nothing. (tapped ())
; laying nothing back says only that -- it lays the frames that were REAL, so a card
; holding its last frame instead of zeroing reads the same from there. (starved n) is
; the other half: it pulls into buffers a card would have handed in, dirty, and counts
; what came back loud. holding the last frame rings a tone under a stall.
(: h (horn 44100 2)
   _ (assert (= 0 (horn-lag h)))
   _ (assert (= "" (tapped ())))
   _ (assert (= 0 (starved 64)))
   ; ..and the control, so the 0 above is the ring being silent and not `starved` blind
   _ (say h (ramp 400))
   _ (flush h)
   _ (assert (0 < (starved 64)))
   (tapped ()))                                 ; drained again, for the law below

; --- the lag is the DEVICE's number, not a clock's --------------------------------
; the sink reckons what is played from ai_clock at the nominal rate, so its lag drifts
; with the wall. a seat answers k_horn_lag, which is what the ring actually holds --
; exact, and the number backpressure is owed.
(: h (horn 44100 2)
   _ (say h (ramp 400))                         ; 100 frames
   _ (flush h)
   _ (assert (= 100 (horn-lag h)))
   _ (say h (ramp 400))
   _ (flush h)
   _ (assert (= 200 (horn-lag h)))              ; ..and it accumulates until something pulls
   _ (tapped ())
   (assert (= 0 (horn-lag h))))

; --- misuse is the port's, not the door's ----------------------------------------
(: _ (assert (nom? (horn 10 2)))
   _ (assert (nom? (horn 44100 3)))
   (assert (nom? (horn 44100 0))))

(: _ (say out "hornseat: ok") (putc 10))
