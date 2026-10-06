; test/host/aplay.l -- src/apps/wav.l: the RIFF walk, every format down to s16, and the aplay
; verb. wavs built here with known samples; then, where ffmpeg is, a signal in every format
; held to ffmpeg's own s16 byte for byte; then the refusals; last the verb into HORN=none.
;   cat test/00-init.l test/host/aplay.l | out/love
(borrow 'posix)
(borrow "src/apps/wav.l")
(borrow 'bytes)
(: dir (cwd 0 + "/out/.aplayd")
   ; a meta that wants more: 'more, or how much and where
   (ap-more? x) (x = 'more || (two? x && <x = 'more))
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   (ap-fmt tag ch rate bits w) (join "" [(wrle tag 2) (wrle ch 2) (wrle rate 4) (wrle (rate * ch * w) 4)
                                        (wrle (ch * w) 2) (wrle bits 2)])
   (ap-wav fmt data) (join "" ["RIFF" (wrle (20 + #fmt + #data) 4) "WAVE" "fmt " (wrle #fmt 4) fmt
                              "data" (wrle #data 4) data])
   ; the s16 a whole wav decodes to, as signed numbers
   (ap-s16 s) (: c (cask #s) _ (pour c 0 s 0 #s)
                 (map (i \ (s (2 * i) + 256 * s (2 * i + 1)) @ v (v < 32768 ? v (v - 65536))) ^(#s // 2)))
   (ap-dec s) (wav-head s @ h (? !(tablet? h) h
                 (: n ((#s - h 'at) // h 'align) c (cask (n * h 'align))
                    (pour c 0 s (h 'at) #c, ap-s16 (string (wav-pcm h n c))))))
   (ap-mono tag bits w samples) (ap-dec (ap-wav (ap-fmt tag 1 8000 bits w)
                                                (join "" (map (v \ wrle v w) samples))))
   ; -- known samples ------------------------------------------------------------------
   _ (test (ap-mono 1 8 1 [0 128 255] = [-32768 0 32512])
           (ap-mono 1 16 2 [65535 32767 32768] = [-1 32767 -32768])
           (ap-mono 1 24 3 [8388607 8388608 16777215 256] = [32767 -32768 -1 1])
           (ap-mono 1 32 4 [65536 4294967295 2147483648] = [1 -1 -32768])
           ; 0.5 -1.0 1.5(clips) 2^-16 1.5*2^-15 -1.25*2^-14: ties go to even
           (ap-mono 3 32 4 [1056964608 3212836864 1069547520 931135488 943718400 3097493504]
              = [16384 -32768 32767 0 2 -2])
           ; 0.25 -0.75, each as its low and high words
           (ap-dec (ap-wav (ap-fmt 3 1 8000 64 8) (join "" (map (v \ wrle 0 4 + wrle v 4) [1070596096 3219652608])))
              = [8192 -24576])
           (ap-mono 7 8 1 [255 0 128] = [0 -32124 32124])
           (ap-mono 6 8 1 [213 85 42] = [8 -8 -32256])
           ; three channels play as their first two; mono stays mono
           (ap-dec (ap-wav (ap-fmt 1 3 8000 16 2) (join "" (map (v \ wrle v 2) [1 2 3 4 5 6]))) = [1 2 4 5])
           ; WAVE_FORMAT_EXTENSIBLE answers to its subformat
           (wav-head (ap-wav (ap-fmt 65534 2 48000 32 4 + wrle 22 2 + wrle 32 2 + wrle 3 4 + wrle 3 2
                                     + join "" (map (k \ string [0]) ^14)) "")
              @ h (tablet? h && h 'name = "FLOAT_LE" && h 'ch = 2 && h 'rate = 48000))
           ; a streamed wav's zero length plays to the end
           (wav-head (ap-wav (ap-fmt 1 1 8000 16 2) "") @ h (h 'len = -1))
           (wav-format "s16_le" @ f (f 'w = 2 && f 'big = 0))
           (wav-format "S99" = ())
           (wav-desc (pins (wav-format "U8") 'rate 8000 'ch 6) = "Unsigned 8 bit, Rate 8000 Hz, Channels 6"))

   ; -- against ffmpeg -----------------------------------------------------------------
   ff? (: r (hark ["sh" "-c" "command -v ffmpeg >/dev/null"]) (<r = 0))
   src "aevalsrc=1.3*sin(440*2*PI*t)+0.01*random(0)|0.7*sin(97*2*PI*t)*random(1):s=44100:d=0.05"
   wavs ["u8" "s16le" "s24le" "s32le" "f32le" "f64le" "mulaw" "alaw"]
   raws [["s8" "S8"] ["u16le" "U16_LE"] ["u16be" "U16_BE"] ["s16be" "S16_BE"] ["s24be" "S24_3BE"]
         ["u24le" "U24_3LE"] ["u24be" "U24_3BE"] ["s32be" "S32_BE"] ["u32le" "U32_LE"]
         ["u32be" "U32_BE"] ["f32be" "FLOAT_BE"] ["f64be" "FLOAT64_BE"]]
   (ff args) (<(hark (["ffmpeg" "-loglevel" "error" "-y"] + args)) = 0)
   (p nm x) (dir + "/" + nm + x)
   (ap-ff-wav nm) (ff ["-f" "lavfi" "-i" src "-c:a" ("pcm_" + nm) (p nm ".wav")]
                   && ff ["-i" (p nm ".wav") "-f" "s16le" "-c:a" "pcm_s16le" (p nm ".ref")]
                   && (: s (av-t-rd (p nm ".wav")) h (wav-head s) n ((#s - h 'at) // h 'align) c (cask (n * h 'align))
                         (pour c 0 s (h 'at) #c, string (wav-pcm h n c) = av-t-rd (p nm ".ref"))))
   (ap-ff-raw nm fm) (ff ["-f" "lavfi" "-i" src "-f" nm "-c:a" ("pcm_" + nm) (p nm ".raw")]
                      && ff ["-f" nm "-ar" "44100" "-ac" "2" "-i" (p nm ".raw") "-f" "s16le" "-c:a" "pcm_s16le" (p nm ".ref")]
                      && (: s (av-t-rd (p nm ".raw")) f (pins (wav-format fm) 'ch 2 'rate 44100)
                            _ (pin f 'align (2 * f 'w)) n (#s // f 'align) c (cask (n * f 'align))
                            (pour c 0 s 0 #c, string (wav-pcm f n c) = av-t-rd (p nm ".ref"))))
   _ (ff? ? (test (all ap-ff-wav wavs) (all (x \ ap-ff-raw <x <>x) raws))
        (gate-partly "aplay: no ffmpeg, its formats skipped"))

   ; -- the refusals --------------------------------------------------------------------
   _ (test (wav-head (ap-wav (ap-fmt 85 1 8000 16 2) "") = "can't play WAVE-file format 0x0055 which is not PCM or FLOAT encoded")
           (wav-head (ap-wav (ap-fmt 1 1 8000 12 2) "") = "can't play WAVE-files with sample 12 bits wide")
           (wav-head (join "" ["RIFF" (wrle 12 4) "WAVE" "data" (wrle 0 4)]) = "a WAVE-file with no fmt chunk ahead of its data")
           (ap-more? (wav-head (snip (ap-wav (ap-fmt 1 1 8000 16 2) "") 0 30)))
           (wav-head "hello, not a riff" = 'raw))
   ; a size field past the head's cap is refused at once, nothing read toward it
   _ (open (dir + "/huge.wav") "w" @ q (say q (join "" ["RIFF" (wrle 36 4) "WAVE" "fmt " (wrle 2147483632 4)]), close q))
   _ (test ((cite 'av 'av-open) (open (dir + "/huge.wav") "r") = "the head of this stream is past 16 MiB"))

   ; -- the verb ------------------------------------------------------------------------
   (run cmd) (hark ["sh" "-c" ("cd " + dir + " && HORN=none ../love aplay " + cmd + " 2>&1")])
   _ (put (dir + "/a.wav") (ap-wav (ap-fmt 1 2 8000 16 2) (join "" (map (v \ wrle v 4) ^80))))
   _ (put (dir + "/z.raw") (join "" (map (k \ string [0]) ^400)))
   _ (test (run "a.wav" = (0 . "Playing WAVE 'a.wav' : Signed 16 bit Little Endian, Rate 8000 Hz, Stereo\n"))
           (run "-q a.wav z.raw" = (0 . ""))
           (run "< a.wav" = (0 . "Playing WAVE 'stdin' : Signed 16 bit Little Endian, Rate 8000 Hz, Stereo\n"))
           (run "-f cd -s 10 z.raw" = (0 . "Playing raw data 'z.raw' : Signed 16 bit Little Endian, Rate 44100 Hz, Stereo\n"))
           (run "-t raw -c 3 --format=mu_law z.raw" = (0 . "Playing raw data 'z.raw' : Mu-Law, Rate 8000 Hz, Channels 3\n"))
           (run "-t wav z.raw" = (1 . "aplay: z.raw: not a WAVE-file\n"))
           (run "-fXX z.raw" = (1 . "aplay: wrong extended format 'XX'\n"))
           (run "-r 4000 z.raw" = (1 . "aplay: rate 4000 Hz is outside the horn's 8000..192000\n"))
           (run "nope.wav a.wav" = (1 . "nope.wav: No such file or directory\nPlaying WAVE 'a.wav' : Signed 16 bit Little Endian, Rate 8000 Hz, Stereo\n"))
           (run "--bogus" = (1 . "aplay: unrecognized option '--bogus'\n"))
           (run "-c 300 z.raw" = (1 . "aplay: value 300 for channels is invalid\n")))
   ; the last gulp plays too, so a wav read whole at once is half a second of HORN=none's time
   _ (put (dir + "/half.wav") (ap-wav (ap-fmt 1 1 8000 8 1) (join "" (map (k \ string [128]) ^4000))))
   t0 (clock 0)
   _ (test (run "-q half.wav" = (0 . "")) (400 <= clock 0 - t0),
    hark ["rm" "-rf" dir],
    0))

(test_fin (), puts "aplay: ok", putc 10, 0)
