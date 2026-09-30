; test/front/hornseat.l -- the horn's seat door, and the ring a card pulls it through.
; runs under out/frontseat (test/front/main.c with -D ai_horn_seat=1), where
; src/love/horn.c asks k_horn_* for the device: the lane inle and the playdate run, which
; no other gate reaches. the frontend's device is src/love/hornring.h's ring; (tapped ())
; drains it as a card would, and at 1024 frames against writes of a few hundred every law
; rides a real push, pull and wrap. horn_land widens a mono port to stereo for a device,
; never for the sink: test/front/horn.l taps a mono port as mono, this sees it as stereo.

(: (ramp n) (string (map (i \ i % 251) (jot n))))

; --- a stereo port goes down as it is -------------------------------------------
(: h (horn 44100 2)
   _ (assert !(nom? h))
   pcm (ramp 1600)                              ; 400 stereo frames, inside the ring
   _ (say h pcm)
   _ (flush h)
   _ (assert (400 = horn-lag h))              ; the ring's fill, before anything pulls
   got (tapped ())                              ; ..and the pull that empties it
   (assert (pcm = got),
    assert (0 = horn-lag h),                  ; drained
    assert (44100 = taprate ()),
    assert (2 = tapchans ())))

; --- ..and a mono one is doubled before it arrives -------------------------------
; the port still calls itself mono; what reached the device is twice the bytes, each
; sample said on both channels. this is the law test/front/horn.l's sink lane inverts.
(: h (horn 44100 1)
   _ (assert !(nom? h))
   pcm (ramp 800)                               ; 400 mono frames
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   (assert (1600 = #got),                ; ..400 stereo frames
    assert (2 = tapchans ()),
    ; frame i is mono sample i twice: bytes 2i,2i+1 landing at 4i..4i+3
    (assert (foldl (a \ i \ a && ((got (4 * i) = pcm (2 * i)) && ((got ((4 * i) + 1) = pcm ((2 * i) + 1)) && ((got ((4 * i) + 2) = pcm (2 * i)) && (got ((4 * i) + 3) = pcm ((2 * i) + 1))))))
                   1 (jot 400)))))

; --- the ring wraps, and nothing is lost or reordered across it ------------------
; 1024 frames deep, so eight rounds of 400 carry the free-running indices past the end
; three times over. a ring that masked its indices in place, or compared them wrongly at
; the seam, loses a frame exactly here and nowhere in the laws above.
(: h (horn 44100 2)
   _ (assert !(nom? h))
   (round i) (: pcm (ramp (1600 + (4 * i)))      ; a different whole-frame length each time
                _ (say h pcm)
                _ (flush h)
                got (tapped ())
                (assert (pcm = got)))
   ; `map`, not a `&&` fold: assert answers falsy when it passes, so a fold over && stops
   ; after round 0 and the seven rounds that cross the seam never run at all. that
   ; spelling passed a ring provably losing a frame from round 1 on.
   (map round (jot 8)))

; --- a starved ring answers silence, not the last frame --------------------------
; nothing has been written since the drain above, so a pull finds nothing. (tapped ())
; laying nothing back says only that -- it lays the frames that were real, so a card
; holding its last frame instead of zeroing reads the same from there. (starved n) is
; the other half: it pulls into buffers a card would have handed in, dirty, and counts
; what came back loud. holding the last frame rings a tone under a stall.
(horn 44100 2 @ h
 (assert (0 = horn-lag h),
  assert ("" = tapped ()),
  assert (0 = starved 64),
  ; ..and the control, so the 0 above is the ring being silent and not `starved` blind
  say h (ramp 400),
  flush h,
  assert (0 < (starved 64)),
  tapped ()))                                   ; drained again, for the law below

; --- the lag is the device's number, not a clock's --------------------------------
; the sink reckons what is played from ai_clock at the nominal rate, so its lag drifts
; with the wall. a seat answers k_horn_lag, which is what the ring actually holds --
; exact, and the number backpressure is owed.
(horn 44100 2 @ h
 (say h (ramp 400),                             ; 100 frames
  flush h,
  assert (100 = horn-lag h),
  say h (ramp 400),
  flush h,
  assert (200 = horn-lag h),                  ; ..and it accumulates until something pulls
  tapped (),
  assert (0 = horn-lag h)))

; --- misuse is the port's, not the door's ----------------------------------------
(assert (nom? (horn 10 2)),
 assert (nom? (horn 44100 3)),
 assert (nom? (horn 44100 0)))

(say out "hornseat: ok", putc 10)
