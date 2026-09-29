; --- test/host/tls.l: the cipher floor, against the RFCs' own numbers ---
; not in the test/*.l corpus: this loads a crew file and splices its module.
;
; chacha20 and poly1305 are arithmetic, not i/o, so what is asserted here is
; arithmetic -- the published vectors of RFC 8439, which is the only kind of
; check a cipher accepts. a cipher that is merely self-consistent is a cipher
; that agrees with its own bug: every number below came from the RFC, and each
; was independently re-derived (in python, and for chacha in C too) before it
; was written down here.
;
;   bytes    the little-endian/big-endian readers, and hex round-tripping.
;   block    §2.3.2 -- the 20-round chacha block on the RFC's key/nonce/counter.
;   stream   64 bytes per block, and block n is what counter n gives on its own
;            -- which is what proves the vectorisation: the counter varies down
;            a galaxy, and if it did not, every block in a batch would be equal.
;   cipher   §2.4.2 -- the sunscreen paragraph, whole, and its round trip.
;   mac      §2.5.2 -- the forum tag, plus the four lengths that exercise the
;            block edges: none, short, exactly one block, one block and a bit.
;   avalanche a one-bit change anywhere changes the tag. this is the assert that
;            fails if the conditional subtract at the end ever stops selecting.
;
; run:  cat test/00-init.l test/host/tls.l | out/love

(borrow "apps/tls/tls.l")

(test
 (elem 'tls (cite ()))
 (elem 'cc-block (keys (cite 'tls)))
 (elem 'po-mac (keys (cite 'tls)))
 (lit? (cite 'tls 'cc-xor)))

; --- bytes ------------------------------------------------------------------------
(test
 (66051 = (le32 (unhex "03020100") 0))         ; 0x00010203 little-endian
 (258 = (be16 (unhex "0102") 0))               ; ..and big-endian is the other way
 ("deadbeef" = (hex (unhex "deadbeef")))
 (4 = #(unhex "deadbeef"))
 ("00ff" = (hex (bytes 2 (\ i (i = 0 ? 0 255))))))

; --- the RFC's key and nonces -----------------------------------------------------
(: rfckey (bytes 32 (\ i i))                          ; 00 01 02 .. 1f
   n232 (bytes 12 (\ i (? (i = 3) 9 (i = 7) 74 0)))   ; §2.3.2: ..09 ..4a
   n242 (bytes 12 (\ i (i = 7 ? 74 0)))             ; §2.4.2: ..4a
   (wd out j i) (peep (peep out j 0) i 0))

; --- block: §2.3.2, the first four words of the 20-round block ---------------------
(: b232 (cc-block (cc-init rfckey n232 1 1))
   (test
    (3840405776 = (wd b232 0 0)) (358169553 = (wd b232 1 0))
    (534581072 = (wd b232 2 0))  (3295748259 = (wd b232 3 0))))

; --- stream: one block is 64 bytes, and a batch is its blocks ---------------------
(test
 (64 = #(cc-stream rfckey n232 1 1))
 (256 = #(cc-stream rfckey n232 1 4))
 ; the counter varies down the galaxy: block 2 of a 4-batch is the 1-batch at
 ; counter 2. this is the assert that would fail if the vectorisation collapsed.
 ((snip (cc-stream rfckey n232 1 4) 64 128) = (cc-stream rfckey n232 2 1))
 ((snip (cc-stream rfckey n232 1 4) 192 256) = (cc-stream rfckey n232 4 1))
 ; ..and distinct blocks are distinct, so the above is not two copies of nothing
 !((cc-stream rfckey n232 1 1) = (cc-stream rfckey n232 2 1)))

; --- cipher: §2.4.2, the sunscreen paragraph ---------------------------------------
(: pt242 ("Ladies and Gentlemen of the class of '99: If I could offer you only "
          + "one tip for the future, sunscreen would be it.")
   ct242 (cc-xor rfckey n242 1 pt242)
   (test
    (114 = #ct242)
    ((hex ct242) = ("6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b"
                    + "f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8"
                    + "07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736"
                    + "5af90bbf74a35be6b40b8eedf2785e42874d"))
    ; xor is its own inverse, so decryption is the same act
    (pt242 = (cc-xor rfckey n242 1 ct242))
    ; ..and the keystream is what did it
    !(ct242 = pt242)))

; --- mac: §2.5.2, and the block edges ---------------------------------------------
(: k252 (unhex "85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
   (test
    ((hex (po-mac k252 "Cryptographic Forum Research Group"))
     = "a8061dc1305136c6c22b8baf0c0127a9")
    (16 = #(po-mac k252 "anything at all"))
    ; the empty message accumulates nothing, so the tag is s -- the key's second
    ; half, unchanged. a cheap assert that catches a great many wiring errors.
    ((hex (po-mac rfckey "")) = "101112131415161718191a1b1c1d1e1f")
    ; the four lengths around a block boundary: short, exact, exact+1, several
    ((hex (po-mac rfckey "A")) = "245295d81b5fa2e5286caff23579bcff")
    ((hex (po-mac rfckey (bytes 16 (\ i i)))) = "a2291a363def0b53845fa4126a6ad364")
    ((hex (po-mac rfckey (bytes 17 (\ i i)))) = "f735c97f7308fd79222447fe76a96872")
    ((hex (po-mac rfckey (bytes 100 (\ i i)))) = "2c48db4b08964d7e67950fbd89760c4d")))

; --- the reduction boundary -------------------------------------------------------
; no message reaches this. the final conditional subtract fires only when the
; accumulator lands in [p, 2^130), which is 5 values out of 2^130 -- so random
; vectors, including every one above, leave that branch untested. deleting the
; subtract outright passed the whole file before these five asserts existed.
; so the accumulator is handed to po-fin directly, at and around p.
; p = 2^130 - 5 is all-ones across 130 bits less 4, hence the 67108859 low limb.
(: allone 67108863                                    ; 2^26 - 1
   (fin l0) (hex (po-fin [l0 allone allone allone allone] rfckey))
   sbytes "101112131415161718191a1b1c1d1e1f"          ; s alone, the key's second half
   (test
    ; h = p reduces to 0, so the tag is s -- the same tag the empty message gives,
    ; by a completely different route.
    ((fin 67108859) = sbytes)
    ((po-mac rfckey "") = (po-fin [67108859 allone allone allone allone] rfckey))
    ; h = p+1 reduces to 1, h = 2^130-1 reduces to 4: the top of the range folds
    ; down by exactly p, not by 2^130.
    ((fin 67108860) = "111112131415161718191a1b1c1d1e1f")
    ((fin allone) = "141112131415161718191a1b1c1d1e1f")
    ; ..and h = p-1 does not fire the subtract, so it stays put and is not s
    !((fin 67108858) = sbytes)))

; --- avalanche: the tag answers to every bit of both inputs -----------------------
(: m0 (bytes 64 (\ i i))
   m1 (bytes 64 (\ i (i = 63 ? 1 i)))            ; one bit of the last byte
   k0 rfckey
   k1 (bytes 32 (\ i (i = 0 ? 1 i)))             ; one bit of r
   k2 (bytes 32 (\ i (i = 16 ? 17 i)))           ; one bit of s
   (test
    !((po-mac k0 m0) = (po-mac k0 m1))
    !((po-mac k0 m0) = (po-mac k1 m0))
    !((po-mac k0 m0) = (po-mac k2 m0))
    ; ..and it is a function: same inputs, same tag
    ((po-mac k0 m0) = (po-mac k0 m0))))

;; --- verify: the leaf's key off its der, and the three signatures a CertificateVerify may be ---
; the certificates are openssl's own (req -x509 over an ed25519, a p-256 and an rsa-2048 key)
; and each signature python's cryptography made over the one message, the verify's shape
; around the sha-256 of "a transcript". a flipped byte, a mismatched scheme and a truncated
; certificate are refused; every prefix of a certificate, and every one-byte change of one,
; reads without dying
(: vsig-m (cv-msg (vsha "a transcript"))
   vder-ed (unhex ("308201383081eba003020102021442be1c96660904283478f8b8e645b1ff2b11459d300506032b6570301231"
           + "10300e06035504030c0765642e74657374301e170d3236303932393030333233345a170d3336303932363030"
           + "333233345a30123110300e06035504030c0765642e74657374302a300506032b657003210021c9c2429e1d03"
           + "2016fbd0527ea6a4acef97fc055ea8e171c415a9d24be668efa3533051301d0603551d0e04160414e0c18bd7"
           + "0492ac4d5ce379e859e7ea80258dea6e301f0603551d23041830168014e0c18bd70492ac4d5ce379e859e7ea"
           + "80258dea6e300f0603551d130101ff040530030101ff300506032b6570034100bac5a231a340e081865f9960"
           + "f8655a18f96b8a375b97fe8aa966473b685c6428662143bbfd2115052a07edd3c6d8ec0397ac97dedb15af38"
           + "b43cc682bb9cf104"))
   vder-ec (unhex ("308201793082011fa003020102021409129e15d2663ef4a2d4ec8f244abbddc17f21be300a06082a8648ce3d"
           + "04030230123110300e06035504030c0765632e74657374301e170d3236303932393030333233345a170d3336"
           + "303932363030333233345a30123110300e06035504030c0765632e746573743059301306072a8648ce3d0201"
           + "06082a8648ce3d030107034200044c550a5ae347cff135892e0a9e39e594ae7ce601abb715c3b4102b03c4f6"
           + "121de94c232d18b08be7b9a089727d8e195fb2de14e4ed0ae38b489a588e57eaea89a3533051301d0603551d"
           + "0e0416041408450e406a31134ef59c79e8316067898ba87075301f0603551d2304183016801408450e406a31"
           + "134ef59c79e8316067898ba87075300f0603551d130101ff040530030101ff300a06082a8648ce3d04030203"
           + "4800304502203f6272da1a98f77f6093d9d09688bea54d29be477018a0491c998fd182d19e9e022100a8fdbc"
           + "c2e60c7c96fd4031176b677f0c8b890239141e1394e9a120095d682a9d"))
   vder-rsa (unhex ("30820307308201efa003020102021423ca01f27b525eca9389e9e9d7cc424e207fe24d300d06092a864886f7"
           + "0d01010b050030133111300f06035504030c087273612e74657374301e170d3236303932393030333233345a"
           + "170d3336303932363030333233345a30133111300f06035504030c087273612e7465737430820122300d0609"
           + "2a864886f70d01010105000382010f003082010a0282010100bc23e6e4118d84bb6e779e0a0fbc554eb6bd8d"
           + "b8c4ce1891f6df17e3f9ba1dda3a92243d35d9984ecadfb3dddba2c93e81f67c23f6aec9d2f8cf2abebc37c3"
           + "07662ec8f4bb79a991ea5afcd9b390b4431283686e4e47bf2b7020749ee74af213f0bb0a319ffe63ca1e0b6b"
           + "c9688229e3743e525fe04dfe4e7e11fffbdf9bc0afdd55f97abca9d015294eb971ddb3e853c39c858c6ab2d4"
           + "eb34e2459687aff2c6ab17fc7c7e83626e23b6e2ad461591fd49fc5b9981676f4a260a425fff7f306ae2b3fd"
           + "f26d9b4fe9e681f72fdb500c3e4e2607e4ec9642703724ee6992a364bf62c53df484fc58dde32e22bac20a29"
           + "0ef4f229c849ee13d86105da7308182ee10203010001a3533051301d0603551d0e041604147fb3b673ae2f91"
           + "7a3417d8e15d11ff1b85076f0f301f0603551d230418301680147fb3b673ae2f917a3417d8e15d11ff1b8507"
           + "6f0f300f0603551d130101ff040530030101ff300d06092a864886f70d01010b05000382010100430acba678"
           + "d39d72ac5b6c15123178fbb47ef62d825c401a2a51216ad72c019e4dae07df103adfab7b287b37852ae7a45e"
           + "c0b914b319aee3d7a23d416312b1875edf4dcd0a2c43317ce761623c2339bcd225de0227008c1ef578a39eb5"
           + "fd2f0adba7d1b97631fd5c1c4f6e2e502df964b1a29eb03729373c9363baaf5a5eb5410459df7e4d9cac722f"
           + "fbaaea196c765cee02e5699dc2e2b6d03783c30a94e6c45c120f785b12f2c78ef9d426fee485c4de06d26f32"
           + "883e988c596bbf44619a20472ec1d822731b5093f746ca49ba3f436b6865b1c24df79ad08f494dba4c0efa77"
           + "6745194aadb710d66525ca341d868d422e0e81288b5eb26d44d10493039be3"))
   vsig-ed (unhex ("ca56818e180270586d086465948c12daae30322be7895095b37f580a5a6e126d5d989991eff40b10df7a5bbd"
           + "5ed614e7606cb45595f26647991c8a847440f70e"))
   vsig-ec (unhex ("3046022100d1fb6d0cac3f22130ae57db9628394e79c9090c10348096a6cb53bae86dbecef0221009e95516c"
           + "5afe18cb99bbf7cacf35d9d97f004a9789952b40213a7d075e2e56ec"))
   vsig-rsa (unhex ("8e874d8ae2133b636e109b20550703d6a36d6c7076eb9ae5f11ade12818b4af8c9323e0dc233163dcf119511"
           + "58e4df9c56ed71c21f1033d41621e8c79c4b74743897584a54efcb80fbb34749176e2313717865af6bb8ab0b"
           + "b1538b25eb9a67016079b2693188c093480560570d98a251091bb55f2295b84ce47d1f942c7a066024e336d8"
           + "a93286a2747d070e5085de46b3d90c8174402f549c2e42be98f93fd03bd9cf0fae2ecc6ba59956b701e41ec5"
           + "fd3a4c1efa3ce93d6f1e1ed0c72ac4c006d0b3a70b12030ab64daad42f2cd7144a38a11b6d74f421e3416ff3"
           + "ca9b74a1e3e348cf2877f2d4162553cb1f097e2fe928ab1f22eb54a14314dd63c61b52bc"))
   (vflip s i) (snip s 0 i + string ((s i) ^ 1) + snip s (i + 1) #s)
   ked (leaf-key vder-ed) kec (leaf-key vder-ec) krsa (leaf-key vder-rsa)
   _ (test ((hex vsig-m) = "20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020544c5320312e332c20736572766572204365727469666963617465566572696679003af65a7a89bdcfc5de8bc7d6ec78f66b56664c5e4c14686f96334567219f1d65")
           (<ked = 'ed25519) (<kec = 'p256) (<krsa = 'rsa)
           ((krsa 1 1) = 65537)
           ; the spki is the der of the key alone, inside the certificate
           (0 < #(ked 2)) (<(der (ked 2) 0 #(ked 2)) = 48)
           ((cv-ok? ked 2055 vsig-ed vsig-m) = 1)
           ((cv-ok? kec 1027 vsig-ec vsig-m) = 1)
           ((cv-ok? krsa 2052 vsig-rsa vsig-m) = 1)
           ; a byte of the signature, a byte of the message, the scheme, the key: each refuses
           ((cv-ok? ked 2055 (vflip vsig-ed 9) vsig-m) = 0)
           ((cv-ok? kec 1027 (vflip vsig-ec 12) vsig-m) = 0)
           ((cv-ok? krsa 2052 (vflip vsig-rsa 100) vsig-m) = 0)
           ((cv-ok? krsa 2052 vsig-rsa (vflip vsig-m 70)) = 0)
           ((cv-ok? kec 2052 vsig-ec vsig-m) = 0)
           ((cv-ok? krsa 1027 vsig-ec vsig-m) = 0)
           ((cv-ok? kec 1027 vsig-ec (vflip vsig-m 90)) = 0)
           ((cv-ok? kec 1027 "" vsig-m) = 0)
           ((cv-ok? krsa 2052 (snip vsig-rsa 1 #vsig-rsa) vsig-m) = 0))
   (every-prefix der) (all (n \ atom? (leaf-key (snip der 0 n))) ^#der)
   (every-flip der) (all (i \ (: k (leaf-key (vflip der i)) (atom? k || two? k))) ^#der)
   _ (test (every-prefix vder-ed) (every-prefix vder-ec) (every-flip vder-ed) (every-flip vder-ec)
           !(leaf-key "") !(leaf-key (unhex "3080")) !(leaf-key (unhex "3084ffffffff"))))

;; --- the handshake: a server of our own, honest or not -------------------------------
; a tls 1.3 server in a task, built from the client's own parts over one ed25519 key and
; the certificate above that carries it. honest, the dial holds and the data arrives; with
; the verify's signature flipped, made by another key, left out, or the certificate left
; out, or the finished flipped, the dial fails and the server reads the client's alert --
; decrypt_error (51) -- under the client's handshake key. those dial with no trust check
; ('none); then the trust: its self-signed certificate is refused against a root that did not
; sign it (unknown_ca, 48), taken by a pin in ~/.love/tls_pins, and refused under another
; pin (bad_certificate, 42)
(: hs-seed (unhex "893a665eebf62b9c0caf1f1de33129ee339d748b1e5f38327c4ad24e2052683d")
   (hs-msg ty b) (u8 ty + u24 #b + b)
   (hs-share ch)
    (: b (snip ch 4 #ch) i (35 + b 34) i2 (i + 2 + rd16 b i) i3 (i2 + 1 + b i2) end (i3 + 2 + rd16 b i3)
       (go j) (? (end <= j) () (rd16 b j = 51) (snip b (j + 10) (j + 42)) (go (j + 4 + rd16 b (j + 2))))
       (go (i3 + 2)))
   (hs-serve l mode)
    (: c (accept l) sv (tablet 8) _ (pins sv 's c 'pend "" 'cseq 0 'sseq 0)
       r (rdrec sv) ch <>r b (snip ch 4 #ch) sid (snip b 35 (35 + b 34))
       priv (rnd 32) pub (x25519-pub priv)
       exts (ext 43 (u16 772) + ext 51 (u16 29 + u16 32 + pub))
       shb (u16 771 + rnd 32 + u8 #sid + sid + u16 4867 + u8 0 + u16 #exts + exts)
       sh (hs-msg 2 shb)
       _ (wr sv (u8 22 + u16 771 + u16 #sh + sh))
       hs (hkdf-extract (derive (hkdf-extract (zeros 32) (zeros 32)) "derived" "") (x25519 priv (hs-share ch)))
       shs (derive hs "s hs traffic" (ch + sh)) chs (derive hs "c hs traffic" (ch + sh))
       _ (pins sv 'ckey (hkdf-label shs "key" "" 32) 'civ (hkdf-label shs "iv" "" 12)
               'skey (hkdf-label chs "key" "" 32) 'siv (hkdf-label chs "iv" "" 12))
       ee (hs-msg 8 (u16 0))
       crt (hs-msg 11 (u8 0 + u24 (#vder-ed + 5) + u24 #vder-ed + vder-ed + u16 0))
       crt2 (? (mode = 'nocert) "" crt)
       tr1 (ch + sh + ee + crt2)
       seed (? (mode = 'otherkey) (bytes 32 (i \ i)) hs-seed)
       sig0 (cite 'ssh 'ed-sign seed (cite 'ssh 'ed-pub seed) (cv-msg (sha tr1)))
       sig (? (mode = 'badsig) (vflip sig0 3) sig0)
       cv (? (mode = 'nocv) "" (hs-msg 15 (u16 2055 + u16 #sig + sig)))
       fv0 (hmac (hkdf-label shs "finished" "" 32) (sha (tr1 + cv)))
       fin (hs-msg 20 (? (mode = 'badfin) (vflip fv0 0) fv0))
       _ (map (m \ ? (0 < #m) (seal sv 22 m) 0) [ee crt2 cv fin])
       master (hkdf-extract (derive hs "derived" "") (zeros 32))
       sats (derive master "s ap traffic" (tr1 + cv + fin))
       got (open-rec sv)
       _ (? (mode = 'honest)
            (: _ (pins sv 'ckey (hkdf-label sats "key" "" 32) 'civ (hkdf-label sats "iv" "" 12) 'cseq 0)
               _ (seal sv 23 "the stub says hi")
               (seal sv 21 (u8 1 + u8 0)))
            0)
       _ (close c)
       got)
   (hs-run port mode how)
    (: l (listen ['tcp "127.0.0.1" port])
       s (twirl (_ \ hs-serve l mode) ())
       t (tls-open "127.0.0.1" port how)
       body (? (tablet? t) (: b (tls-slurp t) _ (close (t 's)) b) ())
       got (catch s)
       _ (close l)
       [body got (? (tablet? t) (t 'spki) t)])
   ok (hs-run 7481 'honest 'none)
   _ (test (<ok = "the stub says hi") (<(ok 1) = 22) ((ok 2) = (ked 2)))
   _ (map (m \ (: r (hs-run (7482 + m 1) <m 'none)
                  (test !(<r) ((r 1) = [21 (u8 2 + u8 (m 2))]) (string? (r 2)))))
          [['badsig 0 51] ['otherkey 1 51] ['nocv 2 51] ['badfin 3 51] ['nocert 4 51]])
   ; the trust, with HOME and SSL_CERT_FILE the test's own
   home0 (getenv "HOME") cf0 (getenv "SSL_CERT_FILE")
   hdir ((cwd 0) + "/out/.tlsp-" + show (getpid 0))
   _ (hark ["mkdir" "-p" (hdir + "/.love")])
   _ (setenv "HOME" hdir)
   _ (setenv "SSL_CERT_FILE" ((cwd 0) + "/test/host/tlschain/roote.pem"))
   (pinfile l) (: q (open (hdir + "/.love/tls_pins") "w") _ (say q l) (close q))
   un (hs-run 7487 'honest 'verify)
   _ (pinfile ("# a comment\n127.0.0.1:7491 " + spki-pin (ked 2) + "\n"))
   pn (hs-run 7491 'honest 'verify)
   _ (pinfile ("127.0.0.1:7492 spki:" + sha256 "another key" + "\n"))
   wp (hs-run 7492 'honest 'verify)
   _ (setenv "HOME" (? (string? home0) home0 ""))
   _ (setenv "SSL_CERT_FILE" (? (string? cf0) cf0 ""))
   _ (hark ["rm" "-rf" hdir])
   _ (test !(<un) ((un 1) = [21 (u8 2 + u8 48)])
           (0 <= str-at (un 2) "not trusted" 0) (0 <= str-at (un 2) "127.0.0.1:7487 spki:" 0)
           (<pn = "the stub says hi")
           !(<wp) ((wp 1) = [21 (u8 2 + u8 42)]) (0 <= str-at (wp 2) "not the one pinned" 0))
   0)

;; --- a real server: openssl's s_server over each kind of key, where openssl is here ----
; a root laid here signs a leaf of each kind for 127.0.0.1, and SSL_CERT_FILE names the root:
; each dial verifies. the same server is refused under the host's own bundle, and a leaf that
; names another host is refused by name
(: os? (two? (stat "/usr/bin/openssl"))
   odir ((cwd 0) + "/out/.tlsv-" + show (getpid 0))
   (osh c) (hark ["sh" "-c" ("exec 2>/dev/null; cd " + odir + " && " + c)])
   (oleaf nm arg san)
    (osh ("printf 'basicConstraints=critical,CA:FALSE\\nsubjectAltName=" + san + "\\n' > " + nm + ".cnf"
          + " && openssl req -new -newkey " + arg + " -nodes -keyout " + nm + ".key -subj /CN=" + nm + " -out " + nm + ".csr"
          + " && openssl x509 -req -in " + nm + ".csr -CA root.pem -CAkey root.key -days 2 -extfile " + nm + ".cnf -out " + nm + ".pem"))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (rest 2, waitfor pid)))
   (orun nm port)
    (: p (tether ["openssl" "s_server" "-quiet" "-tls1_3" "-naccept" "1" "-www" "-accept" ("127.0.0.1:" + show port)
                  "-key" (odir + "/" + nm + ".key") "-cert" (odir + "/" + nm + ".pem")])
       _ (rest 500)
       t (tls-open "127.0.0.1" port 'verify)
       b (? (tablet? t) (: _ (tls-say t "GET / HTTP/1.0\r\n\r\n") b (tls-slurp t) _ (close (t 's)) b) t)
       _ (? (tablet? t) 0 (still <p 15))
       _ (waitfor <p)
       b)
   (has b s) (string? b && 0 <= str-at b s 0)
   _ (? os?
        (: cf0 (getenv "SSL_CERT_FILE")
           _ (hark ["mkdir" "-p" odir])
           _ (osh ("openssl req -x509 -newkey rsa:2048 -nodes -keyout root.key -out root.pem -days 2 -subj /CN=tlsv-root"
                   + " -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign"))
           _ (oleaf "ed" "ed25519" "IP:127.0.0.1")
           _ (oleaf "ec" "ec -pkeyopt ec_paramgen_curve:P-256" "IP:127.0.0.1")
           _ (oleaf "p384" "ec -pkeyopt ec_paramgen_curve:P-384" "IP:127.0.0.1")
           _ (oleaf "rsa" "rsa:2048" "IP:127.0.0.1")
           _ (oleaf "other" "ec -pkeyopt ec_paramgen_curve:P-256" "DNS:other.test")
           _ (setenv "SSL_CERT_FILE" (odir + "/root.pem"))
           e (orun "ed" 7488) p (orun "ec" 7489) q (orun "p384" 7493) r (orun "rsa" 7490) o (orun "other" 7494)
           _ (setenv "SSL_CERT_FILE" "/nonexistent/bundle.pem")
           n (orun "rsa" 7495)
           _ (setenv "SSL_CERT_FILE" (? (string? cf0) cf0 ""))
           _ (hark ["rm" "-rf" odir])
           (test (has e "TLSv1.3") (has p "TLSv1.3") (has q "TLSv1.3") (has r "TLSv1.3")
                 (has o "does not name 127.0.0.1") (has n "no root certificates")))
        0)
   0)

;; --- the chain: x509 path building over openssl's fixtures (test/host/tlschain, gen.sh) ----
; two roots (rsa, p-384) and one of p-521, intermediates and leaves over rsa pkcs#1 with
; sha-256/384/512 and ecdsa over each curve, all valid 2025..2035 and read at mid-2026. the
; good chains verify leaf-first, out of order and with their root sent along; each broken
; rule is refused, and the refusal names the certificate and the check
(borrow 'cal)
(: (tc-ld nm) (: r (uread ("test/host/tlschain/" + nm + ".pem")) (? (two? r) <(pem-ders <>r) ""))
   tc-now (epoch-days 2026 6 1 * 86400)
   tc-roots (map (n \ x509 (tc-ld n)) ["rootr" "roote" "rootw"])
   (tc host l) (chain-ok? (map tc-ld l) tc-roots host tc-now)
   (tc-flip d i) (snip d 0 i + string ((d i) ^ 1) + snip d (i + 1) #d)
   (tc-has r s) (string? r && (0 <= str-at r s 0))
   _ (test ((tc "good.test" ["leafr" "interr"]) = 1)
           ((tc "good.test" ["leafe" "intere"]) = 1)                ; p-256 under p-384
           ((tc "good.test" ["leafw"]) = 1)                          ; p-384 under p-521, sha-512
           ((tc "good.test" ["leaf512" "interr"]) = 1)               ; pkcs#1 over sha-512
           ((tc "GOOD.test." ["leafr" "interr"]) = 1)                ; case and a trailing dot
           ((tc "a.wild.test" ["leafr" "interr"]) = 1)
           ((tc "127.0.0.1" ["leafr" "interr"]) = 1)                 ; an address against iPAddress
           ((tc "good.test" ["leafr" "rootr" "interr"]) = 1)         ; out of order, its root sent
           ((tc "good.test" ["deep" "inter1" "inter0"]) != 1)
           (tc-has (tc "good.test" ["expired" "interr"]) "\"expired\": it has expired")
           (tc-has (tc "good.test" ["notyet" "interr"]) "\"notyet\": it is not valid yet")
           (tc-has (tc "bad.test" ["leafr" "interr"]) "\"leafr\": it does not name bad.test")
           (tc-has (tc "127.0.0.2" ["leafr" "interr"]) "does not name")
           (tc-has (tc "a.b.wild.test" ["leafr" "interr"]) "does not name")   ; one label only
           (tc-has (tc "wild.test" ["leafr" "interr"]) "does not name")        ; not the bare name
           (tc-has (tc "foo.wild.test" ["partial" "interr"]) "does not name")  ; no f*.wild.test
           (tc-has (tc "x.test" ["partial" "interr"]) "does not name")         ; no *.test
           (tc-has (tc "good.test" ["undernoca" "noca" "interr"]) "\"noca\": it is not a certificate authority")
           (tc-has (tc "good.test" ["deep" "inter1" "inter0"]) "\"inter0\": its pathLen is exceeded")
           (tc-has (tc "good.test" ["crit" "interr"]) "\"crit\": a critical extension it does not know")
           (tc-has (tc "good.test" ["client" "interr"]) "\"client\": it is not for serving tls")
           (tc-has (tc "good.test" ["undernosign" "nosign"]) "\"nosign\": its keyUsage does not allow")
           (tc-has (tc "good.test" ["nosan" "interr"]) "\"nosan\": it does not name good.test")
           (tc-has (tc "good.test" ["leafr"]) "\"leafr\": no issuer for it is known")
           (tc-has (chain-ok? [(tc-ld "leafr") (tc-ld "interr")] () "good.test" tc-now) "no issuer")
           (tc-has (chain-ok? [] tc-roots "good.test" tc-now) "no certificate"))
   ; a byte of a signature, or of what it signs, at each depth
   lr (tc-ld "leafr") ir (tc-ld "interr")
   _ (test (tc-has (chain-ok? [(tc-flip lr (#lr - 1)) ir] tc-roots "good.test" tc-now) "\"leafr\": its signature does not verify")
           (tc-has (chain-ok? [lr (tc-flip ir (#ir - 1))] tc-roots "good.test" tc-now) "\"interr\": its signature does not verify")
           (1 != chain-ok? [(tc-flip lr 200) ir] tc-roots "good.test" tc-now)
           (1 != chain-ok? [(tc-ld "leafe") (tc-flip (tc-ld "intere") (#(tc-ld "intere") - 2))] tc-roots "good.test" tc-now))
   ; the times, both encodings; the name rules alone
   _ (test ((x509-time (string 23 + string 13 + "500101000000Z") [23 2 15 0]) = [(0 - 631152000)])
           ((x509-time (string 24 + string 15 + "20260601000000Z") [24 2 17 0]) = [tc-now])
           !(x509-time (string 23 + string 13 + "260601000000+") [23 2 15 0])
           (dns-match? "*.a.test" "x.a.test") !(dns-match? "*.a.test" "a.test")
           !(dns-match? "x*.a.test" "xy.a.test") !(dns-match? "*.*.test" "a.b.test")
           !(dns-match? "*.test" "a.test") (dns-match? "A.Test" "a.TEST"))
   ; every prefix of a certificate, and every one-byte change, reads without dying
   _ (test (all (n \ !(tablet? (x509 (snip ir 0 n)))) ^#ir)
           (all (i \ (: x (x509 (tc-flip ir i)) (atom? x || tablet? x))) ^#ir)))

;; --- the roots: SSL_CERT_FILE names the bundle, read once; the host's own reads whole ----
(: e0 (getenv "SSL_CERT_FILE")
   _ (setenv "SSL_CERT_FILE" "test/host/tlschain/roote.pem")
   r1 (tls-roots 0) r2 (tls-roots 0)
   _ (setenv "SSL_CERT_FILE" "test/host/tlschain/none.pem")
   r3 (tls-roots 0)
   _ (setenv "SSL_CERT_FILE" (? (string? e0) e0 ""))
   hb (filter (p \ two? (stat p)) root-homes)
   hn (? (two? hb) (: t (uread <hb) ds (pem-ders <>t) [#ds #(filter tablet? (map x509 ds))]) [1 1])
   _ (test (<r1 = "test/host/tlschain/roote.pem") (#(r1 1) = 1) (r1 1 0 'subject = (x509 (tc-ld "roote")) 'subject)
           ((r2 1) = (r1 1))                                       ; the same list: read once
           ((r3 1) = ())
           (0 < <hn) (<hn = hn 1)))

; the harness greps for this line, and that is the point: a reader stop exits 0
; with the asserts above never read, so only reaching here proves the file ran.
(test_fin (),
 puts "apps/tls: ok -- chacha20 + poly1305 (rfc 8439 block, stream, counter, cipher, mac); the handshake's verify
",
 0)
