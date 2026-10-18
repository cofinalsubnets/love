; the horn's sink, under test/front/main.c with HORN=none: the frontend defines
; love_horn_tap and keeps what the sink took. (tapped ()) answers it as text and
; empties the keep; (taprate ()) and (tapchans ()) the rate and channels

; a ramp, so a sample is its own index and a reversed or doubled buffer says so
(: (ramp n) (string (map (i \ i % 251) ^n)))

; --- a stereo port: what goes in is what the sink takes, byte for byte ---
; 400 frames fit the 250 ms ring, so a short answer means the sink refused
(: h (horn 8000 2)
   _ (assert !(nom? h))
   pcm (ramp 1600)
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   (assert (1600 = #got),
    assert (pcm = got),                        ; ..and in order, which a ring can lose
    assert (8000 = taprate ()),
    assert (2 = tapchans ())))

; --- a mono port taps as MONO ---
; horn_land doubles mono only on the device path; the tap sits above it, so honour tapchans
(: h (horn 8000 1)
   _ (assert !(nom? h))
   pcm (ramp 800)
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   (assert (pcm = got),                        ; the port's own bytes, undoubled
    assert (1 = tapchans ()),                ; ..and its own count
    assert (8000 = taprate ())))

; --- a write past the ring's depth is backpressure, not a dropped frame ---
; twice the ring (2000 frames at 8k): every byte must still arrive, in order
(: h (horn 8000 2)
   _ (assert !(nom? h))
   pcm (ramp 16000)                            ; 4000 frames, the ring twice over
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   (assert (16000 = #got),
    assert (pcm = got)))

; --- a rate outside the range, and a channel count that is neither 1 nor 2 ---
(assert (nom? (horn 10 2)))
(assert (nom? (horn 8000 3)))
(assert (nom? (horn 8000 0)))

(say out "horn: ok\n")
