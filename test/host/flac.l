; test/host/flac.l -- src/apps/flac.l and src/love/lib/flac.c's flac-frame.
; a small stream libFLAC wrote, three frames, decoded to its samples by their sha-256 and its
; md5; every byte of it flipped and decoded, which answers why or samples and never falls
; over; then, where the reference flac is, streams of every shape held to flac -d and
; metaflac --list byte for byte; last the verbs.
;   cat test/00-init.l test/host/flac.l | out/love
(borrow 'posix)
(borrow 'flac)
(: dir (cwd 0 + "/out/.flacd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (nib c) (? (c < 58) (c - 48) (c - 87))
   (unx h) (cask (#h // 2) @ c (map (i \ pin c i (nib (h (2 * i)) * 16 + nib (h (2 * i + 1)))) (jot (#h // 2)),
                               string c))
   tiny (unx (cats [
     "664c6143000000220020002000006a00006a01f402f000000060c77d5c95d11ac172f2c14037fdd400cc840000362000"
     "00007265666572656e6365206c6962464c414320312e352e30203230323530323131010000000a0000005449544c453d"
     "74696e79fff86418001f1c1800001a0430f4421b0215a7688f11e7896ae546366a4ba644c92bcabef46539e501ca2204"
     "99f4603dd2ec0a6e8c0000406c702e82fec45f0d474027fb433c8cf37724a69cec9ba29cdd24e9febb92eba420db89d8"
     "bb0ad9f12c0dfa9c9128ce000185fff86418011f0918b35ab984c804dd220218bfed06ec95358448913fccf21158b4a2"
     "6d6bf64bdfb6b513b4d6108679fe244449ac44dadccd46d03b6227b83009498f70b50bd08c16260948f2fe5e33217f4e"
     "30a50b188615a5e15bfb28c79d977545cc400490ec008c7cfff86418021f3618f660dd22c804b9840218b7ec9190d6f5"
     "37c0cbbdcc03e849888394a067a53d15f5e524a44dd35276718e52d4308cc86f8e38bdf68005700b0ab4643f25eb6ff4"
     "5a80ad842a2613897829eea5e411262b9efc39689e8fe84cc7684008d2976f9e09ae"]))
   ; every frame from o on -> the samples | why not
   (fl-all s o m) (: (go o acc) (? (o >= #s) (cats (rev acc))
                                   (flac-frame s o (m 'bps) (m 'ch) @ (pcm . nx) (go nx (pcm . acc)) w w))
                     (go o ()))
   m (flac-meta tiny)
   _ (test (tablet? m) (m 'rate = 8000) (m 'ch = 2) (m 'bps = 16) (m 'total = 96)
           (m 'minbs = 32) (m 'md5 = "c77d5c95d11ac172f2c14037fdd400cc")
           (m 'vendor = "reference libFLAC 1.5.0 20250211") (m 'tags = ["TITLE=tiny"])
           (map (b \ <b) (m 'blocks) = [0 4])
           (fl-all tiny (m 'at) m @ pcm (string? pcm && #pcm = 384
              && sha256 pcm = "a89c5bcfe11d42b7b4dfbde0865931ab1a0c9460972c15c79ca445ce5f5eee30"
              && md5 pcm = m 'md5))
           ; a frame cut anywhere is cut short; a byte that is no frame is no frame
           (all (n \ flac-frame (snip tiny 0 n) (m 'at) 16 2 = 2) (map (+ (m 'at)) ^20))
           (flac-frame tiny 0 16 2 = 1)
           (flac-frame tiny (m 'at) 24 2 = 4)                   ; the stream says 16 bits
           (flac-meta "not flac" = "not a FLAC file") (flac-meta "fLaC" = 'more)
           (flac-meta (snip tiny 0 50) = 'more))
   ; a seek: entered part way into the first frame, a pump starts at the second
   (fl-seek k) (: p (dir + "/seek") _ (open p "w" @ q (say q (snip tiny (m 'at + k) #tiny), close q))
                  q (open p "r") b {} r (flac-pump q "" m (pcm \ pin b 0 (peep b 0 "" + pcm)))
                  (close q, [r (peep b 0 "")]))
   _ (test (fl-seek 0 = [0 (fl-all tiny (m 'at) m)])
           (fl-seek 1 = [0 (snip (fl-all tiny (m 'at) m) 128 384)])
           (fl-seek 40 = [0 (snip (fl-all tiny (m 'at) m) 128 384)]))
   ; a flipped byte anywhere answers why or samples, and never takes the process down
   (flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   _ (test (atom? (filter (i \ !(flac-meta (flip tiny i) @ m2
                                  (? (tablet? m2) (fl-all (flip tiny i) (m2 'at) m2 @ r (string? r || charm? r))
                                     (string? m2 || m2 = 'more))))
                          (jot #tiny))))

   ; -- against the reference ------------------------------------------------------------
   ref? (all (t \ <(hark ["sh" "-c" ("command -v " + t + " >/dev/null")]) = 0) ["flac" "metaflac" "ffmpeg"])
   (sh c) (hark ["sh" "-c" ("cd " + dir + " && " + c)])
   ; channels, bits, encoder options: fixed and lpc orders, blocksizes, mid/side, wasted bits
   ; flac -d leaves a 32-bit sample signed when asked for unsigned; flac.l flips it as at every
   ; other width, so 32 bits is held to flac signed
   cases [["1" "8" "-0"] ["1" "16" "-8"] ["2" "16" "-5"] ["2" "16" "-8 -b 192 --lax"]
          ["2" "24" "-8 -A 'tukey(0.5)'"] ["2" "32" "-5"] ["6" "16" "-5"] ["2" "16" "-0 -b 4608"]
          ["2" "24" "-3 -b 576"] ["8" "16" "-1"] ["2" "16" "-8 -l 32 -q 15 --lax -b 1024"]]
   (sign bps) (bps = "32" ? "signed" "unsigned")
   (mk i [ch bps opt])
    (: f ("c" + show i)
       (sh ("ffmpeg -loglevel error -y -f lavfi -i 'aevalsrc=0.8*sin(440*2*PI*t)+0.05*random(0):s=44100:d=0.4' -ac " + ch
            + (bps = "8" ? " -f s8 -c:a pcm_s8 " (" -f s" + bps + "le -c:a pcm_s" + bps + "le ")) + f + ".raw"
            + " && flac -s -f --force-raw-format --endian=little --sign=signed --channels=" + ch + " --bps=" + bps
            + " --sample-rate=44100 " + opt + " -T ARTIST=love -T TITLE=" + f + " " + f + ".raw -o " + f + ".flac"
            + " && flac -s -d -f " + f + ".flac -o " + f + ".wav"
            + " && flac -s -d -f --force-raw-format --endian=big --sign=" + sign bps + " " + f + ".flac -o " + f + ".bu"
            + " && metaflac --list " + f + ".flac > " + f + ".list") @ (0 . _) [f (sign bps)] _ ()))
   (same [f sg]) (: a (sh ("../love flac -s -d -c " + f + ".flac"))
                    b (sh ("../love flac -s -dc --force-raw-format --endian=big --sign=" + sg + " - < " + f + ".flac"))
               l (sh ("../love metaflac --list " + f + ".flac"))
               (<a = 0 && >a = rd (dir + "/" + f + ".wav") && <b = 0 && >b = rd (dir + "/" + f + ".bu")
                && <l = 0 && >l = rd (dir + "/" + f + ".list")))
   _ (ref? ? (: fs (map (i \ mk i (cases i)) ^#cases)
                (test (all two? fs) (all same fs)))
        (gate-partly "flac: no flac, metaflac or ffmpeg, the reference streams skipped"))

   ; -- the verbs ------------------------------------------------------------------------
   _ (open (dir + "/t.flac") "w" @ q (say q tiny, close q))
   _ (test (sh "../love flac -d t.flac 2>&1" = (0 . "t.flac: done\n"))
           (sh "../love flac -d t.flac 2>&1" = (1 . "ERROR: output file t.wav already exists, use -f to override\n"))
           (sh "../love flac -t t.flac 2>&1" = (0 . "t.flac: ok\n"))
           (sh "../love flac -s -d -f --force-raw-format t.flac 2>&1"
              = (1 . "ERROR: for decoding to a raw file you must specify --endian and --sign\n"))
           (sh "../love flac t.flac 2>&1" = (1 . "flac: encoding is not built yet; -d decodes and -t tests\n"))
           (sh "../love metaflac --show-sample-rate --show-tag=title t.flac" = (0 . "8000\nTITLE=tiny\n"))
           (sh "../love metaflac --export-tags-to=- t.flac" = (0 . "TITLE=tiny\n"))
           (sh "head -c 300 t.flac | ../love flac -s -t - 2>&1" = (1 . "stdin: ERROR while decoding data: cut short\n")))
   ; -- the decoder door: av picks the codec off the bytes, and plays through the horn ----------
   (av e) (sh ("HORN=none ../love -e '(borrow (quote posix)) (borrow (quote av)) " + e + " (quit 0)' 2>&1"))
   _ (sh "../love flac -s -d -f t.flac")
   _ (test (av "(puts (show (av-open (open \"t.flac\" \"r\") @ [n m h] [n (m (quote rate)) (#h)] w w)))"
              = (0 . "(\"flac\" 8000 318)"))
           (av "(puts (show (av-open (open \"t.wav\" \"r\") @ [n m h] [n (m (quote rate)) (#h)] w w)))"
              = (0 . "(\"wav\" 8000 384)"))
           (av "(puts (show (av-open (open \"t.flac\" \"r\") @ [n m h] [n (m (quote total))] w w)))"
              = (0 . "(\"flac\" 96)"))
           (av "(puts (av-open (open \"/dev/null\" \"r\")))" = (0 . "no codec here reads this stream"))
           (av "(puts (show (av-play (open \"t.flac\" \"r\"))))" = (0 . "0"))
           (av "(puts (show (av-play (open \"t.wav\" \"r\"))))" = (0 . "0")),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "flac: ok", putc 10, 0)
