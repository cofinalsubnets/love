; test/host/opus.l -- src/love/lib/opus.c and ogg.l's opus. the rfc 8251 test vectors (make
; dl/opus-vectors) decoded at 48 kHz: stereo held to their reference decode by 11172-4's full
; accuracy on s16 (every sample within two steps, the rms under 1/sqrt 12 of one), mono 60 dB
; clear of its downmix, and the head's output gain scaling each sample. then, where ffmpeg is, libopus streams through the door: lengths
; ffmpeg's to the sample (pre-skip off the front, the end page's granule off the back), a
; chain's second title, and flipped bytes that never fall over.
;   cat test/00-init.l test/host/opus.l | out/love
(borrow 'posix)
(borrow 'ogg)
(borrow 'av)
(: dir (cwd 0 + "/out/.opusd")
   peepv (cite (quote guts) (quote peepv))
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (op-rd p) (: q (open p "r") (? (hot? q) (: s (slurp q) (close q, s)) ""))
   (op-be s i) (foldl (\ a j (a * 256 + s (i + j))) 0 ^4)
   ; a vector's packets (each a length, a range word, the bytes) on a fresh decoder of ch
   ; channels at gain g (dB in Q7.8) -> its samples, s16 | why
   (op-vec s ch g)
    (: st (cask (opus-state ch)) r (opus-init st ch g)
       (go i acc) (? (i + 8 > #s) (cats (rev acc))
                     (: k (op-be s i) (opus-packet st (snip s (i + 8) (i + 8 + k)) 0 @ x
                                         (go (i + 8 + k) (string? x ? (x . acc) acc)))))
       (r = 0 ? (go 0 ()) r))
   (op-cask s) (: c (cask #s) (pour c 0 s 0 #s, c))
   (op-sg t) (t - 65536 * (t >= 32768))
   (op-s16 s) (op-sg (peepv (op-cask s) 0 2 2 (#s // 2)))
   (op-full a b) (? (#a != #b || #a < 2) 0
                    (: d (op-s16 a - op-s16 b) (net (d * d) / (#a // 2) < 1 / 12 && aall (d <= 2) && aall (d >= -2))))
   ; mono against the stereo reference's mean of its two channels
   (op-mono a b) (? (2 * #a != #b || #a < 2) 0
                    (: c (op-cask b) n (#b // 4)
                       m ((op-sg (peepv c 0 2 4 n) + op-sg (peepv c 2 2 4 n)) / 2)
                       d (op-s16 a - m)
                       (net (m * m) > 1000000 * net (d * d))))
   vd (getenv "DL" @ d (string? d ? (d + "/opus-vectors") ""))
   vs (map (i \ (i < 9 ? "0" "") + show (i + 1)) ^12)
   (op-vecs v) (: b (op-rd (vd + "/testvector" + v + ".bit")) r (op-rd (vd + "/testvector" + v + ".dec"))
                  (op-full (op-vec b 2 0) r && op-mono (op-vec b 1 0) r))
   ; -6 dB of output gain (-1536 in Q7.8) is every sample times 10^(-6/20), to the step
   (op-half a b) (#a = #b && 2 < #a && (: d (op-s16 b - op-s16 a * 0.5011872336272722) (aall (d <= 1) && aall (d >= -1))))
   _ (test (opus-state 2 > opus-state 1) (opus-state 3 = ()) (opus-init (cask 10) 2 0 = 1)
           (opus-init (cask (opus-state 2)) 2 0 = 0) (opus-init (cask (opus-state 2)) 2 32768 = 1))
   _ (? (0 < #(op-rd (vd + "/testvector01.bit")))
         (test (all op-vecs vs)
               (: b (op-rd (vd + "/testvector01.bit")) (op-half (op-vec b 2 0) (op-vec b 2 -1536))))
        (gate-partly "opus: no dl/opus-vectors (make dl/opus-vectors), the rfc's test vectors skipped"))

   ; -- libopus's streams through the door -------------------------------------------------
   ref? (<(hark ["sh" "-c" "command -v ffmpeg >/dev/null"]) = 0)
   (sh c) (hark ["sh" "-c" ("cd " + dir + " && " + c)])
   tone "0.5*sin(440*2*PI*t)*lt(mod(t\\,0.25)\\,0.02)+0.2*random(0)*lt(mod(t\\,0.5)\\,0.01)+0.3*sin(3000*2*PI*t)|0.4*sin(660*2*PI*t)+0.2*random(1)"
   cases [["48000" "2" "128k" "audio"] ["44100" "2" "64k" "audio"] ["48000" "1" "16k" "voip"] ["16000" "1" "12k" "voip"]
          ["48000" "2" "32k" "lowdelay"] ["24000" "2" "24k" "audio"] ["48000" "2" "6k" "voip"]]
   (mk i [r ch b app])
    (: f ("o" + show i)
       (sh ("ffmpeg -nostdin -loglevel error -y -f lavfi -i 'aevalsrc=" + tone + ":s=" + r + ":d=1.3' -ac " + ch
            + " -c:a libopus -b:a " + b + " -application " + app + " -metadata title=" + f + " " + f + ".opus"
            + " && ffmpeg -nostdin -loglevel error -y -c:a libopus -i " + f + ".opus -f s16le " + f + ".ff")
          @ (0 . _) f _ ()))
   ; a file through the door -> [codec r samples]
   (op-dec p)
    (: q (open (dir + "/" + p) "r") b {'l ()}
       r (av-open q @ [n m h] ((<(filter (c \ <c = n) (av-codecs ()))) 4 q h m (pcm \ pin b 'l (pcm . b 'l)) @ x [n x]) w w)
       (close q, string? r ? [r] (r + [(cats (rev (b 'l)))])))
   (same f) (op-dec (f + ".opus") @ ["ogg" 0 pcm] (#pcm = #(op-rd (dir + "/" + f + ".ff")) && 0 < #pcm) _ 0)
   _ (ref? ? (: fs (map (i \ mk i (cases i)) ^#cases)
                (test (all string? fs) (all same fs)
                      ; a radio's chain of songs: the second's title reaches m, and both play whole
                      (sh "cat o0.opus o4.opus > och.opus && cat o0.ff o4.ff > och.ff" = (0 . ""))
                      (same "och")
                      (: q (open (dir + "/och.opus") "r")
                         r (av-open q @ [n m h] (: x ((<(filter (c \ <c = n) (av-codecs ()))) 4 q h m (_ \ 0))
                                                   [x (m 'link) (elem "TITLE=o4" (m 'tags))]) w w)
                         (close q, r = [0 1 1]))
                      ; the head's output gain reaches the samples: o0 re-headed at -6 dB
                      (: s (op-rd (dir + "/o0.opus")) c (op-cask s) h (27 + s 26) e (h + net (map (i \ s (27 + i)) ^(s 26)))
                         _ (pin c (h + 16) 0, pin c (h + 17) 250)   ; -1536 = 0xfa00, little-endian
                         k (ogg-crc (string c) 0 e)
                         _ (map (j \ pin c (22 + j) ((k // (256 ** j)) % 256)) ^4)
                         _ (open (dir + "/half.opus") "w" @ q (say q (string c), close q))
                         (op-dec "o0.opus" @ [_ 0 a] (op-dec "half.opus" @ [_ 0 b] (op-half a b) _ 0) _ 0))
                      ; a flipped byte anywhere answers why or samples, and never falls over
                      (: s (op-rd (dir + "/o3.opus"))
                         (all (i \ (: c (op-cask s)
                                      _ (pin c i (255 - s i), open (dir + "/flip") "w" @ q (say q (string c), close q))
                                      (op-dec "flip" @ [r] (string? r) [_ r _] (r = 0 || string? r) _ 0)))
                              (map (k \ k * 7) ^(#s // 7))))))
        (gate-partly "opus: no ffmpeg, libopus's streams skipped"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "opus: ok", putc 10, 0)
