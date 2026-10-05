; test/host/ogg.l -- src/apps/ogg.l: pages, packets, ogg flac through the decoder door.
; a stream laid here page by page around a small flac, decoded to its samples; every byte of
; it flipped, which answers why or samples and never falls over; then, where the reference
; tools are, `flac --ogg` streams of every shape held to flac -d byte for byte, a chain, a
; multiplex, a stream entered mid-way and one damaged.
;   cat test/00-init.l test/host/ogg.l | out/love
(borrow 'posix)
(borrow 'flac)
(borrow 'ogg)
(borrow 'av)
(: dir (cwd 0 + "/out/.oggd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (og-rd p) (: q (open p "r") s (slurp q) (close q, s))
   (og-nib c) (? (c < 58) (c - 48) (c - 87))
   (og-unx h) (cask (#h // 2) @ c (map (i \ pin c i (og-nib (h (2 * i)) * 16 + og-nib (h (2 * i + 1)))) (jot (#h // 2)),
                                   string c))
   (og-le v n) (string (map (k \ (v >> (8 * k)) & 255) ^n))
   ; libFLAC's three-frame stream test/host/flac.l holds to its samples
   tiny (og-unx (cats [
     "664c6143000000220020002000006a00006a01f402f000000060c77d5c95d11ac172f2c14037fdd400cc840000362000"
     "00007265666572656e6365206c6962464c414320312e352e30203230323530323131010000000a0000005449544c453d"
     "74696e79fff86418001f1c1800001a0430f4421b0215a7688f11e7896ae546366a4ba644c92bcabef46539e501ca2204"
     "99f4603dd2ec0a6e8c0000406c702e82fec45f0d474027fb433c8cf37724a69cec9ba29cdd24e9febb92eba420db89d8"
     "bb0ad9f12c0dfa9c9128ce000185fff86418011f0918b35ab984c804dd220218bfed06ec95358448913fccf21158b4a2"
     "6d6bf64bdfb6b513b4d6108679fe244449ac44dadccd46d03b6227b83009498f70b50bd08c16260948f2fe5e33217f4e"
     "30a50b188615a5e15bfb28c79d977545cc400490ec008c7cfff86418021f3618f660dd22c804b9840218b7ec9190d6f5"
     "37c0cbbdcc03e849888394a067a53d15f5e524a44dd35276718e52d4308cc86f8e38bdf68005700b0ab4643f25eb6ff4"
     "5a80ad842a2613897829eea5e411262b9efc39689e8fe84cc7684008d2976f9e09ae"]))
   tm (flac-meta tiny)
   ; its frames, cut at their ends
   tfr (: (go o acc) (? (o >= #tiny) (rev acc)
                        (flac-frame tiny o 16 2 @ (_ . nx) (go nx (snip tiny o nx . acc))))
         (go (tm 'at) ()))
   ; a page laid around whole packets
   (og-page ty gr sn sq ps)
    (: ls (cats (map (p \ string (map (_ \ 255) ^(#p // 255)) + string [(#p % 255)]) ps))
       pg ("OggS" + string [0 ty] + og-le gr 8 + og-le sn 4 + og-le sq 4 + og-le 0 4 + string [#ls] + ls + cats ps)
       (snip pg 0 22 + og-le (ogg-crc pg 0 #pg) 4 + snip pg 26 #pg))
   ; ogg flac: the mapping's first packet with STREAMINFO, the tags, then the frames
   h1 ("\x7fFLAC" + string [1 0 0 1] + "fLaC" + snip tiny 4 42)
   h2 (snip tiny 42 (tm 'at))
   toga (cats [(og-page 2 0 7 0 [h1]) (og-page 0 0 7 1 [h2]) (og-page 4 96 7 2 tfr)])
   ; a stream decoded from o on through ogg-pump -> [r samples]
   (og-pump s m) (: p (dir + "/p") _ (open p "w" @ q (say q s, close q))
                    q (open p "r") b {'l ()} r (ogg-pump q "" m (pcm \ pin b 'l (pcm . b 'l)))
                    (close q, [r (cats (rev (b 'l)))]))
   want "a89c5bcfe11d42b7b4dfbde0865931ab1a0c9460972c15c79ca445ce5f5eee30"
   om (ogg-meta toga)
   _ (test (ogg-sniff toga = 1) (ogg-sniff "Ogg" = 'more) (ogg-sniff tiny = 0)
           (ogg-page toga 0 @ [ty gr sn sq ls b e] (ty = 2 && sn = 7 && ls = [#h1] && e = 28 + #h1) _ 0)
           (ogg-cut "abcdef" 0 [2 0 3] = [["ab" "" "cde"] ()])
           (ogg-page (snip toga 0 30) 0 = 'more)
           (ogg-page ("Oggs" + snip toga 4 #toga) 0 = "lost sync")
           (ogg-page (snip toga 0 30 + "x" + snip toga 31 #toga) 0 = "a bad page (its crc)")
           (tablet? om) (om 'ogg = "flac") (om 'serial = 7) (om 'rate = 8000) (om 'ch = 2)
           (om 'tags = ["TITLE=tiny"]) (om 'skip = 1) (om 'at = 28 + #h1)
           (ogg-format om 'align = 4)
           (og-pump (snip toga (om 'at) #toga) om @ [r pcm] (r = 0 && sha256 pcm = want))
           (ogg-meta "OggT" = "not an Ogg stream") (ogg-meta (snip toga 0 40) = 'more)
           (ogg-meta (og-page 2 0 1 0 ["\x01vorbiz"]) = 'more)
           (ogg-meta (og-page 0 0 1 0 ["x"]) = "an ogg stream with no codec this reads"))
   ; the headers and the first frame on one page: the pump passes the headers over there
   toga2 (cats [(og-page 2 0 9 0 [h1]) (og-page 4 96 9 1 ([h2] + tfr))])
   om2 (ogg-meta toga2)
   _ (test (om2 'skip = 1) (om2 'at = 28 + #h1)
           (og-pump (snip toga2 (om2 'at) #toga2) om2 @ [r pcm] (r = 0 && sha256 pcm = want)))
   ; a flipped byte anywhere answers why or samples, and never takes the process down
   (og-flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   _ (test (atom? (filter (i \ !(ogg-meta (og-flip toga i) @ m2
                                  (? (tablet? m2) (og-pump (snip (og-flip toga i) (m2 'at) #toga) m2 @ [r _] (r = 0 || string? r))
                                     (string? m2 || m2 = 'more))))
                          (jot #toga))))

   ; -- against the reference ------------------------------------------------------------
   ref? (all (t \ <(hark ["sh" "-c" ("command -v " + t + " >/dev/null")]) = 0) ["flac" "ffmpeg"])
   (sh c) (hark ["sh" "-c" ("cd " + dir + " && " + c)])
   ; a file through the door -> [codec r samples]
   (og-dec p)
    (: q (open (dir + "/" + p) "r") b {'l ()}
       r (av-open q @ [n m h] ((<(filter (c \ <c = n) (av-codecs ()))) 4 q h m (pcm \ pin b 'l (pcm . b 'l)) @ x [n x]) w w)
       (close q, string? r ? [r] (r + [(cats (rev (b 'l)))])))
   (og-raw f) ("flac -s -d -f --force-raw-format --endian=little --sign=signed " + f + ".oga -o " + f + ".raw")
   cases [["1" "8" "-0"] ["2" "16" "-5"] ["2" "24" "-8"] ["6" "16" "-5"] ["2" "16" "-8 -b 4608"]
          ["2" "32" "-5"] ["8" "16" "-1"]]
   (mk i [ch bps opt])
    (: f ("c" + show i)
       (sh ("ffmpeg -loglevel error -y -f lavfi -i 'aevalsrc=0.8*sin(440*2*PI*t)+0.05*random(0):s=44100:d=0.7' -ac " + ch
            + (bps = "8" ? " -f s8 -c:a pcm_s8 " (" -f s" + bps + "le -c:a pcm_s" + bps + "le ")) + f + ".in"
            + " && flac -s -f --ogg --serial-number=" + show (i + 100) + " -T TITLE=" + f + " --force-raw-format --endian=little --sign=signed"
            + " --channels=" + ch + " --bps=" + bps + " --sample-rate=44100 " + opt + " " + f + ".in -o " + f + ".oga"
            + " && " + og-raw f) @ (0 . _) f _ ()))
   (same f) (og-dec (f + ".oga") @ ["ogg" 0 pcm] (pcm = og-rd (dir + "/" + f + ".raw")) _ 0)
   _ (ref? ? (: fs (map (i \ mk i (cases i)) ^#cases)
                (test (all string? fs) (all same fs)
                      ; a chain: one stream after another, the second with its own serial
                      (sh "cat c1.oga c4.oga > ch.oga && cat c1.raw c4.raw > ch.raw" = (0 . ""))
                      (same "ch")
                      ; each link's tags reach the caller's m, its link counted
                      (: q (open (dir + "/ch.oga") "r")
                         r (av-open q @ [n m h] (: x ((<(filter (c \ <c = n) (av-codecs ()))) 4 q h m (_ \ 0))
                                                   [x (m 'link) (elem "TITLE=c4" (m 'tags))]) w w)
                         (close q, r = [0 1 1]))
                      ; a chain whose format changes stops there
                      (sh "cat c1.oga c2.oga > cx.oga" = (0 . ""))
                      (og-dec "cx.oga" @ ["ogg" "a chained stream changes its format" _] 1 _ 0)
                      ; two streams on one line: the first is played, the other passed over
                      (sh "ffmpeg -loglevel error -y -i c1.oga -i c3.oga -map 0 -map 1 -c copy mx.oga && cp c1.raw mx.raw"
                         = (0 . ""))
                      (same "mx")
                      ; entered mid-way, the pump finds the next page and plays on from there
                      (og-dec "c1.oga" @ [_ _ all1]
                        (: s (og-rd (dir + "/c1.oga")) m (ogg-meta s)
                           (og-pump (snip s (#s // 2) #s) m @ [r pcm]
                             (r = 0 && 0 < #pcm && pcm = snip all1 (#all1 - #pcm) #all1))))
                      ; a damaged page is passed over, the rest played
                      (: s (og-rd (dir + "/c1.oga")) m (ogg-meta s) k (#s // 3)
                         (og-pump (snip s (m 'at) k + string [(255 - s k)] + snip s (k + 1) #s) m @ [r pcm]
                           (r = 0 && 0 < #pcm)))
                      ; av plays it through the horn
                      (sh "HORN=none ../love -e '(borrow (quote posix)) (borrow (quote av)) (puts (show (av-play (open \"c1.oga\" \"r\")))) (quit 0)' 2>&1"
                         = (0 . "0"))))
        (gate-partly "ogg: no flac or ffmpeg, the reference streams skipped"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "ogg: ok", putc 10, 0)
