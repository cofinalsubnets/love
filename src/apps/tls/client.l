; src/apps/tls/client.l -- a TLS 1.3 client over the ciphers beside it: x25519 for the key
; share, HKDF-SHA256 for the schedule, and the records under chacha20-poly1305 or, when the
; server picks it, aes-128-gcm (src/love/lib/tls.c's nifs) -- the one suite RFC 8446 makes every
; server speak. one group, one version, the two suites; a key's length says which cipher
; it is for (32 bytes chacha, 16 aes).
;
; what is verified, by default: the handshake -- the server's CertificateVerify under its
; leaf key (ed25519, ecdsa p-256/sha-256 or p-384/sha-384, rsa-pss/sha-256 or sha-384) and
; its Finished under the handshake secret -- and the certificate, before a byte goes out: a
; path from the leaf to a root in the host's bundle (verify.l's chain-ok?: every signature,
; every date, the issuers' roles, the host's name in subjectAltName). no revocation is
; checked. a line in ~/.love/tls_pins, "host:port spki:<sha-256>", answers for that
; host:port instead of the roots -- a self-signed or private server -- and a key other than
; the pinned one is refused. a refusal says which check, and which certificate.
;
;   (tls-dial host port)       resolve, connect, shake hands, verify -> a session | ()
;   (tls-open host port how)   the same -> a session | why not, a string. how: 'verify, or
;                              'pin-only (the caller holds the pin: gemini), or 'none
;   (tls-open-as host port sni how)   the same, sni the name said and checked
;   (tls-on s sni port how)    the same over a socket already connected (STARTTLS)
;   (tls-say t s)              send s as application data
;   (tls-hear t)               the next run of application data as it arrives, () at the
;                              peer's close_notify, a nom for a stream cut or forged, (t 'why)
;                              the reason
;   (tls-slurp t)              every byte of application data the peer sends to its
;                              close_notify, else tls-hear's nom
;   (tls-close t)              a close_notify, and the socket shut
;   (t 'chain)                 the server's certificates, ders, leaf first, as they came
;   (t 'cert) (t 'spki)        the leaf's der, and its SubjectPublicKeyInfo's
;
; the session is a tablet: the socket, a pending-bytes run, the two traffic keys and their
; sequence numbers, the transcript. x25519 rides the bignums (RFC 7748's ladder, the field
; by `%` and `//` -- bit ops on bigs are not a floor this tree stands on yet), which is
; milliseconds for one handshake.
(module 'tls
(borrow 'dns)
(borrow 'posix)
(borrow 'bytes)

(:
   ; --- bytes and words ---
   (u8 v) (string (v & 255))
   (u16 v) (wrbe v 2)
   (u24 v) (wrbe v 3)
   (u32 v) (wrbe v 4)
   (rd16 s i) (rdbe s i 2)
   (rd24 s i) (rdbe s i 3)
   (zeros n) (zbytes n)
   (xors a b) (xorb a b)
   ; equal strings, in time that does not hang on where they differ
   (ct-same? a b) (: d (xors a b) (go i acc) (? (i < #d) (go (i + 1) (acc | d i)) acc)
                  (#a = #b && go 0 0 = 0))
   ; a small count as eight bytes, either end first
   (u64le n) (bytes 8 (i \ (n >> (8 * i)) & 255))
   (u64be n) (wrbe n 8)
   (pad16 s) (zeros ((16 - (#s % 16)) % 16))

   ; --- the hash floor: sha256 raw, hmac, hkdf ---
   (sha s) (unhex (sha256 s))
   (hmac k m) (: kp (k + zeros (64 - #k))
                 (sha ((xors kp (bytes 64 (i \ 92))) + sha ((xors kp (bytes 64 (i \ 54))) + m))))
   (hkdf-extract salt ikm) (hmac salt ikm)
   (hkdf-label secret label ctx n)                                   ; HKDF-Expand-Label, n <= 32
    (: lab ("tls13 " + label)
       info (u16 n + u8 #lab + lab + u8 #ctx + ctx)
       (snip (hmac secret (info + u8 1)) 0 n))
   (derive secret label tr) (hkdf-label secret label (sha tr) 32)

   ; --- x25519 ---
   p25519 ((255 2) - 19)
   (fmod a) ((a % p25519 + p25519) % p25519)                        ; % truncates: fold a negative back in
   (fmul a b) (fmod (a * b))
   (finv a) (modpow a (p25519 - 2) p25519)
   (le-num s) (: (go i a) (i < 0 ? a (go (i - 1) (a * 256 + s i))) (go (#s - 1) 0))
   (le-bytes n) (bytes 32 (i \ n // (8 * i) 2 % 256))
   (kbit k t) (k // t 2 % 2)                                       ; bit t of the scalar
   ; the ladder, RFC 7748 section 5: the state is (x2 z2 x3 z3), swapped by the scalar's bits
   (ladder k u)
    (: a24 121665
       (step st t)
        (: x2 <st z2 <>st x3 (st 2) z3 (st 3)
           a (fmod (x2 + z2)) aa (fmul a a) b (fmod (x2 - z2)) bb (fmul b b) e (fmod (aa - bb))
           c (fmod (x3 + z3)) d (fmod (x3 - z3)) da (fmul d a) cb (fmul c b)
           s1 (fmod (da + cb)) s2 (fmod (da - cb))
           [(fmul aa bb) (fmul e (fmod (aa + (a24 * e)))) (fmul s1 s1) (fmul u (fmul s2 s2))])
       (swap st) [(st 2) (st 3) <st <>st]
       (go t st sw)
        (? (t < 0) (sw ? (swap st) st)
           (: kt (kbit k t)
              st2 (sw ^ kt = 1 ? (swap st) st)
              (go (t - 1) (step st2 t) kt)))
       r (go 254 [1 0 u 1] 0)
       (fmul <r (finv <>r)))
   (x25519 k u)
    (: kk (bytes 32 (i \ (? (i = 0) (k 0 & 248) (i = 31) ((k 31 & 127) | 64) (k i))))
       uu (le-num u % (255 2))
       (le-bytes (ladder (le-num kk) uu)))
   (x25519-pub k) (x25519 k (bytes 32 (i \ (i = 0 ? 9 0))))

   (rnd n) (: q (open "/dev/urandom" "r")                ; no entropy is a scare, never a constant
              _ (? (nom? q) (scare 'no-entropy q) 0)
              (byte i) (: c (see q) (? (c < 0) (close q, scare 'no-entropy "/dev/urandom") c))
              b (bytes n byte)
              (close q, b))

   ; --- the aead: RFC 8439's, the poly key block zero of the stream; or aes-gcm's nifs ---
   (nonce iv seq) (xors iv (zeros 4 + u64be seq))
   (aead-seal key iv seq aad pt)
    (? (#key = 16) (aes-gcm-seal key (nonce iv seq) aad pt)
    (: nn (nonce iv seq)
       pk (snip (cc-stream key nn 0 1) 0 32)
       ct (cc-xor key nn 1 pt)
       (ct + po-mac pk (aad + pad16 aad + ct + pad16 ct + u64le #aad + u64le #ct))))
   (aead-open key iv seq aad ctag)
    (? (#key = 16) (: p (aes-gcm-open key (nonce iv seq) aad ctag) (string? p ? [1 p] ()))
    (: n (#ctag - 16)
       (? (n < 0) ()
          (: nn (nonce iv seq)
             pk (snip (cc-stream key nn 0 1) 0 32)
             ct (snip ctag 0 n)
             tag (snip ctag n #ctag)
             (ct-same? tag (po-mac pk (aad + pad16 aad + ct + pad16 ct + u64le #aad + u64le #ct))
               ? [1 (cc-xor key nn 1 ct)] ())))))

   ; --- the wire: exact reads over the socket, a run kept between records ---
   (rd t n)
    (: (go acc have) (? (n <= have) (join "" (rev acc))       ; chunks kept in a list, joined once -- no per-read recopy
                        (: c (see (t 's))
                           (? (c = -1) ()
                              (: piece (string c + chug (t 's)) (go (piece . acc) (have + #piece))))))
       p (t 'pend)
       got (go (0 < #p ? [p] ()) #p)
       (? !(string? got) ()
          (pin t 'pend (snip got n #got), [1 (snip got 0 n)])))
   (rdrec t)                                                           ; -> (type body) | ()
    (: h (rd t 5)
       (? (atom? h) ()
          (: hdr <>h
             b (rd t (rd16 hdr 3))
             (? (atom? b) () [(hdr 0) <>b]))))
   (wr t s) (say (t 's) s, flush (t 's))
   ; one encrypted record out under the client's current key; type rides the inner tail
   (seal t type pt)
    (: inner (pt + u8 type)
       aad (u8 23 + u16 771 + u16 (#inner + 16))
       ct (aead-seal (t 'ckey) (t 'civ) (t 'cseq) aad inner)
       _ (pin t 'cseq (t 'cseq + 1))
       (wr t (aad + ct)))
   ; a fatal alert under the client's current key, and no session
   (alert t d why) (pin t 'why why, seal t 21 (u8 2 + u8 d), ())
   ; the read side dead for good: the nom kept and answered, the reason said, an alert sent
   ; when d names one
   (rd-fail t nm d why) (pins t 'dead nm 'why why, (0 < d ? (seal t 21 (u8 2 + u8 d)) 0), nm)
   ; one record in, opened under the server's key -> (inner-type body), () after a
   ; close_notify, or rd-fail's nom: an end with no close_notify, a plaintext record but a
   ; CCS before the handshake is done, a bad tag
   (open-rec t)
    (: r (? (t 'done || t 'dead) () (rdrec t))
       (? (t 'done) ()
          (t 'dead) (t 'dead)
          (atom? r) (rd-fail t 'eof 0 "the peer closed the connection without a close_notify")
          (<r = 20 && !(t 'up) && <>r = u8 1) (open-rec t)
          (<r != 23) (rd-fail t 'bad 10 "a plaintext record where only encrypted ones may come")
          (: body <>r
             aad (u8 23 + u16 771 + u16 #body)
             pt (aead-open (t 'skey) (t 'siv) (t 'sseq) aad body)
             _ (pin t 'sseq (t 'sseq + 1))
             (? (atom? pt) (rd-fail t 'bad 20 "a record whose tag does not verify")
                (: s <>pt
                   (strip i) (i > 0 && s (i - 1) = 0 ? (strip (i - 1)) i)
                   e (strip #s)
                   (e < 1 ? (rd-fail t 'bad 10 "a record with no content type") [(s (e - 1)) (snip s 0 (e - 1))]))))))
   ; an alert heard: close_notify ends the stream, user_canceled waits for it, the rest refuse
   (alert-in t b)
    (? (#b = 2 && b 1 = 0) (pin t 'done 1, ())
       (#b = 2 && b 1 = 90) [1]
       (rd-fail t 'alert 0 ("the peer sent alert " + show (#b = 2 ? (b 1) -1))))

   ; --- handshake messages off the decrypted stream, each added to the transcript ---
   (hs-next t)
    (: (go buf) (? (4 <= #buf && 4 + rd24 buf 1 <= #buf)
                   (: n (4 + rd24 buf 1)
                      msg (snip buf 0 n)
                      _ (pin t 'hbuf (snip buf n #buf))
                      _ (pin t 'tr (t 'tr + msg))
                      [(buf 0) (snip msg 4 n)])
                   (: r (open-rec t)
                      (? (atom? r) ()
                         (<r = 22) (go (buf + <>r))
                         (<r = 21) (: a (alert-in t <>r) (? (two? a) (go buf) ()))
                         (rd-fail t 'bad 10 "application data before the handshake is done"))))
       (go (t 'hbuf)))

   ; --- the client hello ---
   (ext type body) (u16 type + u16 #body + body)
   (client-hello host pub sid)
    (: sni (ext 0 (u16 (#host + 3) + u8 0 + u16 #host + host))
       groups (ext 10 (u16 2 + u16 29))
       ; what a CertificateVerify may use is what verify.l checks: ecdsa p-256 and p-384, rsa-pss, ed25519.
       ; the chain's own signatures are named apart (50), so the server's pick of a leaf is not narrowed
       sigs (ext 13 (u16 10 + u16 1027 + u16 1283 + u16 2052 + u16 2053 + u16 2055))
       csigs (ext 50 (u16 12 + u16 1027 + u16 2052 + u16 1025 + u16 2055 + u16 2053 + u16 1281))
       vers (ext 43 (u8 2 + u16 772))
       modes (ext 45 (u8 1 + u8 1))
       share (ext 51 (u16 36 + u16 29 + u16 32 + pub))
       exts (sni + groups + sigs + csigs + vers + modes + share)
       body (u16 771 + rnd 32 + u8 32 + sid + u16 4 + u16 4867 + u16 4865 + u8 1 + u8 0 + u16 #exts + exts)
       (u8 1 + u24 #body + body))
   ; the server hello's key share and the key length of its suite (32 chacha20, 16 aes-128),
   ; its version checked: () for any hello we cannot use
   (server-share body)
    (: sidn (body 34)
       i (35 + sidn)
       suite (rd16 body i)
       extn (rd16 body (i + 3))
       (go j end share ok)
        (? (j + 4 > end) (ok && string? share ? [share (suite = 4865 ? 16 32)] ())
           (: ty (rd16 body j) ln (rd16 body (j + 2)) d (snip body (j + 4) (j + 4 + ln))
              (go (j + 4 + ln) end
                  (ty = 51 && rd16 d 0 = 29 && rd16 d 2 = 32 ? (snip d 4 36) share)
                  (ty = 43 && rd16 d 0 = 772 ? 1 ok))))
       (? !(suite = 4867 || suite = 4865) ()
          (go (i + 5) (i + 5 + extn) () 0)))

   ; the Certificate message's list -> its ders, leaf first, or () for one that does not tile
   (cert-list b)
    (: cx (? (0 < #b) (b 0) -1) i (1 + cx)
       (go j acc k)
        (? (j = #b) (rev acc)
           (16 < k || #b < j + 5) ()
           (: n (rd24 b j) e (j + 3 + n) xl (? (e + 2 <= #b) (rd16 b e) -1)
              (? (xl < 0 || #b < e + 2 + xl) () (go (e + 2 + xl) (snip b (j + 3) e . acc) (k + 1)))))
       (? (cx < 0 || #b < i + 3 || rd24 b i != #b - i - 3) () (go (i + 3) () 0)))
   ; a failed dial: the socket shut, and the reason, the first one said
   (quit-why t d) (close (t 's), (? (string? (t 'why)) (t 'why) d))

   ; --- the pins: a line "host:port spki:<sha-256 of the key's SubjectPublicKeyInfo>" a key.
   ; ~/.love/tls_pins is the override for a server no root vouches for; www's gemini trust on
   ; first use writes the same lines to ~/.love/gemini_hosts ---
   (pin-path nm) (: h (getenv "HOME") ((? (string? h) h ".") + "/.love/" + nm))
   (pin-of path key)
    (: txt (uread path @ [1 s] s "")
       (find l) (? (atom? l) () (: f (split " " <l) (? (1 < #f && <f = key) (f 1) (find >l))))
       (find (split "\n" txt)))
   (spki-pin spki) ("spki:" + sha256 spki)
   ; () when the peer is to be believed, else why not, with the line that would pin it
   (trust-why host port chain spki how)
    (: key (host + ":" + show port) fp (spki-pin spki)
       file (pin-path "tls_pins") pin (pin-of file key)
       (? (how != 'verify) ()
          (string? pin) (? (pin = fp) () ("the key of " + key + " is not the one pinned in " + file
                                          + " (pinned " + pin + ", offered " + fp + ")"))
          (: rs (tls-roots 0) r (chain-ok? chain (rs 1) host (clock 0 // 1000))
             (? (r = 1) ()
                ((? (atom? (rs 1))
                     ("no root certificates to check " + key + " against"
                      + (? (string? <rs) (" (" + <rs + " has none that read)") " (no bundle here; SSL_CERT_FILE names one)"))
                     ("the certificate of " + key + " is not trusted: " + r))
                 + "; to trust this key for " + key + " anyway, add the line \"" + key + " " + fp + "\" to " + file)))))

   ; --- the handshake, whole ---
   (tls-dial host port) (: r (tls-open host port 'verify) (? (tablet? r) r ()))
   ; how: 'verify (the chain to a root, or a pin), 'pin-only (the caller pins: gemini), 'none
   (tls-open host port how) (tls-open-as host port host how)
   ; ..naming sni to the server, and checking the certificate against it, not host
   (tls-open-as host port sni how)
    (dial host port @ s (hot? s ? (tls-on s sni port how) ("cannot connect to " + host + ":" + show port)))
   ; ..over a socket already connected, the way STARTTLS asks
   (tls-on s sni port how)
    (: t (tablet 16)
       _ (pin t 's s) _ (pin t 'pend "") _ (pin t 'hbuf "") _ (pin t 'tr "")
       _ (pin t 'cseq 0) _ (pin t 'sseq 0)
       priv (rnd 32)
       ch (client-hello sni (x25519-pub priv) (rnd 32))
       _ (pin t 'tr ch)
       _ (wr t (u8 22 + u16 769 + u16 #ch + ch))
       r (rdrec t)
       (? (atom? r || <r != 22 || <>r 0 != 2) (quit-why t "the server did not answer with a tls 1.3 hello")
          (: sh <>r
             _ (pin t 'tr (t 'tr + sh))
             ss (server-share (snip sh 4 #sh))
             (? (atom? ss) (quit-why t "the server chose nothing this client speaks")
                (: share <ss kl <>ss
                   shared (x25519 priv share)
                   weak (shared = zeros 32)                              ; RFC 8446 7.4.2: a small-order share
                   early (hkdf-extract (zeros 32) (zeros 32))
                   hs (hkdf-extract (derive early "derived" "") shared)
                   chs (derive hs "c hs traffic" (t 'tr))
                   shs (derive hs "s hs traffic" (t 'tr))
                   _ (pin t 'ckey (hkdf-label chs "key" "" kl)) _ (pin t 'civ (hkdf-label chs "iv" "" 12))
                   _ (pin t 'skey (hkdf-label shs "key" "" kl)) _ (pin t 'siv (hkdf-label shs "iv" "" 12))
                   ; the server's flight: extensions, the certificate, its verify, finished.
                   ; the leaf is kept as 'cert (its der) and its key as 'spki; the verify
                   ; must be the leaf key's signature of the transcript through the
                   ; certificate, and the finished the hmac of the transcript through the
                   ; verify under the server's finished key. anything else ends the dial
                   (flight _)
                    (: tb (t 'tr) m (hs-next t)
                       (? (atom? m) ()
                          (<m = 20)
                           (? (t 'cv = 1 && ct-same? <>m (hmac (hkdf-label shs "finished" "" 32) (sha tb))) m
                              (alert t 51 "the server's Finished does not verify"))
                          (<m = 11)
                           (: ds (cert-list <>m)
                              k (? (two? ds) (leaf-key <ds) ())
                              (? (two? k && !(t 'key))
                                 (pins t 'chain ds 'cert <ds 'key k 'spki (k 2), flight 0)
                                 (alert t 42 "the server's certificate does not read")))
                          (<m = 15)
                           (: b <>m n (? (4 <= #b) (rd16 b 2) -1) k (t 'key)
                              (? (two? k && #b = 4 + n && !(t 'cv)
                                  && cv-ok? k (rd16 b 0) (snip b 4 #b) (cv-msg (sha tb)) = 1)
                                 (pin t 'cv 1, flight 0)
                                 (alert t 51 "the server's CertificateVerify does not verify under its certificate's key")))
                          ; a request for our certificate: its context kept
                          (<m = 13) (pin t 'creq (snip <>m 1 (1 + <>m 0)), flight 0)
                          (flight 0)))
                   fin (? weak (pin t 'why "the server's key share is of small order", ()) (flight 0))
                   why (? (atom? fin) () (trust-why sni port (t 'chain) (t 'spki) how))
                   (? (atom? fin) (quit-why t "the handshake failed")
                      (string? why) (: _ (alert t (? (0 <= str-at why "pinned" 0) 42 48) why) (quit-why t why))
                      (: ; the client finished is over the transcript through the server's
                         ; asked for one, we send an empty certificate (we have none),
                         ; and our finished covers it; the traffic keys stop at the server's
                         tr0 (t 'tr)
                         cx (t 'creq)
                         ccert (? (string? cx) (: b (u8 #cx + cx + u24 0) (u8 11 + u24 #b + b)) "")
                         fkey (hkdf-label chs "finished" "" 32)
                         vd (hmac fkey (sha (tr0 + ccert)))
                         cfin (u8 20 + u24 32 + vd)
                         _ (wr t (u8 20 + u16 771 + u16 1 + u8 1))          ; a CCS for the middleboxes
                         _ (0 < #ccert ? (seal t 22 ccert) 0)
                         _ (seal t 22 cfin)
                         master (hkdf-extract (derive hs "derived" "") (zeros 32))
                         cats (derive master "c ap traffic" tr0)
                         sats (derive master "s ap traffic" tr0)
                         _ (pin t 'ckey (hkdf-label cats "key" "" kl)) _ (pin t 'civ (hkdf-label cats "iv" "" 12))
                         _ (pin t 'skey (hkdf-label sats "key" "" kl)) _ (pin t 'siv (hkdf-label sats "iv" "" 12))
                         _ (pins t 'cseq 0 'sseq 0 'cats cats 'sats sats 'up 1)
                         t)))))))

   ; --- the application half ---
   (tls-say t s)
    (: n #s
       (go i) (? (n <= i) 0
                 (: k (n - i < 16384 ? (n - i) 16384)
                    _ (seal t 23 (snip s i (i + k)))
                    (go (i + k))))
       (go 0))
   (tls-hear t)
    (: r (open-rec t)
       (? (atom? r) r
          (<r = 23) <>r
          (<r = 21) (: a (alert-in t <>r) (? (two? a) (tls-hear t) a))
          (<r = 22) (post-hs t (t 'hbuf + <>r))
          (rd-fail t 'bad 10 "a record of no type this client knows")))
   ; the handshake messages after it: a ticket passed over (no resumption here), a key update
   ; taken, which must end its record (RFC 8446 5.1), the rest refused
   (post-hs t buf)
    (? (4 <= #buf && 4 + rd24 buf 1 <= #buf)
       (: n (4 + rd24 buf 1) m (snip buf 4 n) more (snip buf n #buf)
          (? (buf 0 = 4) (post-hs t more)
             (buf 0 != 24) (rd-fail t 'bad 10 "a handshake message after the handshake")
             (#m = 1 && m 0 < 2 && #more = 0) (key-step t (m 0), pin t 'hbuf "", tls-hear t)
             (rd-fail t 'bad 47 "a key update that does not read")))
       (pin t 'hbuf buf, tls-hear t))
   ; RFC 8446 4.6.3: the server's key steps on; asked to, ours does too, said under the old one
   (key-step t ask)
    (: kl #(t 'skey)
       ss (hkdf-label (t 'sats) "traffic upd" "" 32)
       _ (pins t 'sats ss 'skey (hkdf-label ss "key" "" kl) 'siv (hkdf-label ss "iv" "" 12) 'sseq 0)
       (? (ask = 1)
          (: _ (seal t 22 (u8 24 + u24 1 + u8 0))
             cs (hkdf-label (t 'cats) "traffic upd" "" 32)
             (pins t 'cats cs 'ckey (hkdf-label cs "key" "" kl) 'civ (hkdf-label cs "iv" "" 12) 'cseq 0))
          0))
   (tls-slurp t)
    (: j (jug 0)
       (go _) (: s (tls-hear t) (? (string? s) (say j s, go 0) s))
       e (go 0)
       (? (nom? e) e (slurp j)))
   (tls-close t) (seal t 21 (u8 1 + u8 0), close (t 's)))
) ; module tls
