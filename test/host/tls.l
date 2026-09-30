; test/host/tls.l -- the cipher floor against RFC 8439's own vectors: the byte readers, the
; chacha20 block (§2.3.2) and stream, the sunscreen cipher (§2.4.2), the poly1305 tag (§2.5.2)
; at the block edges, and the avalanche. every number came from the RFC, never from this code.
; block n of a batch is what counter n gives alone: that is what proves the vectorisation.
; the avalanche is what fails if poly's conditional subtract ever stops selecting.
; not in the corpus: it loads a crew file. run: cat test/00-init.l test/host/tls.l | out/love

(borrow "src/apps/tls/tls.l")

(test
 (elem 'tls (cite ()))
 (elem 'cc-block (keys (cite 'tls)))
 (elem 'po-mac (keys (cite 'tls)))
 (lit? (cite 'tls 'cc-xor)))

; --- bytes ------------------------------------------------------------------------
(test
 (66051 = le32 (unhex "03020100") 0)         ; 0x00010203 little-endian
 (258 = be16 (unhex "0102") 0)               ; ..and big-endian is the other way
 ("deadbeef" = hex (unhex "deadbeef"))
 (4 = #(unhex "deadbeef"))
 ("00ff" = hex (bytes 2 (i \ (i = 0 ? 0 255)))))

; --- the RFC's key and nonces -----------------------------------------------------
(: rfckey (bytes 32 (i \ i))                          ; 00 01 02 .. 1f
   n232 (bytes 12 (i \ (? (i = 3) 9 (i = 7) 74 0)))   ; §2.3.2: ..09 ..4a
   n242 (bytes 12 (i \ (i = 7 ? 74 0)))             ; §2.4.2: ..4a
   (wd out j i) (peep (peep out j 0) i 0))

; --- block: §2.3.2, the first four words of the 20-round block ---------------------
(cc-block (cc-init rfckey n232 1 1) @ b232
   (test
    (3840405776 = wd b232 0 0) (358169553 = wd b232 1 0)
    (534581072 = wd b232 2 0)  (3295748259 = wd b232 3 0)))

; --- stream: one block is 64 bytes, and a batch is its blocks ---------------------
(test
 (64 = #(cc-stream rfckey n232 1 1))
 (256 = #(cc-stream rfckey n232 1 4))
 ; the counter varies down the galaxy: block 2 of a 4-batch is the 1-batch at
 ; counter 2. this is the assert that would fail if the vectorisation collapsed.
 (snip (cc-stream rfckey n232 1 4) 64 128 = cc-stream rfckey n232 2 1)
 (snip (cc-stream rfckey n232 1 4) 192 256 = cc-stream rfckey n232 4 1)
 ; ..and distinct blocks are distinct, so the above is not two copies of nothing
 !(cc-stream rfckey n232 1 1 = cc-stream rfckey n232 2 1))

; --- cipher: §2.4.2, the sunscreen paragraph ---------------------------------------
(: pt242 ("Ladies and Gentlemen of the class of '99: If I could offer you only "
          + "one tip for the future, sunscreen would be it.")
   ct242 (cc-xor rfckey n242 1 pt242)
   (test
    (114 = #ct242)
    (hex ct242 = ("6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b"
                    + "f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8"
                    + "07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736"
                    + "5af90bbf74a35be6b40b8eedf2785e42874d"))
    ; xor is its own inverse, so decryption is the same act
    (pt242 = cc-xor rfckey n242 1 ct242)
    ; ..and the keystream is what did it
    !(ct242 = pt242)))

; --- mac: §2.5.2, and the block edges ---------------------------------------------
(unhex "85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b" @ k252
   (test
    (hex (po-mac k252 "Cryptographic Forum Research Group")
     = "a8061dc1305136c6c22b8baf0c0127a9")
    (16 = #(po-mac k252 "anything at all"))
    ; the empty message accumulates nothing, so the tag is s -- the key's second
    ; half, unchanged. a cheap assert that catches a great many wiring errors.
    (hex (po-mac rfckey "") = "101112131415161718191a1b1c1d1e1f")
    ; the four lengths around a block boundary: short, exact, exact+1, several
    (hex (po-mac rfckey "A") = "245295d81b5fa2e5286caff23579bcff")
    (hex (po-mac rfckey (bytes 16 (i \ i))) = "a2291a363def0b53845fa4126a6ad364")
    (hex (po-mac rfckey (bytes 17 (i \ i))) = "f735c97f7308fd79222447fe76a96872")
    (hex (po-mac rfckey (bytes 100 (i \ i))) = "2c48db4b08964d7e67950fbd89760c4d")))

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
    (fin 67108859 = sbytes)
    (po-mac rfckey "" = po-fin [67108859 allone allone allone allone] rfckey)
    ; h = p+1 reduces to 1, h = 2^130-1 reduces to 4: the top of the range folds
    ; down by exactly p, not by 2^130.
    (fin 67108860 = "111112131415161718191a1b1c1d1e1f")
    (fin allone = "141112131415161718191a1b1c1d1e1f")
    ; ..and h = p-1 does not fire the subtract, so it stays put and is not s
    !(fin 67108858 = sbytes)))

; --- avalanche: the tag answers to every bit of both inputs -----------------------
(: m0 (bytes 64 (i \ i))
   m1 (bytes 64 (i \ (i = 63 ? 1 i)))            ; one bit of the last byte
   k0 rfckey
   k1 (bytes 32 (i \ (i = 0 ? 1 i)))             ; one bit of r
   k2 (bytes 32 (i \ (i = 16 ? 17 i)))           ; one bit of s
   (test
    !(po-mac k0 m0 = po-mac k0 m1)
    !(po-mac k0 m0 = po-mac k1 m0)
    !(po-mac k0 m0 = po-mac k2 m0)
    ; ..and it is a function: same inputs, same tag
    (po-mac k0 m0 = po-mac k0 m0)))

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
   (vflip s i) (snip s 0 i + string (s i ^ 1) + snip s (i + 1) #s)
   ked (leaf-key vder-ed) kec (leaf-key vder-ec) krsa (leaf-key vder-rsa)
   _ (test (hex vsig-m = "20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020544c5320312e332c20736572766572204365727469666963617465566572696679003af65a7a89bdcfc5de8bc7d6ec78f66b56664c5e4c14686f96334567219f1d65")
           (<ked = 'ed25519) (<kec = 'p256) (<krsa = 'rsa)
           (krsa 1 1 = 65537)
           ; the spki is the der of the key alone, inside the certificate
           (0 < #(ked 2)) (<(der (ked 2) 0 #(ked 2)) = 48)
           (cv-ok? ked 2055 vsig-ed vsig-m = 1)
           (cv-ok? kec 1027 vsig-ec vsig-m = 1)
           (cv-ok? krsa 2052 vsig-rsa vsig-m = 1)
           ; a byte of the signature, a byte of the message, the scheme, the key: each refuses
           (cv-ok? ked 2055 (vflip vsig-ed 9) vsig-m = 0)
           (cv-ok? kec 1027 (vflip vsig-ec 12) vsig-m = 0)
           (cv-ok? krsa 2052 (vflip vsig-rsa 100) vsig-m = 0)
           (cv-ok? krsa 2052 vsig-rsa (vflip vsig-m 70) = 0)
           (cv-ok? kec 2052 vsig-ec vsig-m = 0)
           (cv-ok? krsa 1027 vsig-ec vsig-m = 0)
           (cv-ok? kec 1027 vsig-ec (vflip vsig-m 90) = 0)
           (cv-ok? kec 1027 "" vsig-m = 0)
           (cv-ok? krsa 2052 (snip vsig-rsa 1 #vsig-rsa) vsig-m = 0))
   (every-prefix der) (all (n \ atom? (leaf-key (snip der 0 n))) ^#der)
   (every-flip der) (all (i \ (leaf-key (vflip der i) @ k (atom? k || two? k))) ^#der)
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
       crt2 (mode = 'nocert ? "" crt)
       tr1 (ch + sh + ee + crt2)
       seed (mode = 'otherkey ? (bytes 32 (i \ i)) hs-seed)
       sig0 (cite 'ssh 'ed-sign seed (cite 'ssh 'ed-pub seed) (cv-msg (sha tr1)))
       sig (mode = 'badsig ? (vflip sig0 3) sig0)
       cv (mode = 'nocv ? "" (hs-msg 15 (u16 2055 + u16 #sig + sig)))
       fv0 (hmac (hkdf-label shs "finished" "" 32) (sha (tr1 + cv)))
       fin (hs-msg 20 (mode = 'badfin ? (vflip fv0 0) fv0))
       _ (map (m \ ? (0 < #m) (seal sv 22 m) 0) [ee crt2 cv fin])
       master (hkdf-extract (derive hs "derived" "") (zeros 32))
       sats (derive master "s ap traffic" (tr1 + cv + fin))
       got (open-rec sv)
       ((mode = 'honest ?
           (pins sv 'ckey (hkdf-label sats "key" "" 32) 'civ (hkdf-label sats "iv" "" 12) 'cseq 0,
            seal sv 23 "the stub says hi",
            seal sv 21 (u8 1 + u8 0))
           0),
        close c,
        got))
   ; a loopback listener of this run's own, [port listener], for hs-run
   (hs-seat u) (test-seat (p \ (listen ['tcp "127.0.0.1" p])))
   (hs-run pl mode how)
    (: port <pl
       l (pl 1)
       s (twirl (_ \ hs-serve l mode) ())
       t (tls-open "127.0.0.1" port how)
       body (tablet? t ? (tls-slurp t @ b (close (t 's), b)))
       got (catch s)
       (close l,
        [body got (tablet? t ? (t 'spki) t)]))
   ok (hs-run (hs-seat 0) 'honest 'none)
   _ (test (<ok = "the stub says hi") (<(ok 1) = 22) (ok 2 = ked 2))
   _ (map (m \ (hs-run (hs-seat 0) <m 'none @ r
                  (test !(<r) (r 1 = [21 (u8 2 + u8 (m 2))]) (string? (r 2)))))
          [['badsig 0 51] ['otherkey 1 51] ['nocv 2 51] ['badfin 3 51] ['nocert 4 51]])
   ; the trust, with HOME and SSL_CERT_FILE the test's own
   home0 (getenv "HOME") cf0 (getenv "SSL_CERT_FILE")
   hdir (cwd 0 + "/out/.tlsp-" + show (getpid 0))
   _ (hark ["mkdir" "-p" (hdir + "/.love")])
   _ (setenv "HOME" hdir)
   _ (setenv "SSL_CERT_FILE" (cwd 0 + "/test/host/tlschain/roote.pem"))
   (pinfile l) (open (hdir + "/.love/tls_pins") "w" @ q (say q l, close q))
   pu (hs-seat 0)
   un (hs-run pu 'honest 'verify)
   pp (hs-seat 0)
   _ (pinfile ("# a comment\n127.0.0.1:" + show <pp + " " + spki-pin (ked 2) + "\n"))
   pn (hs-run pp 'honest 'verify)
   pw (hs-seat 0)
   _ (pinfile ("127.0.0.1:" + show <pw + " spki:" + sha256 "another key" + "\n"))
   wp (hs-run pw 'honest 'verify)
   (setenv "HOME" (string? home0 ? home0 ""),
    setenv "SSL_CERT_FILE" (string? cf0 ? cf0 ""),
    hark ["rm" "-rf" hdir],
    test !(<un) (un 1 = [21 (u8 2 + u8 48)])
         (0 <= str-at (un 2) "not trusted" 0) (0 <= str-at (un 2) ("127.0.0.1:" + show <pu + " spki:") 0)
         (<pn = "the stub says hi")
         !(<wp) (wp 1 = [21 (u8 2 + u8 42)]) (0 <= str-at (wp 2) "not the one pinned" 0),
    0))

;; --- a real server: openssl's s_server over each kind of key, where openssl is here ----
; a root laid here signs a leaf of each kind for 127.0.0.1, and SSL_CERT_FILE names the root:
; each dial verifies. the same server is refused under the host's own bundle, and a leaf that
; names another host is refused by name
(: os? (two? (stat "/usr/bin/openssl"))
   odir (cwd 0 + "/out/.tlsv-" + show (getpid 0))
   (osh c) (hark ["sh" "-c" ("exec 2>/dev/null; cd " + odir + " && " + c)])
   (oleaf nm arg san)
    (osh ("printf 'basicConstraints=critical,CA:FALSE\\nsubjectAltName=" + san + "\\n' > " + nm + ".cnf"
          + " && openssl req -new -newkey " + arg + " -nodes -keyout " + nm + ".key -subj /CN=" + nm + " -out " + nm + ".csr"
          + " && openssl x509 -req -in " + nm + ".csr -CA root.pem -CAkey root.key -days 2 -extfile " + nm + ".cnf -out " + nm + ".pem"))
   (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (rest 2, waitfor pid)))
   (orun nm port)
    (: p (tether ["openssl" "s_server" "-quiet" "-tls1_3" "-naccept" "1" "-www" "-accept" ("127.0.0.1:" + show port)
                  "-key" (odir + "/" + nm + ".key") "-cert" (odir + "/" + nm + ".pem")])
       ; the server listens when it is ready, not after a fixed wait: under load it is slow
       (open k) (tls-open "127.0.0.1" port 'verify @ t
                   (k < 40 && string? t && 0 <= str-at t "cannot connect" 0 ? (rest 250, open (k + 1)) t))
       t (open 0)
       b (tablet? t ? (: _ (tls-say t "GET / HTTP/1.0\r\n\r\n") b (tls-slurp t) (close (t 's), b)) t)
       ((tablet? t ? 0 (still <p 15)),
        waitfor <p,
        b))
   (has b s) (string? b && 0 <= str-at b s 0)
   ((os? ?
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
          e (orun "ed" (test-free 0)) p (orun "ec" (test-free 0)) q (orun "p384" (test-free 0)) r (orun "rsa" (test-free 0)) o (orun "other" (test-free 0))
          _ (setenv "SSL_CERT_FILE" "/nonexistent/bundle.pem")
          n (orun "rsa" (test-free 0))
          (setenv "SSL_CERT_FILE" (string? cf0 ? cf0 ""),
           hark ["rm" "-rf" odir],
           test (has e "TLSv1.3") (has p "TLSv1.3") (has q "TLSv1.3") (has r "TLSv1.3")
                (has o "does not name 127.0.0.1") (has n "no root certificates")))
       0),
    0))

;; --- the chain: x509 path building over openssl's fixtures (test/host/tlschain, gen.sh) ----
; two roots (rsa, p-384) and one of p-521, intermediates and leaves over rsa pkcs#1 with
; sha-256/384/512 and ecdsa over each curve, all valid 2025..2035 and read at mid-2026. the
; good chains verify leaf-first, out of order and with their root sent along; each broken
; rule is refused, and the refusal names the certificate and the check
(borrow 'cal)
(: (tc-ld nm) (uread ("test/host/tlschain/" + nm + ".pem") @ r (two? r ? <(pem-ders <>r) ""))
   tc-now (epoch-days 2026 6 1 * 86400)
   tc-roots (map (n \ x509 (tc-ld n)) ["rootr" "roote" "rootw"])
   (tc host l) (chain-ok? (map tc-ld l) tc-roots host tc-now)
   (tc-flip d i) (snip d 0 i + string (d i ^ 1) + snip d (i + 1) #d)
   (tc-has r s) (string? r && 0 <= str-at r s 0)
   _ (test (tc "good.test" ["leafr" "interr"] = 1)
           (tc "good.test" ["leafe" "intere"] = 1)                ; p-256 under p-384
           (tc "good.test" ["leafw"] = 1)                          ; p-384 under p-521, sha-512
           (tc "good.test" ["leaf512" "interr"] = 1)               ; pkcs#1 over sha-512
           (tc "GOOD.test." ["leafr" "interr"] = 1)                ; case and a trailing dot
           (tc "a.wild.test" ["leafr" "interr"] = 1)
           (tc "127.0.0.1" ["leafr" "interr"] = 1)                 ; an address against iPAddress
           (tc "good.test" ["leafr" "rootr" "interr"] = 1)         ; out of order, its root sent
           (tc "good.test" ["deep" "inter1" "inter0"] != 1)
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
   _ (test (x509-time (string 23 + string 13 + "500101000000Z") [23 2 15 0] = [(0 - 631152000)])
           (x509-time (string 24 + string 15 + "20260601000000Z") [24 2 17 0] = [tc-now])
           !(x509-time (string 23 + string 13 + "260601000000+") [23 2 15 0])
           (dns-match? "*.a.test" "x.a.test") !(dns-match? "*.a.test" "a.test")
           !(dns-match? "x*.a.test" "xy.a.test") !(dns-match? "*.*.test" "a.b.test")
           !(dns-match? "*.test" "a.test") (dns-match? "A.Test" "a.TEST"))
   ; every prefix of a certificate, and every one-byte change, reads without dying
   _ (test (all (n \ !(tablet? (x509 (snip ir 0 n)))) ^#ir)
           (all (i \ (x509 (tc-flip ir i) @ x (atom? x || tablet? x))) ^#ir)))

;; --- name constraints: a root, or an issuer, vouches only for its own names ----------------
(: nc-roots (map (n \ x509 (tc-ld n)) ["rootn" "rootp" "rootm" "rootd"])
   (nc host l) (chain-ok? (map tc-ld l) nc-roots host tc-now)
   rn (x509 (tc-ld "rootn"))
   _ (test (#(rn 'ncp) = 2) (#(rn 'nce) = 1)                      ; sb.test and 10/8; not bad.sb.test
           (nc "a.sb.test" ["leafn"] = 1) (nc "10.1.2.3" ["leafn"] = 1)
           (tc-has (nc "a.sb.test" ["leafno"]) "\"rootn\": the name evil.test is outside the names it may vouch for")
           (tc-has (nc "x.bad.sb.test" ["leafnx"]) "the name x.bad.sb.test is among the names it may not vouch for")
           (tc-has (nc "a.sb.test" ["leafnw"]) "the name *.sb.test is among")    ; the wildcard reaches bad.sb.test
           (nc "a.ok.sb.test" ["leafnw2"] = 1)
           (tc-has (nc "a.sb.test" ["leafni"]) "the name 192.168.1.1 is outside")
           (nc "a.in.test" ["leafin" "intern"] = 1)                        ; an issuer's own constraint
           (tc-has (nc "in.test" ["leafia" "intern"]) "\"intern\": the name in.test is outside")
           (nc "good.test" ["leafm"] = 1)                                  ; email bears on no server name
           (tc-has (nc "good.test" ["leafd"]) "a kind of name not checked here")))

;; --- the tree's roots: mozilla's, the last home, and carried in the binary for a host with none --
(: t (carried-roots 0) f (uread tree-roots)
   ds (string? t ? (pem-ders t)) xs (filter tablet? (map x509 ds))
   _ (test (string? t) (two? f) (<>f = t)                          ; the carried copy is the tree's
           (100 < #xs) (#xs = #ds)                                 ; every root reads
           (all (x \ (x 'ca) = 1) xs)
           (elem ("/proc/src/" + tree-roots) root-homes)))

;; --- the roots: SSL_CERT_FILE names the bundle, read once; the host's own reads whole ----
(: e0 (getenv "SSL_CERT_FILE")
   _ (setenv "SSL_CERT_FILE" "test/host/tlschain/roote.pem")
   r1 (tls-roots 0) r2 (tls-roots 0)
   _ (setenv "SSL_CERT_FILE" "test/host/tlschain/none.pem")
   r3 (tls-roots 0)
   _ (setenv "SSL_CERT_FILE" (string? e0 ? e0 ""))
   hb (filter (p \ two? (stat p)) root-homes)
   hn (two? hb ? (: t (uread <hb) ds (pem-ders <>t) [#ds #(filter tablet? (map x509 ds))]) [1 1])
   _ (test (<r1 = "test/host/tlschain/roote.pem") (#(r1 1) = 1) (r1 1 0 'subject = (x509 (tc-ld "roote")) 'subject)
           (r2 1 = r1 1)                                       ; the same list: read once
           (r3 1 = ())
           (0 < <hn) (<hn = hn 1)))

;; --- der written (cert.l): the reader's inverse, both ways round ----------------------------
(borrow 'bytes)
; a tree encodes and reads back to itself, lengths short and long; every fixture reads to a tree
; that encodes to its own bytes
(: mk-trees [[48 [[2 (string 1)] [4 "abc"] [48 ()] [160 [[6 "x"]]] [3 ""]]]
             [4 (bytes 300 (i \ i & 255))] [48 [[4 (bytes 70000 (i \ 7))]]]
             [49 [[48 [[6 (unhex "550403")] [12 "a name"]]]]] [5 ""]]
   mk-fix (map tc-ld ["rootr" "interr" "leafr" "roote" "leafe" "rootw" "leafw" "rootn" "leafn" "intern" "rootd" "crit"])
   _ (test (all (t \ der-tree (der-enc t) = t) mk-trees)
           (all (d \ der-enc (der-tree d) = d) mk-fix)
           (map (n \ b2hex (der-enc (der-int n))) [0 127 128 255 256 65535]
            = ["020100" "02017f" "02020080" "020200ff" "02020100" "020300ffff"])
           !(der-tree "") !(der-tree (unhex "3003020100ff")) !(der-tree (unhex "3080"))
           ; a time before 2050 is a UTCTime, from 2050 a GeneralizedTime, and x509-time reads both back
           (<(der-time tc-now) = 23) (<(der-time (epoch-days 2050 1 1 * 86400)) = 24)
           (all (s \ x509-time (der-enc (der-time s)) (der (der-enc (der-time s)) 0 20) = [s])
                [0 tc-now (epoch-days 2049 12 31 * 86400 + 86399) (epoch-days 2050 1 1 * 86400) (epoch-days 2100 2 28 * 86400)])))

;; --- p-256 signing (p256.l): rfc 6979 a.2.5, edge scalars, and verify.l's own verifier ----------
; the key, nonces and signatures are the rfc's; every point is held to verify.l's bignum
; arithmetic, a separate implementation; the complete addition to its exceptional cases
(: mk-d (unhex "c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721")
   (mk-hx n) (b2hex (wrbe n 32))
   (mk-sig m) (p256-sign mk-d m @ rs [(mk-hx <rs) (mk-hx (rs 1))])
   mk-n (curve-p256 1) mk-p (curve-p256 0)
   ; d G by verify.l's jacobian ladder, affine
   (mk-ref d) (: q (ec-twin curve-p256 d 0 [1 1 0]) zi (modpow (q 2) (mk-p - 2) mk-p)
                 [(<q * zi * zi % mk-p) (q 1 * zi * zi * zi % mk-p)])
   (mk-b n) (wrbe n 32)
   q (p256-pub mk-d)
   _ (test (mk-hx <q = "60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb6")
           (mk-hx (q 1) = "7903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299")
           (b2hex (p256-nonce mk-d (p2-sha "sample")) = "a6e3c57dd01abe90086538398355dd4c3b17aa873382b0f24d6129493d8aad60")
           (mk-sig "sample" = ["efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716"
                                 "f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8"])
           (b2hex (p256-nonce mk-d (p2-sha "test")) = "d16b6ae827f17175e040871a1c7ec3500192c4c92677336ec2537acaee0008e0")
           (mk-sig "test" = ["f1abb023518351cd71d881567b1ea663ed3efcf6c5132b354f28d3b0b7d38367"
                               "019f4113742a2b14bd25926b49c649155f267e60d3814b4c0cc84250e46f0083"]))
   ; the scalars at the edges of [1, n-1], and a few more, against the reference
   ds [1 2 3 15 16 17 255 256 (1 << 128) (1 << 255) (mk-n - 1) (mk-n - 2) (mk-n // 2) (be-num mk-d)]
   _ (test (all (d \ p256-pub (mk-b d) = mk-ref d) ds)
           (p256-pub (mk-b 1) = [(curve-p256 3) (curve-p256 4)])
           (p256-pub (mk-b (mk-n - 1)) = [(curve-p256 3) (mk-p - curve-p256 4)])
           ; 0 < k < n, by masks
           (map (d \ p2-ok? (mk-b d)) [0 1 (mk-n - 1) mk-n (mk-n + 1) ((1 << 256) - 1)] = [0 1 1 0 0 0]))
   ; the complete addition: the identity either side, a point and its negation, a doubling
   g p2-g o p2-o gn [<g (p2-fs p2-zero (g 1)) (g 2)]
   (mk-aff pt) (pt 2 = p2-zero ? 'o (p2-affine pt))
   _ (test (mk-aff (p2-add o o) = 'o) (mk-aff (p2-add g o) = p2-affine g) (mk-aff (p2-add o g) = p2-affine g)
           (mk-aff (p2-add g gn) = 'o) (mk-aff (p2-add g g) = mk-ref 2))
   ; signatures of fresh keys over several messages verify under verify.l's ec-ok?; a changed
   ; message or signature does not
   (mk-der rs) (der-enc [48 [(der-int <rs) (der-int (rs 1))]])
   ks (map (_ \ key-new 'p256) ^3)
   _ (test (all (k \ (: d (k 1) pt (k 2) m ("m " + show pt)
                        s (mk-der (p256-sign d m))
                        (ec-ok? curve-p256 pt (p2-sha m) s = 1 && ec-ok? curve-p256 pt (p2-sha (m + "!")) s = 0
                         && ec-ok? curve-p256 pt (p2-sha m) (tc-flip s 10) = 0 && p256-pub d = pt)))
                ks)
           (all (k \ p2-ok? (k 1) = 1 && #(k 1) = 32) ks)))

;; --- certificates made (cert.l): an ed25519 root with name constraints over a p-256 issuer ------
; the root may vouch for sb.test and 10/8 but not bad.sb.test; the intermediate has pathLen 0.
; verify.l takes the good chain and refuses each broken rule by the check it breaks
(: mk-now tc-now mk-nb (epoch-days 2025 1 1 * 86400) mk-na (epoch-days 2035 1 1 * 86400)   ; the fixtures' window
   (mk-cert sub key iss ikey ca exts)
    (cert-make {'subject (name-der sub) 'issuer (name-der (string? iss ? iss sub)) 'spki (key-spki key)
                'key (two? ikey ? ikey key) 'nb mk-nb 'na mk-na
                'akid (string? ca ? (cert-kid ca)) 'exts (["subjectKeyIdentifier=hash" "authorityKeyIdentifier=keyid"] + exts)})
   mk-rk (key-new 'ed25519) mk-ik (key-new 'p256) mk-lk (key-new 'p256) mk-ek (key-new 'ed25519)
   mk-root (mk-cert "/CN=sb root/O=svalbard" mk-rk () () ()
                    ["basicConstraints=critical,CA:TRUE" "keyUsage=critical,keyCertSign,cRLSign"
                     "nameConstraints=critical,permitted;DNS:sb.test,permitted;IP:10.0.0.0/8,excluded;DNS:bad.sb.test"])
   mk-inter (mk-cert "/CN=sb issuer" mk-ik "/CN=sb root/O=svalbard" mk-rk mk-root
                     ["basicConstraints=critical,CA:TRUE,pathlen:0" "keyUsage=critical,keyCertSign"])
   (mk-leaf san key) (mk-cert "/CN=a leaf" key "/CN=sb issuer" mk-ik mk-inter
                              ["basicConstraints=critical,CA:FALSE" "keyUsage=critical,digitalSignature"
                               "extendedKeyUsage=serverAuth" ("subjectAltName=" + san)])
   mk-good (mk-leaf "DNS:a.sb.test,DNS:sb.test,IP:10.1.2.3" mk-lk)
   mk-edleaf (mk-leaf "DNS:ed.sb.test" mk-ek)
   mk-bad (mk-leaf "DNS:x.bad.sb.test" mk-lk)
   mk-out (mk-leaf "DNS:a.sb.test,DNS:evil.test" mk-lk)
   mk-ip (mk-leaf "DNS:a.sb.test,IP:192.168.1.1" mk-lk)
   mk-sub (mk-cert "/CN=under" mk-lk "/CN=sb issuer" mk-ik mk-inter ["basicConstraints=critical,CA:TRUE" "keyUsage=keyCertSign"])
   mk-deep (mk-cert "/CN=deep" mk-ek "/CN=under" mk-lk mk-sub ["subjectAltName=DNS:d.sb.test"])
   mk-roots [(x509 mk-root)]
   (mk-ok host l) (chain-ok? l mk-roots host mk-now)
   rx (x509 mk-root) ix (x509 mk-inter) gx (x509 mk-good)
   _ (test (all string? [mk-root mk-inter mk-good mk-edleaf mk-bad mk-out mk-ip mk-sub mk-deep])
           (rx 'ca = 1) (rx 'plen = ()) (rx 'ku = 6 << 24) (#(rx 'ncp) = 2) (#(rx 'nce) = 1) (rx 'bad = ())
           (<(rx 'key) = 'ed25519) (<(ix 'key) = 'p256) (ix 'plen = 0) (rx 'subject = ix 'issuer)
           (gx 'dns = ["a.sb.test" "sb.test"]) (gx 'ips = [(unhex "0a010203")]) (gx 'eku = [oid-server-auth])
           (cert-kid mk-root = key-id (key-spki mk-rk))
           (mk-ok "a.sb.test" [mk-good mk-inter] = 1)
           (mk-ok "10.1.2.3" [mk-good mk-inter] = 1)
           (mk-ok "ed.sb.test" [mk-edleaf mk-inter] = 1)
           (tc-has (mk-ok "x.bad.sb.test" [mk-bad mk-inter]) "the name x.bad.sb.test is among the names it may not vouch for")
           (tc-has (mk-ok "a.sb.test" [mk-out mk-inter]) "the name evil.test is outside the names it may vouch for")
           (tc-has (mk-ok "a.sb.test" [mk-ip mk-inter]) "the name 192.168.1.1 is outside")
           (tc-has (mk-ok "d.sb.test" [mk-deep mk-sub mk-inter]) "\"sb issuer\": its pathLen is exceeded")
           (tc-has (mk-ok "a.sb.test" [(tc-flip mk-good (#mk-good - 3)) mk-inter]) "its signature does not verify")
           (tc-has (mk-ok "a.sb.test" [mk-good]) "no issuer"))
   ; what the extension parser refuses, and says why
   ctx {'kid "k" 'akid "a"}
   _ (test (all (l \ string? (ext-der l ctx))
                ["keyUsage=keyCertSign,bogus" "basicConstraints=CA:TRUE,pathlen:x" "subjectAltName=DNS:"
                 "subjectAltName=IP:1.2.3" "nameConstraints=permitted;IP:10.0.0.0" "nameConstraints=allowed;DNS:x"
                 "noSuchExtension=1" "subjectKeyIdentifier=abc" "extendedKeyUsage=serverAuth,nope"])
           (ext-der "subjectAltName=IP:::1,IP:fe80::1:2" ctx 1 = der-enc [48 [[6 oid-san] [4 (der-enc [48 [[135 (unhex "00000000000000000000000000000001")] [135 (unhex "fe800000000000000000000000010002")]]])]]])
           (ip-net "10.0.0.0/8" = unhex "0a000000ff000000") (ip-net "10.0.0.0/255.255.0.0" = unhex "0a000000ffff0000")
           (ip-net "192.168.1.0/23" = unhex "c0a80100fffffe00") !(ip-net "10.0.0.0/33") !(name-der "/XX=1"))
   ; a request: made, read back with its signature checked, refused with one byte changed
   csr (csr-make mk-lk (name-der "/CN=req") ["subjectAltName=DNS:r.sb.test"])
   cr (csr-read csr)
   _ (test (tablet? cr) (cr 'spki = key-spki mk-lk) (cr 'subject = name-der "/CN=req") (#(cr 'exts) = 1)
           (csr-read (tc-flip csr (#csr - 2)) = "the request's signature does not verify")
           (string? (csr-read "junk")))
   ; the keys, out and back
   _ (test (all (k \ key-read (key-pem k) = k) [mk-rk mk-ik mk-lk]) !(key-read "junk")
           (key-read (key-der mk-ik) = mk-ik))

   ;; --- the host's openssl (where it is) verifies and parses what is made here, and hands keys
   ; and a request of its own to be signed; its keys come from its genpkey, never the host's store
   os? (two? (stat "/usr/bin/openssl"))
   dir (cwd 0 + "/out/.tlsca-" + show (getpid 0))
   (put nm s) (open (dir + "/" + nm) "w" @ q (say q s, close q))
   (osh c) (hark ["sh" "-c" ("cd " + dir + " && " + c + " 2>&1")])
   (sees r s) (two? r && tc-has >r s)
   ((os? ?
       (: _ (hark ["mkdir" "-p" dir])
          _ (each [["root.pem" mk-root] ["inter.pem" mk-inter] ["good.pem" mk-good] ["ed.pem" mk-edleaf]
                   ["bad.pem" mk-bad] ["out.pem" mk-out] ["deep.pem" mk-deep] ["sub.pem" mk-sub]]
                  (e \ put <e (pem-out "CERTIFICATE" (e 1))))
          _ (put "chain.pem" (pem-out "CERTIFICATE" mk-inter + pem-out "CERTIFICATE" mk-sub))
          _ (put "p256.key" (key-pem mk-ik))
          _ (put "ed.key" (key-pem mk-rk))
          v (osh "openssl verify -CAfile root.pem -untrusted inter.pem good.pem ed.pem")
          vb (osh "openssl verify -CAfile root.pem -untrusted inter.pem bad.pem")
          vo (osh "openssl verify -CAfile root.pem -untrusted inter.pem out.pem")
          vd (osh "openssl verify -CAfile root.pem -untrusted chain.pem deep.pem")
          t (osh "openssl x509 -in root.pem -noout -text")
          tl (osh "openssl x509 -in good.pem -noout -text")
          pk (osh "openssl pkey -in p256.key -pubout -outform DER | od -An -tx1 | tr -d ' \\n'")
          pe (osh "openssl pkey -in ed.key -pubout -outform DER | od -An -tx1 | tr -d ' \\n'")
          ; a raw p-256 signature over a message, openssl's dgst the verifier
          _ (put "msg" "a message for openssl")
          _ (put "sig.der" (mk-der (p256-sign (mk-ik 1) "a message for openssl")))
          _ (put "pub.pem" (pem-out "PUBLIC KEY" (key-spki mk-ik)))
          dv (osh "openssl dgst -sha256 -verify pub.pem -signature sig.der msg")
          ; openssl's own keys and request, signed here
          _ (osh "openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out h.key && openssl genpkey -algorithm ed25519 -out he.key && openssl req -new -key h.key -subj /CN=host -addext subjectAltName=DNS:h.sb.test -out h.csr")
          hk (key-read (uread (dir + "/h.key") @ r (two? r ? <>r "")))
          hek (key-read (uread (dir + "/he.key") @ r (two? r ? <>r "")))
          hr (csr-read <(pem-in (uread (dir + "/h.csr") @ r (two? r ? <>r "")) "CERTIFICATE REQUEST"))
          hc (tablet? hr ? (cert-make {'subject (hr 'subject) 'issuer (name-der "/CN=sb issuer") 'spki (hr 'spki) 'key mk-ik
                                      'nb mk-nb 'na mk-na 'akid (cert-kid mk-inter)
                                      'exts (["basicConstraints=critical,CA:FALSE"] + map ext-pair (hr 'exts))}))
          hx (two? hk ? (cert-make {'subject (name-der "/CN=host key") 'issuer (name-der "/CN=host key") 'spki (key-spki hk)
                                    'key hk 'nb mk-nb 'na mk-na 'exts ["basicConstraints=critical,CA:TRUE"]}))
          hy (two? hek ? (cert-make {'subject (name-der "/CN=host ed") 'issuer (name-der "/CN=host ed") 'spki (key-spki hek)
                                     'key hek 'nb mk-nb 'na mk-na 'exts ["basicConstraints=critical,CA:TRUE"]}))
          _ (put "h.pem" (string? hc ? (pem-out "CERTIFICATE" hc) ""))
          _ (put "hx.pem" (string? hx ? (pem-out "CERTIFICATE" hx) ""))
          _ (put "hy.pem" (string? hy ? (pem-out "CERTIFICATE" hy) ""))
          vh (osh "openssl verify -CAfile root.pem -untrusted inter.pem h.pem")
          vx (osh "openssl verify -CAfile hx.pem hx.pem && openssl verify -CAfile hy.pem hy.pem")
          (hark ["rm" "-rf" dir],
           test (sees v "good.pem: OK") (sees v "ed.pem: OK")
                (sees vb "excluded subtree violation") (sees vo "permitted subtree violation")
                (sees vd "path length constraint exceeded")
                (sees t "X509v3 Name Constraints: critical") (sees t "Permitted:") (sees t "DNS:sb.test")
                (sees t "IP:10.0.0.0/255.0.0.0") (sees t "Excluded:") (sees t "DNS:bad.sb.test")
                (sees t "CA:TRUE") (sees t "Certificate Sign, CRL Sign") (sees t "Signature Algorithm: ED25519")
                (sees tl "ecdsa-with-SHA256") (sees tl "DNS:a.sb.test, DNS:sb.test, IP Address:10.1.2.3")
                (sees tl "TLS Web Server Authentication")
                (two? pk && >pk = b2hex (key-spki mk-ik)) (two? pe && >pe = b2hex (key-spki mk-rk))
                (sees dv "Verified OK")
                (two? hk && hk 0 = 'p256) (two? hek && hek 0 = 'ed25519) (tablet? hr) (string? hc)
                (sees vh "h.pem: OK") (sees vx "hx.pem: OK") (sees vx "hy.pem: OK")))
       0),
    0))

; the harness greps for this line, and that is the point: a reader stop exits 0
; with the asserts above never read, so only reaching here proves the file ran.
(test_fin (),
 puts "src/apps/tls: ok -- chacha20 + poly1305 (rfc 8439 block, stream, counter, cipher, mac); the handshake's verify; certificates made (der, ed25519, p-256 by rfc 6979)
",
 0)
