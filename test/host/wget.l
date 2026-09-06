; --- test/host/wget.l: kore's wget over a real socket, and the tls floor under it ---
; not in the test/*.l corpus: the socket nifs are src/host/sock.c's. kiosko is twirled onto
; a listener over a scratch directory and wget pulls a file back through it -- love
; serving love, test/host/sbhttp.l's shape. the https half is held to the RFC vectors
; the handshake stands on (x25519 from 7748, hmac from 4231): a live peer is
; test/host/wgetnet.l, opt-in, because a gate must not need the internet.
;   cat test/00-init.l test/host/wget.l | out/love
(use 'kiosko)
(use 'tls)

(: T (from 'tls)
   unhex (T 'unhex) hex (T 'hex)
   wget (from 'kore 'wget-main)
   root "out/.wget"
   _ (hark (list "rm" "-rf" root))
   _ (mkdir "out" 493) _ (mkdir root 493) _ (mkdir (root + "/site") 493)
   home (cwd 0)
   sroot (home + "/" + root + "/site")
   ; a 70000-byte file: bigger than one socket gulp, so the read runs to the peer's close
   blob (string (map (\ i (& i 255)) ^70000))
   _ (: p (open (sroot + "/blob.bin") "w") _ (say p blob) (close p))
   port 7434
   l (listen port)
   srv (twirl (\ _ ((: (g k) (: _ (await l)
                                c (accept l)
                                _ (? (hot? c) (: _ ((from 'kiosko 'serve1) sroot () c)
                                          (close c)) ())
                                (g k)))
                    0)) 0)
   out1 (root + "/got.bin")
   rc (wget ["-q" "-O" out1 ("http://127.0.0.1:" + show port + "/blob.bin")])
   got (: p (open out1 "r") (? (hot? p) (: s (slurp p) _ (close p) s) ()))
   rc404 (wget ["-q" "-O" (root + "/none") ("http://127.0.0.1:" + show port + "/absent.bin")])
   rcbad (wget ["-q" "-O" (root + "/none") "ftp://nowhere/x"])
   (assert
    (0 = rc) (= got blob)                                              ; the bytes came back whole
    (8 = rc404)                                                        ; a server's no is wget's 8
    (1 = rcbad)                                                        ; not a url
    ; the tls floor: RFC 7748 6.1's alice, RFC 4231's first case
    (= "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"
       (hex ((T 'x25519-pub) (unhex "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))))
    (= "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
       (hex ((T 'hmac) ((T 'bytes) 20 (\ i 11)) "Hi There")))
    ; an aead round trip: what seal made, open takes back, and a flipped byte it refuses
    (: k ((T 'bytes) 32 (\ i i)) iv ((T 'bytes) 12 (\ i (+ i 7)))
       ct ((T 'aead-seal) k iv 3 "aad" "the plaintext")
       ok ((T 'aead-open) k iv 3 "aad" ct)
       bad ((T 'aead-open) k iv 3 "aad" ((T 'bytes) (tally ct) (\ i (? (= i 0) (^ (ct 0) 1) (ct i)))))
       (&& (two? ok) (= "the plaintext" <>ok) (! (two? bad))))))

(: _ (test_fin ()) _ (puts "wget: ok") _ (putc 10) 0)
