; apps/tls/client.l -- a TLS 1.3 client over the ciphers beside it: x25519 for the key
; share, HKDF-SHA256 for the schedule, and the records under chacha20-poly1305 or, when the
; server picks it, aes-128-gcm (love/lib/tls.c's nifs) -- the one suite RFC 8446 makes every
; server speak. one group, one version, the two suites; a key's length says which cipher
; it is for (32 bytes chacha, 16 aes).
;
; what is verified: the handshake. the server's CertificateVerify must be its leaf key's
; signature of the transcript (ed25519, ecdsa p-256/sha-256 or p-384/sha-384, rsa-pss/sha-256 or sha-384;
; apps/tls/verify.l), and its Finished the hmac of the transcript under the handshake
; secret, so the peer holds the private key of the certificate it sent and saw the same
; handshake we did. what is NOT verified: the certificate itself -- no chain to a trusted
; root, no check of the name against the host, no expiry. any key signs for any name here,
; so this proves "the same key as before" (a pin) and never "the host we asked for".
;
;   (tls-dial host port)   resolve, connect, shake hands -> a session | ()
;   (tls-say t s)          send s as application data
;   (tls-slurp t)          every byte of application data the peer sends, to its close
;   (tls-close t)          a close_notify, and the socket shut
;   (t 'cert)              the server's leaf certificate, its der, as it came
;   (t 'spki)              its SubjectPublicKeyInfo, the der of the key that signed
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
             (tag = po-mac pk (aad + pad16 aad + ct + pad16 ct + u64le #aad + u64le #ct)
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
   (alert t d) (seal t 21 (u8 2 + u8 d), ())
   ; one record in: a plaintext CCS is skipped, an encrypted one opened under the server's
   ; key -> (inner-type body) | () at the end or on a bad tag
   (open-rec t)
    (: r (rdrec t)
       (? (atom? r) ()
          (<r = 20) (open-rec t)
          (<r != 23) ()
          (: body <>r
             aad (u8 23 + u16 771 + u16 #body)
             pt (aead-open (t 'skey) (t 'siv) (t 'sseq) aad body)
             _ (pin t 'sseq (t 'sseq + 1))
             (? (atom? pt) ()
                (: s <>pt
                   (strip i) (i > 0 && s (i - 1) = 0 ? (strip (i - 1)) i)
                   e (strip #s)
                   (e < 1 ? () [(s (e - 1)) (snip s 0 (e - 1))]))))))

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
                         (go buf))))
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

   ; --- the handshake, whole ---
   (tls-dial host port)
    (: s (dial host port)
       (? !(hot? s) ()
          (: t (tablet 16)
             _ (pin t 's s) _ (pin t 'pend "") _ (pin t 'hbuf "") _ (pin t 'tr "")
             _ (pin t 'cseq 0) _ (pin t 'sseq 0)
             priv (rnd 32)
             ch (client-hello host (x25519-pub priv) (rnd 32))
             _ (pin t 'tr ch)
             _ (wr t (u8 22 + u16 769 + u16 #ch + ch))
             r (rdrec t)
             (? (atom? r || <r != 22 || <>r 0 != 2) (close s, ())
                (: sh <>r
                   _ (pin t 'tr (t 'tr + sh))
                   ss (server-share (snip sh 4 #sh))
                   (? (atom? ss) (close s, ())
                      (: share <ss kl <>ss
                         shared (x25519 priv share)
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
                                 (? (t 'cv = 1 && <>m = hmac (hkdf-label shs "finished" "" 32) (sha tb)) m
                                    (alert t 51))
                                (<m = 11)
                                 (: b <>m i (? (8 <= #b) (1 + b 0) #b)
                                    n (? (i + 6 <= #b) (rd24 b (i + 3)) 0)
                                    k (leaf-key (snip b (i + 6) (i + 6 + n)))
                                    (? (two? k && !(t 'key))
                                       (pins t 'cert (snip b (i + 6) (i + 6 + n)) 'key k 'spki (k 2), flight 0)
                                       (alert t 42)))
                                (<m = 15)
                                 (: b <>m n (? (4 <= #b) (rd16 b 2) -1) k (t 'key)
                                    (? (two? k && #b = 4 + n && !(t 'cv)
                                        && cv-ok? k (rd16 b 0) (snip b 4 #b) (cv-msg (sha tb)) = 1)
                                       (pin t 'cv 1, flight 0)
                                       (alert t 51)))
                                ; a request for our certificate: its context kept
                                (<m = 13) (pin t 'creq (snip <>m 1 (1 + <>m 0)), flight 0)
                                (flight 0)))
                         fin (flight 0)
                         (? (atom? fin) (close s, ())
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
                               _ (pin t 'cseq 0) _ (pin t 'sseq 0)
                               t)))))))))

   ; --- the application half ---
   (tls-say t s)
    (: n #s
       (go i) (? (n <= i) 0
                 (: k (n - i < 16384 ? (n - i) 16384)
                    _ (seal t 23 (snip s i (i + k)))
                    (go (i + k))))
       (go 0))
   (tls-slurp t)
    (: j (jug 0)
       (go _) (: r (open-rec t)
                 (? (atom? r) 0
                    (<r = 23) (say j <>r, go 0)
                    (<r = 21) 0                                        ; an alert: close_notify or worse, the end either way
                    (go 0)))                                            ; a ticket, a key update: not ours
       _ (go 0)
       (slurp j))
   (tls-close t) (seal t 21 (u8 1 + u8 0), close (t 's)))
) ; module tls
