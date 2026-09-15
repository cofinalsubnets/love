; test/front/horn.l -- the horn's sink, and what it takes.
;
; these run under test/front/main.c with HORN=none, so inle/horn.c opens its SINK: the ring
; that keeps time and discards, which is the lane every box without a card runs and the
; only lane a gate can run anywhere. what the sink accepts it hands to ai_horn_tap, and
; the weak default in inle/horn.c takes nothing -- so on an ordinary love the PCM stops
; there and nothing downstream of the port has ever been asserted. the frontend defines
; that hook and keeps what it is given, which is what lets these be laws:
;
;   (tapped ())   what the sink took, as text, and the keep is emptied
;   (taprate ())  the rate, and (tapchans ()) the channels, it took it at
;
; the shape belongs to a seat with a speaker and no card -- a page, a handheld -- and
; this is the one place in the tree where that path is read back rather than played.

; a ramp, so a sample is its own index and a reversed or doubled buffer says so
(: (ramp n) (string (map (\ i (i % 251)) (jot n))))

; --- a stereo port: what goes in is what the sink takes, byte for byte -----------
; 1600 bytes is 400 stereo frames at 8k, well inside the sink's 250 ms ring, so the
; whole write lands in one go and a short answer here means the sink refused.
(: h (horn 8000 2)
   _ (assert (! (nom? h)))
   pcm (ramp 1600)
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   _ (assert (= 1600 (tally got)))
   _ (assert (= pcm got))                      ; ..and in order, which a ring can lose
   _ (assert (= 8000 (taprate ())))
   (assert (= 2 (tapchans ()))))

; --- a mono port taps as MONO, which is the trap for whoever plays the tap --------
; inle/horn.c doubles a 1-channel port to stereo so that the device is always stereo --
; but that is horn_land, on the DEVICE path, and the sink is not a device. the tap sits
; above it, so what arrives is the port's own bytes at the port's own channel count.
; the same 800 bytes are 400 frames here and 200 through a stereo port, and a seat that
; assumed two would play this at half speed. so: honour tapchans, do not assume it.
(: h (horn 8000 1)
   _ (assert (! (nom? h)))
   pcm (ramp 800)
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   _ (assert (= pcm got))                      ; the port's own bytes, undoubled
   _ (assert (= 1 (tapchans ())))              ; ..and its own count, said plainly
   (assert (= 8000 (taprate ()))))

; --- a write past the ring's depth is backpressure, not a dropped frame -----------
; the sink holds a quarter second and no more -- 2000 frames at 8k, 8000 bytes -- so
; this offers twice that and the first pass cannot take it. the port keeps the residue
; and the task parks on the 1 ms poll every heap port has, so the sink drains at the
; rate and the rest lands behind it. every byte arrives, and in order: a horn that
; dropped what would not fit would pass the first law above and fail here.
(: h (horn 8000 2)
   _ (assert (! (nom? h)))
   pcm (ramp 16000)                            ; 4000 frames, the ring twice over
   _ (say h pcm)
   _ (flush h)
   got (tapped ())
   _ (assert (= 16000 (tally got)))
   (assert (= pcm got)))

; --- a rate outside the range, and a channel count that is neither 1 nor 2 --------
(: _ (assert (nom? (horn 10 2)))
   _ (assert (nom? (horn 8000 3)))
   (assert (nom? (horn 8000 0))))

(: _ (say out "horn: ok") (putc 10))
