; src/apps/tls/cert.l -- certificates made here: der written, keys, extensions, the signature.
;
;   (der-enc x)              a node's der. a node is [tag body], the body a string (the
;                            content) or a list of nodes; a bare string is der already written
;   (der-tree s)             s as one node, every constructed tag read to its children -> node | ()
;                            (der-tree (der-enc x)) = x for a node whose constructed bodies are lists
;   (key-new kind)           a fresh key: ['ed25519 seed pub], or ['p256 d [x y]]
;   (key-pem k) (key-read t) pkcs#8 out as pem, and back from pem or der -> key | ()
;   (key-spki k)             its SubjectPublicKeyInfo, der
;   (name-der s)             "/CN=a/O=b" (or "CN=a, O=b") -> a Name's der | ()
;   (ext-der line ctx)       one "name=value" extension in openssl's spelling -> [oid der] | why not
;   (cert-make o)            a signed certificate's der from a tablet (see there) | [why not]
;   (cert-kid d)             the key id a certificate names itself by, for its issued ones' aki
;   (csr-make k name lines)  a pkcs#10 request's der | [why not] ; (csr-read d) -> a tablet | why not
;   (pem-out label d)        pem text ; (pem-in t label) the der of each block of that label
;
; the extensions: basicConstraints, keyUsage, extendedKeyUsage, subjectAltName (DNS, IP, email,
; URI), nameConstraints (permitted and excluded DNS and IP subtrees, as verify.l reads them),
; subjectKeyIdentifier=hash (sha-1 of the key's bits, as openssl) and
; authorityKeyIdentifier=keyid. ed25519 signs through src/apps/ssh/ed25519.l, p-256 ecdsa through
; p256.l beside this file.
(module 'tls
(borrow 'bytes)
(borrow 'cal)
(:
   oid-ski (unhex "551d0e")
   oid-aki (unhex "551d23")
   oid-extreq (unhex "2a864886f70d01090e")
   oid-ecdsa256 (unhex "2a8648ce3d040302")
   name-oids {"CN" "550403" "C" "550406" "L" "550407" "ST" "550408" "O" "55040a" "OU" "55040b"
              "serialNumber" "550405" "emailAddress" "2a864886f70d010901" "DC" "0992268993f22c640119"}
   ku-names ["digitalSignature" "nonRepudiation" "keyEncipherment" "dataEncipherment" "keyAgreement"
             "keyCertSign" "cRLSign" "encipherOnly" "decipherOnly"]
   eku-oids {"serverAuth" "2b06010505070301" "clientAuth" "2b06010505070302" "codeSigning" "2b06010505070303"
             "emailProtection" "2b06010505070304" "timeStamping" "2b06010505070308" "OCSPSigning" "2b06010505070309"}
   ext-oids {"basicConstraints" oid-bc "keyUsage" oid-ku "extendedKeyUsage" oid-eku "subjectAltName" oid-san
             "nameConstraints" oid-nc "subjectKeyIdentifier" oid-ski "authorityKeyIdentifier" oid-aki}

   ; --- der, written ---
   (der-len n) (n < 128 ? (string n) (wrbe n ((bits-of n + 7) // 8) @ b (string (128 + #b) + b)))
   (der-enc x)
    (string? x ? x
       (: t <x b (x 1)
          c (? (string? b) b (two? b) (catmap der-enc b) "")
          (string t + der-len #c + c)))
   (der-node s t)
    (<t & 32 = 0 ? [<t (der-body s t)]
       (: ks (der-kids s (t 1) (t 2))
          ns (charm? ks ? () (map (der-node s) ks))
          (charm? ks || any atom? ns ? () [<t ns])))
   (der-tree s) ((string? s ? (der s 0 #s)) @ t (two? t && t 2 = #s ? (der-node s t)))
   ; a non-negative integer, a bit string of whole bytes, a time
   (der-int n) [2 (wrbe n ((bits-of n + 8) // 8))]
   (der-bits b) [3 (string 0 + b)]
   (dd n) (n < 10 ? ("0" + show n) (show n))
   (der-time s)
    (: d (civil (s // 86400)) r (s % 86400) y <d
       tail (dd (d 1) + dd (d 2) + dd (r // 3600) + dd (r // 60 % 60) + dd (r % 60) + "Z")
       (1950 <= y && y < 2050 ? [23 (dd (y % 100) + tail)] [24 (show y + tail)]))
   ; openssl's [CC]YYMMDDHHMMSSZ -> seconds | ()
   (time-arg v)
    (: n #v g (n = 15 ? 24 23)
       t (x509-time (string g + string n + v) [g 2 (2 + n) 0])
       (two? t ? <t))

   ; --- pem ---
   (pem-out label d)
    ((cite 'ssh 'b64e d 1) @ b
       ("-----BEGIN " + label + "-----\n" + catmap (i \ snip b (64 * i) (min #b (64 * i + 64)) + "\n") ^((#b + 63) // 64)
        + "-----END " + label + "-----\n"))
   (pem-in t label)
    (: b ("-----BEGIN " + label + "-----") e ("-----END " + label + "-----")
       (go i acc) (: p (fsub t b i) q (p < 0 ? -1 (fsub t e (p + #b)))
                     (q < 0 ? (rev acc) (go (q + #e) (b64-dec t (p + #b) q . acc))))
       (string? t ? (go 0 ())))

   ; --- keys: ['ed25519 seed pub] and ['p256 d [x y]] ---
   (key-new kind)
    (? (kind = 'ed25519) (rnd 32 @ s ['ed25519 s (cite 'ssh 'ed-pub s)])
       (kind = 'p256) (p256-scalar 0 @ d ['p256 d (p256-pub d)])         ; d 32 bytes, never a bignum
       ())
   (ec-point q) (string 4 + wrbe <q 32 + wrbe (q 1) 32)
   (key-spki k)
    (k @ ['ed25519 _ p] (der-enc [48 [[48 [[6 oid-ed25519]]] (der-bits p)]])
         ['p256 _ q] (der-enc [48 [[48 [[6 oid-ec] [6 oid-p256]]] (der-bits (ec-point q))]])
         ())
   (key-der k)
    (k @ ['ed25519 s _] (der-enc [48 [(der-int 0) [48 [[6 oid-ed25519]]] [4 (der-enc [4 s])]]])
         ['p256 d q] (der-enc [48 [(der-int 0) [48 [[6 oid-ec] [6 oid-p256]]]
                                  [4 (der-enc [48 [(der-int 1) [4 d] [161 [(der-bits (ec-point q))]]]])]]])
         ())
   (key-pem k) (pem-out "PRIVATE KEY" (key-der k))
   ; an ECPrivateKey's scalar, held to the public point when it carries one
   (p256-sec s)
    (der-tree s @ [48 ([2 v] . [4 d] . r)]
                  (: q (#d = 32 && v = string 1 && p2-ok? d = 1 ? (p256-pub d))
                     pt (filter (x \ <x = 161) r)
                     (? (atom? q) ()
                        (atom? pt || pt 0 1 0 = der-bits (ec-point q)) ['p256 d q]
                        ()))
                  ())
   (key-read t)
    (: ds (pem-in t "PRIVATE KEY") d (two? ds ? <ds t)
       (der-tree d @ [48 [[2 z] [48 [[6 o]]] [4 in]]]
                      (z = string 0 && o = oid-ed25519 ?
                          (der-tree in @ [4 s] (#s = 32 ? ['ed25519 s (cite 'ssh 'ed-pub s)] ()) ()))
                     [48 [[2 z] [48 [[6 o] [6 c]]] [4 in]]]
                      (z = string 0 && o = oid-ec && c = oid-p256 ? (p256-sec in))
                     ()))
   (sig-alg k) (k @ ['ed25519 _ _] [48 [[6 oid-ed25519]]] ['p256 _ _] [48 [[6 oid-ecdsa256]]] ())
   (key-sign k m)
    (k @ ['ed25519 s p] (cite 'ssh 'ed-sign s p m)
         ['p256 d _] (p256-sign d m @ rs (der-enc [48 [(der-int <rs) (der-int (rs 1))]]))
         ())
   ; the key id: sha-1 of the key's bit string, rfc 5280's first method and openssl's
   (key-id sp) (der-tree sp @ [48 [_ [3 b]]] (unhex (sha1 (snip b 1 #b))) ())

   ; --- names ---
   (name-der s)
    (: ps (0 < #s && s 0 = 47 ? (split "/" (snip s 1 #s)) (split "," s))
       (rdn p) (: av (p @ ((a && 0 < #a) + "=" + v) [(strip a) (strip v)] ["" ""])
                  a <av v <>av
                  o (peep name-oids a ())
                  st (? (elem a ["C" "serialNumber"]) 19 (elem a ["emailAddress" "DC"]) 22 12)
                  (string? o && 0 < #v ? [49 [[48 [[6 (unhex o)] [st v]]]]]))
       rs (map rdn (filter (p \ 0 < #(strip p)) ps))
       (any atom? rs ? () (der-enc [48 rs])))

   ; --- extensions, as openssl's config lines spell them ---
   (pre? p w) (#p <= #w && snip w 0 #p = p)
   (idx l x) (: (go l i) (? (atom? l) -1 (<l = x) i (go >l (i + 1))) (go l 0))
   (hexd c) (? (47 < c < 58) (c - 48) (96 < c < 103) (c - 87) (64 < c < 71) (c - 55) -1)
   (h16 p) (foldl (a \ c \ (a < 0 || hexd c < 0 ? -1 (a * 16 + hexd c))) 0 (chars p) @ v
              (0 < #p && #p < 5 ? v -1))
   (ip6-bytes s)
    (: k (fsub s "::" 0)
       (grp t) (t = "" ? () (map h16 (split ":" t)))
       hd (k < 0 ? (grp s) (grp (snip s 0 k)))
       tl (k < 0 ? () (grp (snip s (k + 2) #s)))
       gap (8 - #hd - #tl)
       (fsub s ":" 0 < 0 || any (w \ w < 0) (hd + tl) || k < 0 && gap != 0 || 0 <= k && gap < 1 ? ()
          (catmap (w \ wrbe w 2) (hd + (map (_ \ 0) ^(0 <= k ? gap 0)) + tl))))
   (ip-bytes s) (quad-bytes s @ q (string? q ? q (ip6-bytes s)))
   ; an address and its mask, "10.0.0.0/255.0.0.0" or "10.0.0.0/8"
   (ip-net s)
    (: at (s @ (h + "/" + t) [(ip-bytes h) t] [() ""])
       a <at t <>at
       m (: b (ip-bytes t) n (unum t)
            (? (string? b) b
               (charm? n && string? a && 0 <= n && n <= 8 * #a)
                (bytes #a (i \ (n - 8 * i @ r (? (7 < r) 255 (r < 1) 0 (255 - (255 >> r))))))
               ()))
       (string? a && string? m && #a = #m ? (a + m)))
   ; "DNS:x" "IP:a" "email:x" "URI:x" -> a GeneralName; net? reads an IP as an address and mask
   (gname s net?)
    (: tv (s @ ((ty && 0 < #ty) + ":" + v) [ty v] ["" ""]) ty <tv v <>tv
       (? (ty = "DNS" && 0 < #v) [130 v]
          (ty = "IP") ((net? ? (ip-net v) (ip-bytes v)) @ b (string? b ? [135 b]))
          (ty = "email" && 0 < #v) [129 v]
          (ty = "URI" && 0 < #v) [134 v]
          ()))
   (ku-val ws)
    (map (idx ku-names) ws @ is
       (atom? is || any (i \ i < 0) is ? ()
          (: top (foldl max 0 is) nb (top // 8 + 1)
             v (foldl (a \ i \ a | 1 << (8 * nb - 1 - i)) 0 is)
             [3 (string (8 * nb - 1 - top) + wrbe v nb)])))
   ; one extension's value node from its comma items, critical taken off -> node | why not
   (ext-val nm ws ctx)
    (nm @ "basicConstraints"
           (: us (map upper ws) ca (elem "CA:TRUE" us) pl (filter (pre? "PATHLEN:") us)
              n (two? pl ? (unum (snip <pl 8 #(<pl))))
              (? (!(all (w \ elem w ["CA:TRUE" "CA:FALSE"] || pre? "PATHLEN:" w) us) || (two? pl && !(charm? n)))
                  "basicConstraints reads CA:TRUE|CA:FALSE[,pathlen:N]"
                 [48 ((ca ? [[1 (string 255)]]) + (two? pl ? [(der-int n)]))]))
          "keyUsage" (ku-val ws @ v (two? v ? v ("keyUsage takes " + join "," ku-names)))
          "extendedKeyUsage"
           (map (w \ peep eku-oids w ()) ws @ os
              (two? os && all string? os ? [48 (map (o \ [6 (unhex o)]) os)]
                 ("extendedKeyUsage takes " + join "," (sort (keys eku-oids)))))
          "subjectAltName"
           (map (w \ gname w 0) ws @ gs
              (two? gs && all two? gs ? [48 gs] "subjectAltName takes DNS:, IP:, email: and URI: names"))
          "nameConstraints"
           (: (item w) (w @ ((h && elem h ["permitted" "excluded"]) + ";" + r) (gname r 1 @ g (two? g ? [h g])) ())
              its (map item ws)
              (part h tag) (map (i \ [48 [(i 1)]]) (filter (i \ <i = h) its) @ gs (two? gs ? [[tag gs]]))
              (atom? its || any atom? its ? "nameConstraints takes permitted;NAME and excluded;NAME, names DNS: or IP:addr/mask"
                 [48 (part "permitted" 160 + part "excluded" 161)]))
          "subjectKeyIdentifier" (ws = ["hash"] && string? (ctx 'kid) ? [4 (ctx 'kid)] "subjectKeyIdentifier is hash here")
          "authorityKeyIdentifier"
           (ctx 'akid @ a
              (two? ws && all (w \ elem w ["keyid" "keyid:always"]) ws && string? a ? [48 [[128 a]]]
                 "authorityKeyIdentifier is keyid here, and wants an issuer"))
          ("no extension " + nm + " here"))
   ; "name=value", "critical," leading the value when it is -> [oid der] | why not
   (ext-der line ctx)
    (: nw (line @ ((n && 0 < #n) + "=" + r) [(strip n) (map strip (split "," r))] ["" ()])
       nm <nw ws0 <>nw
       crit (two? ws0 ? (<ws0 = "critical") 0)
       ws (crit ? >ws0 ws0)
       oid (peep ext-oids nm ())
       v (string? oid ? (ext-val nm ws ctx) ("no extension " + nm + " here"))
       (string? v ? v
          [oid (der-enc [48 ([[6 oid]] + (crit ? [[1 (string 255)]]) + [[4 (der-enc v)]])])]))
   ; an extension written already -> [oid der] | ()
   (ext-pair d) (der-tree d @ [48 ([6 o] . _)] [o d] ())
   ; a later extension of the same oid takes an earlier one's place
   ; the key id a certificate gives itself, else its key's
   (cert-kid d) (der-tree (ext-of d oid-ski) @ t (two? t && <t = 4 ? (t 1) (key-id (x509 d 'key 2))))
   (ext-merge rs) (foldl (acc \ r \ (any (a \ <a = <r) acc ? (map (a \ (<a = <r ? r a)) acc) (acc + [r]))) () rs)
   ; a certificate's extension value by oid -> the value's der | ()
   (ext-of d oid)
    (: t (der-tree d)
       fs (t @ [48 [[48 l] _ _]] l ())
       x (filter (f \ <f = 163) fs)
       es (x @ [[163 [[48 l]]]] l ())
       hit (filter (e \ (e @ [48 ([6 o] . _)] (o = oid) 0)) es)
       (hit @ [[48 l]] ((last l) @ [4 v] v ()) ()))

   ; --- the certificate ---
   ; o: 'subject 'issuer (name ders), 'spki (the subject's key), 'key (the signer), 'nb 'na
   ; (seconds), 'serial, 'akid (the issuer's key id; the subject's own when absent), 'exts
   ; ("name=value" lines and [oid der] pairs, a later one of an oid replacing an earlier)
   ; -> the der | [why not]
   (cert-make o)
    (: kid (key-id (o 'spki))
       ctx {'kid kid 'akid (o 'akid @ a (string? a ? a kid))}
       rs (map (l \ (string? l ? (ext-der l ctx) l)) (o 'exts))
       bad (filter string? rs)
       k (o 'key) alg (sig-alg k)
       (? (two? bad) [<bad]
          (atom? alg) ["no key to sign with"]
          (: es (map (r \ r 1) (ext-merge (filter two? rs)))
             ser (o 'serial @ s (charm? s && 0 < s ? s (be-num (rnd 16) >> 1 | 1)))
             tbs (der-enc [48 ([[160 [(der-int 2)]] (der-int ser) alg (o 'issuer)
                                [48 [(der-time (o 'nb)) (der-time (o 'na))]] (o 'subject) (o 'spki)]
                               + (two? es ? [[163 [[48 es]]]]))])
             (der-enc [48 [tbs alg (der-bits (key-sign k tbs))]]))))

   ; --- pkcs#10 requests: the extensions ride an extensionRequest attribute ---
   (csr-make k name lines)
    (: ctx {'kid (key-id (key-spki k))}
       rs (map (l \ ext-der l ctx) lines)
       bad (filter string? rs)
       es (map (r \ r 1) (ext-merge (filter two? rs)))
       attrs (two? es ? [[48 [[6 oid-extreq] [49 [[48 es]]]]]])
       info (der-enc [48 [(der-int 0) name (key-spki k) [160 attrs]]])
       (two? bad ? [<bad]
          (der-enc [48 [info (sig-alg k) (der-bits (key-sign k info))]])))
   (alg-oid a) (a @ [48 [[6 o]]] o [48 [[6 o] _]] o "")
   ; -> {'subject 'spki 'exts} | why not; the request's own signature is checked
   (csr-read d)
    (: top (der d 0 #d)
       ks (two? top && top 2 = #d && <top = 48 ? (der-kids d (top 1) (top 2)) 0)
       (? (!(two? ks) || #ks != 3) "the request does not read"
          (der-all d <ks @ info
             (der-tree info @ [48 [[2 _] subj sp [160 attrs]]]
                              (: spd (der-enc sp) k (spki-key spd (der spd 0 #spd))
                                 sig (der-tree (der-all d (ks 2)) @ [3 b] (snip b 1 #b) "")
                                 ao (alg-oid (der-tree (der-all d (ks 1))))
                                 (ext-in a) (a @ [48 [[6 o] [49 [[48 es]]]]] (o = oid-extreq ? (map der-enc es)) ())
                                 exts (catmap ext-in attrs)
                                 (? (atom? k) "the request's key is not one read here"
                                    (1 != sig-ok? ao k info sig) "the request's signature does not verify"
                                    {'subject (der-enc subj) 'spki spd 'exts (two? exts ? exts)}))
                              "the request does not read")))))
) ; module tls
