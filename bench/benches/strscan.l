; strscan: fold a polynomial rolling hash over a fixed 20000-char string built once, outside the
; timed loop -- the read counterpart to strcat. printable bytes 32 + 7i mod 95, realized with one
; `string` call. the hash stays < 2^31, so every language agrees on the checksum.
(: hmod 1000000007
   (strhash s) (: n #s
     (go i h) (i < n ? (go (i + 1) ((h * 31 + peep s i 0) % hmod)) h) (go 0 0))
   (mkdata n) (string ((: (go i) (i < n ? (32 + 7 * i % 95 . go (i + 1)))) 0))
   data (mkdata 20000)
 (bench "strscan" (_ \ strhash data)))
