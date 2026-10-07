; test/host/mp3.l -- src/love/lib/mp3.c's nifs and src/apps/mp3.l. a small stream laid here,
; decoded to its samples; every byte of it flipped, which answers why or samples and never
; falls over; then the iso 11172-4 and 13818-4 layer iii conformance streams (make
; dl/mp3-vectors) held to their reference output by 11172-4's full accuracy, and lame streams
; of every shape held to ffmpeg's and mpg123's decodes the same way, gapless; last the door,
; mpg123's verb, a stream entered mid-way and a second song's tags.
;   cat test/00-init.l test/host/mp3.l | out/love
(borrow 'posix)
(borrow 'mp3)
(borrow 'av)
(borrow 'bytes)
(borrow 'hashes)
(: dir (cwd 0 + "/out/.mp3d")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (mp-nib c) (? (c < 58) (c - 48) (c - 87))
   (mp-unx h) (cask (#h // 2) @ c (map (i \ pin c i (mp-nib (h (2 * i)) * 16 + mp-nib (h (2 * i + 1)))) (jot (#h // 2)),
                                  string c))
   ; lame's 0.3 s of a fading 440 Hz, mpeg 2 at 16 kHz, mono, 16 kbit/s: eleven frames
   tiny (mp-unx (cats [
     "fff328c4000d206aac3f4f18000b16da000af57abd5eaf57b3bf7eac4e218a86b2de26e26e38c841a068218ac6479404"
     "c1f07c1fe18e0ffff7f29e7f94f3fd1efe85749877fffa27fff328c4060dd0b2b0019b78002f1f8ffc64c087cd791840"
     "386c06a17083870501ec3949c866a5f40a055762572ba0ffffffbd7b6b42f82a1206bf129d0695fffffa0674a0505b98"
     "fff328c4090f80724001de4801601a030605a0d4610e04c60f01b6631c7a273486a47f5289c65f260063d0316629c49a"
     "602020660f405660240029dca5d0f3c22605fffffca5ac49fff328c4060d886e4000eff8812240801814120004e60389"
     "c60f156635c30614729f063fe8564602d012a63b021b22226332198f4001c1156275645608aafffffaee429bae12a006"
     "fff328c40a0e987a3000eff88060104061188e625108649a166a95fc639abdf46606086460d682de6dd749d43c86a559"
     "197c320614215ad471dfc8c53e15f9644501a03012080c98fff328c40a0f187e2800a7fa642014b2154c2408a1304066"
     "12200c265ff80706cb400ec614d81ce65ba926197b4638aac60009a2305070015b4f5c4259477baafffffc634c451580"
     "fff328c4080dd86e3800eff881202180008980a12182425986652192504986baa1f992d414b9811e04018a04a6bfa518"
     "98b463a0386039585d68adf8d5fffffc25efc3ccb2846070fff328c40b0c786e3c00e7f6810068c263d31a220d1fa330"
     "d3914731484249302f00b4364623adc5348410528207b3481e594e18c39ff5200620b082a01a0a040300300530150510"
     "fff328c41410287630015e100180d730940c8313238439864233fe5405322f127303d103313f2693028115307d01d030"
     "058880012e2314ee2045104d924fe3f9117f7fe0461ec35afff328c40e0f58caa8c99a900257fa279cb2ce70303ff813"
     "616591326873873b970b88264348290132f4ded2f134625d2efe0d05415fd40d094eff834a4c414d45342e30aaaaaaaa"
     "fff328c40b0000034801c00000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
     "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]))
   ; every frame from 0 on, one state -> the samples, s16 (f 0) or f32 (f 1) | why not. a
   ; last frame cut short is the end, as it is to the pump
   (mp-all s f) (: st (cask (mp3-state 0))
                   (go o acc) (? (o >= #s) (cats (rev acc))
                                 (mp3-frame st s o f @ (pcm . nx) (go nx (pcm . acc)) 2 (cats (rev acc)) w w))
                   (go 0 ()))
   want "816cd0c08947870ba80a1ddfcbd2a349b0e43586fbe13226b7e1be8bbcfee8a9"
   tm (mp3-meta tiny)
   _ (test (mp3-head tiny 0 = (72 | (1 << 12) | (16000 << 16))) (mp3-head "abcd" 0 = 0) (mp3-head tiny 1 = 0)
           (mp-all tiny 0 @ pcm (string? pcm && #pcm = 12672 && sha256 pcm = want) _ 0)
           (mp-all tiny 1 @ pcm (string? pcm && #pcm = 25344) _ 0)
           (mp3-frame (cask (mp3-state 0)) (snip tiny 0 50) 0 0 = 2)
           (mp3-frame (cask (mp3-state 0)) tiny 1 0 = 1)
           (mp3-frame (cask 10) tiny 0 0 = 3)
           (tablet? tm) (tm 'rate = 16000) (tm 'ch = 1) (tm 'at = 0) (tm 'total = 0) (tm 'tags = ())
           (mp3-format tm 'align = 2)
           (mp3-sniff tiny = 1) (mp3-sniff (snip tiny 0 50) = 'more) (mp3-sniff (cats (map (_ \ "noise ") ^1000)) = 0)
           (mp3-meta "ID3" = ['more 10]))
   ; a tag past 1 MiB through the door: its text frames kept, the picture after them left unread
   (mp-ss n) (string (map (k \ (n >> (7 * (3 - k))) & 127) ^4))
   (mp-fr i b) (i + wrbe #b 4 + string [0 0] + b)
   mp-big (: t (mp-fr "TIT2" (string [0] + "Big") + mp-fr "APIC" (string [0] + "image/jpeg" + string [0 3 0] + string (cask 2097152)))
             ("ID3" + string [3 0 0] + mp-ss #t + t))
   _ (open (dir + "/apic.mp3") "w" @ q (say q (mp-big + tiny), close q))
   _ (test ((cite 'av 'av-open) (open (dir + "/apic.mp3") "r") @ [n m h] (n = "mp3" && m 'tags = ["TITLE=Big"]) _ 0))
   ; a flipped byte anywhere answers why or samples, and never takes the process down
   (mp-flip s i) (cask #s @ c (map (k \ pin c k (s k)) (jot #s), pin c i (255 - s i), string c))
   _ (test (atom? (filter (i \ !(mp-all (mp-flip tiny i) 0 @ r (string? r || charm? r))) (jot #tiny))))

   ; -- 11172-4's full accuracy, on s16: rms under 1/sqrt 12 of a step, none more than two ---
   ; the conformance streams: a reference may leave out a last frame, and sin1k0db's leaves
   ; out the first two (whose main data reaches back before the stream: silence here); that
   ; one opens on zeros, so it is decoded from its first frame
   vd (getenv "DL" @ d (string? d ? (d + "/mp3-vectors") ""))
   iso ["l3-compl" "l3-he_32khz" "l3-he_44khz" "l3-he_48khz" "l3-he_free" "l3-he_mode" "l3-hecommon"
        "l3-si" "l3-si_block" "l3-si_huff" "l3-test45" "l3-test46" "M2L3_bitrate_16_all"
        "M2L3_bitrate_22_all" "M2L3_bitrate_24_all" "M2L3_compl24" "M2L3_noise"]
   (mp-iso nm) (: b (av-t-rd (vd + "/" + nm + ".bit")) r (av-t-rd (vd + "/" + nm + ".pcm"))
                  (mp-all b 0 @ pcm (? (string? pcm && #r <= #pcm && #pcm - #r <= 4608) (av-t-full (snip pcm 0 #r) r)) _ 0))
   _ (? (0 < #(av-t-rd (vd + "/l3-compl.bit")))
         (test (all mp-iso iso)
               (: b (av-t-rd (vd + "/l3-sin1k0db.bit")) r (av-t-rd (vd + "/l3-sin1k0db.pcm"))
                  (mp-all (snip b (mp3-meta b 'at) #b) 0 @ pcm (? (string? pcm) (av-t-full (snip pcm 9216 (9216 + #r)) r)) _ 0)))
        (gate-partly "mp3: no dl/mp3-vectors (make dl/mp3-vectors), the conformance streams skipped"))

   ; -- lame's streams against ffmpeg's float decoder and mpg123, gapless ----------------------
   ref? (all (t \ <(hark ["sh" "-c" ("command -v " + t + " >/dev/null")]) = 0) ["ffmpeg" "mpg123"])
   (sh c) (hark ["sh" "-c" ("cd " + dir + " && " + c)])
   cases [["44100" "2" "-b:a 128k"] ["48000" "2" "-b:a 320k"] ["32000" "1" "-b:a 48k"] ["22050" "2" "-b:a 64k"]
          ["24000" "1" "-b:a 32k"] ["16000" "2" "-b:a 24k"] ["11025" "1" "-b:a 16k"] ["12000" "2" "-b:a 16k"]
          ["8000" "1" "-b:a 8k"] ["44100" "2" "-q:a 0"] ["44100" "1" "-q:a 9"]]
   tone "aevalsrc=0.5*sin(440*2*PI*t)*lt(mod(t\\,0.25)\\,0.02)+0.2*random(0)*lt(mod(t\\,0.5)\\,0.01)+0.3*sin(3000*2*PI*t)|0.4*sin(660*2*PI*t)+0.3*random(1)*lt(mod(t\\,0.3)\\,0.005)"
   (mk i [r ch q])
    (: f ("c" + show i)
       (sh ("ffmpeg -nostdin -loglevel error -y -f lavfi -i '" + tone + ":s=" + r + ":d=1.3' -ac " + ch
            + " -c:a libmp3lame " + q + " -metadata title=" + f + " " + f + ".mp3"
            + " && mpg123 -q -s " + f + ".mp3 > " + f + ".m123"
            + " && ffmpeg -nostdin -loglevel error -y -c:a mp3float -i " + f + ".mp3 -f s16le " + f + ".ff"
            + " && ../love mpg123 -s " + f + ".mp3 > " + f + ".love") @ (0 . _) f _ ()))
   (same f) (: a (av-t-rd (dir + "/" + f + ".love"))
               (av-t-full a (av-t-rd (dir + "/" + f + ".m123")) && av-t-full a (av-t-rd (dir + "/" + f + ".ff"))))
   _ (ref? ? (: fs (map (i \ mk i (cases i)) ^#cases)
                (test (all string? fs) (all same fs)
                      ; mpg123's wav: the same header, the same length
                      (sh "mpg123 -q -w m.wav c0.mp3 && ../love mpg123 -w l.wav c0.mp3" = (0 . ""))
                      (av-t-rd (dir + "/m.wav") @ a (av-t-rd (dir + "/l.wav") @ b (snip a 0 44 = snip b 0 44 && #a = #b)))
                      ; with no -w -s or -t it plays, as mpg123 does: HORN=none keeps the 1.3 s
                      (: t0 (clock 0) r (sh "HORN=none ../love mpg123 c0.mp3") (r = (0 . "") && 1000 <= clock 0 - t0))
                      ; the door: its tags, its gapless length, and the horn
                      (sh ("HORN=none ../love -e '(borrow (quote posix)) (borrow (quote av)) (puts (show (av-open (open \"c0.mp3\" \"r\") @ [n m h] [n (m (quote total)) (m (quote tags))] w w))) (puts (show (av-play (open \"c0.mp3\" \"r\")))) (quit 0)' 2>&1")
                         = (0 . "(\"mp3\" 57330 (\"TITLE=c0\"))0"))
                      ; entered mid-way: the pump finds the next frame, and from a few frames on
                      ; plays what the whole stream does
                      (: s (av-t-rd (dir + "/c2.mp3")) m (pins (mp3-meta s) 'skip 0 'total 0) b {'l ()}
                         _ (open (dir + "/mid") "w" @ q (say q (snip s (#s // 2) #s), close q))
                         q (open (dir + "/mid") "r") r (mp3-pump q "" m (pcm \ pin b 'l (pcm . b 'l)))
                         all (mp-all (snip s (m 'at) #s) 0) mid (cats (rev (b 'l)))
                         (close q, r = 0 && 4608 < #mid && snip mid (#mid - 4608) #mid = snip all (#all - 4608) #all))
                      ; a second song at the same rate on the same line: its id3 tags, a link counted
                      (sh "cat c0.mp3 c9.mp3 > two.mp3" = (0 . ""))
                      (: q (open (dir + "/two.mp3") "r")
                         r (av-open q @ [n m h] (: x (mp3-pump q h m (_ \ 0)) [x (m 'link) (m 'tags)]) w w)
                         (close q, r = [0 1 ["TITLE=c9"]]))))
        (gate-partly "mp3: no ffmpeg or mpg123, lame's streams skipped"))
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "mp3: ok", putc 10, 0)
