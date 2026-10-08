; test/kernel/vecirq.l -- an interrupt that lands inside a vector loop keeps the loop's registers.
; one sha256 of 8 MB is a single run of the hardware rounds where the cpu has them (x64's sha
; extensions, armv8's sha2), its state held whole in vector registers; run again until 50 ms of
; it have passed, the 100 Hz timer has fired inside it several times, and every answer is still
; the one the c rounds give. the 64 KB-chunked feed agrees too

(borrow 'hashes)

(: (vi-grow s k) (k = 0 ? s (vi-grow (s + s) (k - 1)))
   vi-seed (: b (cask 65536) (go i) (65536 <= i ? (string b) (pin b i (((i * 2654435761) >> 11) & 255), go (i + 1)))
              (go 0))
   vi-s (vi-grow vi-seed 7)
   vi-want "354533e7bc9b479fe87e893375dd7cbacd2d64adccc73b5b4fa474c2f69cbc4a"
   (vi-chunked s k) (: b (cask 105) n #s
                       _ (sha256-init b)
                       (go i) (n <= i ? (sha256-done b) (sha256-feed b (snip s i (n < i + k ? n (i + k))), go (i + k)))
                       (go 0))
   (vi-runs t0 k) (sha256 vi-s != vi-want ? 0 (clock t0 >= 50 ? k (vi-runs t0 (k + 1))))
 (test
  (#vi-s = 8388608)
  (vi-runs (clock 0) 1 > 0)
  (vi-chunked vi-s 65536 = vi-want)))
