; test/kernel/horn.l -- the samples really leave the machine. a boot line names this file and
; the terminal takes what is played (inle.mjs --horn, which is the page's AudioWorklet with
; a file where the speaker is); test/gate/horn.l reads that file back. a ramp rather than a
; tone, so a wrap taken at the wrong index is not a plausible answer on the far side.
; 20000 stereo frames is more than the worker's ring holds, so the run wraps it and parks
; the writer on a full device on the way -- which is the shape being asked about, not the
; length. the wait is the drainer's: it takes them at the rate, so the run is its 417 ms.
(: n 80000
   pcm (string (map (\ i (i % 251)) (jot n)))
   h (horn 48000 2)
   (? (nom? h) (puts $ "horn " + show h + "\n")
      (: _ (say h pcm)
         _ (flush h)
         _ (rest 1200)
         _ (close h)
         (puts $ "horn wrote " + show n + "\n"))))
