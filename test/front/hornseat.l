; test/front/hornseat.l -- the horn's seat door, and the ring a card pulls it through.
; runs under out/frontseat (test/front/main.c, -D love_horn_seat=1): horn.c asks k_horn_* for the
; device, the lane inle and the playdate run. the device is hornring.h's ring; (tapped ()) drains it
; as a card would; 1024 frames against writes of a few hundred, so every law rides a real push, pull
; and wrap. horn_land widens mono to stereo for a device, never for the sink (test/front/horn.l)

(: (ramp n) (string (map (i \ i % 251) (jot n))))

; --- a stereo port goes down as it is ---
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

; --- ..and a mono one is doubled before it arrives ---
; the port still calls itself mono; each sample lands on both channels (horn.l's sink lane inverts this)
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

; --- the ring wraps, and nothing is lost or reordered across it ---
; 1024 frames deep: eight rounds of 400 carry the free-running indices past the end three times,
; where a ring masking its indices in place, or comparing them wrongly at the seam, loses a frame
(: h (horn 44100 2)
   _ (assert !(nom? h))
   (round i) (: pcm (ramp (1600 + (4 * i)))      ; a different whole-frame length each time
                _ (say h pcm)
                _ (flush h)
                got (tapped ())
                (assert (pcm = got)))
   ; `map`, not a `&&` fold: assert answers falsy when it passes, so the fold would stop after round 0
   (map round (jot 8)))

; --- a starved ring answers silence, not the last frame ---
; (tapped ()) lays only the real frames, so it can't see a card holding its last frame; (starved n)
; pulls into dirty buffers as a card hands them and counts what came back loud
(horn 44100 2 @ h
 (assert (0 = horn-lag h),
  assert ("" = tapped ()),
  assert (0 = starved 64),
  ; ..and the control, so the 0 above is the ring being silent and not `starved` blind
  say h (ramp 400),
  flush h,
  assert (0 < (starved 64)),
  tapped ()))                                   ; drained again, for the law below

; --- the lag is the device's number, not a clock's ---
; the sink reckons its lag from love_clock and drifts; a seat answers k_horn_lag, what the ring holds
(horn 44100 2 @ h
 (say h (ramp 400),                             ; 100 frames
  flush h,
  assert (100 = horn-lag h),
  say h (ramp 400),
  flush h,
  assert (200 = horn-lag h),                  ; ..and it accumulates until something pulls
  tapped (),
  assert (0 = horn-lag h)))

; --- a port opened on the seat takes it from the ports before ---
; a dropped port's finalizer close must not shut the device the newer port holds;
; a major here runs it, between the say and the read
(: (dropped _) (: h (horn 44100 2) _ (say h (ramp 400)) _ (flush h) 0)
   _ (dropped 0)
   h (horn 44100 2) _ (say h (ramp 400)) _ (flush h)
   _ (please 1) _ (please 1)
   (assert (100 = horn-lag h),
    tapped ()))

; --- misuse is the port's, not the door's ---
(assert (nom? (horn 10 2)),
 assert (nom? (horn 44100 3)),
 assert (nom? (horn 44100 0)))

(say out "hornseat: ok", putc 10)
