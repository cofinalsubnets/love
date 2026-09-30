; src/apps/kore/openssl.l -- openssl: a small face of the openssl command line.
;
;   openssl x509 [-in F] [-inform PEM|DER] [-noout] [-text] [-subject] [-issuer] [-dates]
;                [-startdate] [-enddate] [-serial] [-fingerprint] [-md5|-sha1|-sha224|-sha256
;                |-sha384|-sha512] [-ext NAMES] [-pubkey] [-outform PEM|DER] [-out F]
;   openssl x509 -req -in CSR (-CA F [-CAkey F] | -signkey F) [-days N] [-not_before T]
;                [-not_after T] [-set_serial N] [-extfile F [-extensions S]] [-addext E]..
;                [-copy_extensions copy] [-out F] ..and the printing flags above
;   openssl genpkey -algorithm ed25519 | -algorithm EC -pkeyopt ec_paramgen_curve:P-256 [-out F]
;   openssl req -new [-x509] (-key F | -newkey ed25519|ec [-pkeyopt ..] [-keyout F]) -subj /CN=..
;                [-days N] [-not_before T] [-not_after T] [-set_serial N] [-addext E].. [-out F]
;   openssl s_client [-connect] HOST:PORT [-servername NAME] [-showcerts] [-verify_return_error]
;                [-brief] [-quiet]
;   openssl verify [-CAfile F] [-untrusted F] [CERT..]
;   openssl dgst [-md5|-sha1|-sha224|-sha256|-sha384|-sha512] [-r] [FILE..]
;   openssl rand [-hex|-base64] [-out F] N
;   openssl base64 [-e|-d] [-A] [-in F] [-out F]
;   openssl version | help
;
; spelled and printed as openssl 3 does, so scripts carry over. the certificate is read here
; (its own total der walk, for printing); trust is the tls module's -- verify.l's chain-fail
; against tls-roots or -CAfile, and client.l's handshake, tls 1.3 only. keys, requests and
; certificates are made by the tls module's cert.l: ed25519 and p-256 keys, pkcs#8 and pkcs#10,
; the extensions in openssl's config spelling (-addext, and -extfile's unnamed or named section).
(module 'kore
(borrow 'bytes)
(borrow 'posix)

(:
   (os-tls nm) (cite 'tls nm)
   (os-sp n) (string (map (_ \ 32) ^n))
   (os-cat f l) (? (two? l) (catmap f l) "")
   (os-lines l) (os-cat (s \ s + "\n") l)
   (os-up s) (string (map (i \ (: c (s i) (96 < c < 103 ? (c - 32) c))) ^#s))
   (os-hexn n) (? (n < 16) (string ("0123456789abcdef" n)) (os-hexn (n // 16) + os-hexn (n % 16)))
   (os-num b) (foldl (a \ i \ a * 256 + b i) 0 ^#b)
   (os-colon s) (: h (b2hex s) (join ":" (map (i \ snip h (2 * i) (2 * i + 2)) ^#s)))
   ; openssl's hex blocks: per bytes a line, each byte but the very last followed by a colon
   (os-dump s per ind)
    (: n #s h (b2hex s) pad (os-sp ind)
       (ln i) (pad + catmap (j \ snip h (2 * j) (2 * j + 2) + (j + 1 < n ? ":" "")) (map (k \ i + k) ^(min per (n - i))))
       (map (k \ ln (k * per)) ^((n + per - 1) // per)))

   ; --- der, walked totally: a tlv is [tag cs ce], and a bad length is () ---
   (os-tlv s i n)
    (? (n < i + 2) ()
       (: tag (s i) l0 (s (i + 1))
          k (l0 < 128 ? 0 (l0 - 128))
          (? ((tag & 31) = 31 || l0 = 128 || 132 < l0 || n < i + 2 + k) ()
             (: cs (i + 2 + k)
                ln (k = 0 ? l0 (rdbe s (i + 2) k))
                (? (n < cs + ln) () [tag cs (cs + ln)])))))
   ; s as exactly one tlv -> [tag body] | ()
   (os-one s) (: t (os-tlv s 0 #s) (? (two? t && t 2 = #s) [<t (snip s (t 1) (t 2))] ()))
   (os-tag s) (? (0 < #s) (s 0) -1)
   (os-body s) (os-one s @ [_ b] b "")
   ; a body's children, each a whole tlv string, when they tile it -> list | 0
   (os-tile s)
    (: n #s
       (go i acc) (? (i = n) (rev acc)
                     (: t (os-tlv s i n) (? (atom? t) 0 (go (t 2) ((snip s i (t 2)) . acc)))))
       (go 0 ()))
   ; a constructed tlv's children -> list | 0
   (os-in s) (os-one s @ [_ b] (os-tile b) 0)
   (os-oid b)
    (: (go i v acc) (? (#b <= i) (rev acc)
                       (: c (b i) w (v * 128 + (c & 127))
                          (? (c < 128) (go (i + 1) 0 (w . acc)) (go (i + 1) w acc))))
       ns (go 0 0 ())
       (? (atom? ns) ""
          (: a <ns f (? (a < 80) (a // 40) 2)
             (join "." (map show (f . (a - 40 * f) . >ns))))))
   (os-oidof s) (? (os-tag s = 6) (os-oid (os-body s)) "")
   ; an integer's magnitude: its leading zero dropped
   (os-mag b) (? (1 < #b && b 0 = 0) (os-mag (snip b 1 #b)) b)

   ; --- names ---
   os-attrs {"2.5.4.3" "CN" "2.5.4.6" "C" "2.5.4.7" "L" "2.5.4.8" "ST" "2.5.4.10" "O" "2.5.4.11" "OU"
             "1.2.840.113549.1.9.1" "emailAddress" "2.5.4.5" "serialNumber" "2.5.4.9" "street"
             "2.5.4.17" "postalCode" "2.5.4.4" "SN" "2.5.4.42" "GN" "2.5.4.12" "title"
             "2.5.4.43" "initials" "2.5.4.46" "dnQualifier" "2.5.4.65" "pseudonym" "2.5.4.15" "businessCategory"
             "2.5.4.97" "organizationIdentifier" "0.9.2342.19200300.100.1.25" "DC" "0.9.2342.19200300.100.1.1" "UID"
             "1.3.6.1.4.1.311.60.2.1.1" "jurisdictionL" "1.3.6.1.4.1.311.60.2.1.2" "jurisdictionST"
             "1.3.6.1.4.1.311.60.2.1.3" "jurisdictionC"}
   os-algs {"1.2.840.113549.1.1.1" "rsaEncryption" "1.2.840.113549.1.1.4" "md5WithRSAEncryption"
            "1.2.840.113549.1.1.5" "sha1WithRSAEncryption" "1.2.840.113549.1.1.10" "rsassaPss"
            "1.2.840.113549.1.1.11" "sha256WithRSAEncryption" "1.2.840.113549.1.1.12" "sha384WithRSAEncryption"
            "1.2.840.113549.1.1.13" "sha512WithRSAEncryption" "1.2.840.113549.1.1.14" "sha224WithRSAEncryption"
            "1.2.840.10045.2.1" "id-ecPublicKey" "1.2.840.10045.4.1" "ecdsa-with-SHA1"
            "1.2.840.10045.4.3.1" "ecdsa-with-SHA224" "1.2.840.10045.4.3.2" "ecdsa-with-SHA256"
            "1.2.840.10045.4.3.3" "ecdsa-with-SHA384" "1.2.840.10045.4.3.4" "ecdsa-with-SHA512"
            "1.3.101.112" "ED25519" "1.3.101.113" "ED448" "1.2.840.10040.4.1" "dsaEncryption"
            "1.2.840.10040.4.3" "dsaWithSHA1"}
   ; a curve: its name, its nist name, its bits
   os-curves {"1.2.840.10045.3.1.7" ["prime256v1" "P-256" 256] "1.3.132.0.34" ["secp384r1" "P-384" 384]
              "1.3.132.0.35" ["secp521r1" "P-521" 521] "1.3.132.0.10" ["secp256k1" () 256]}
   (os-alg o) (peep os-algs o o)
   ; a code point as utf-8
   (os-utf8 c)
    (? (c < 128) (string c)
       (c < 2048) (string [(192 | c >> 6) (128 | c & 63)])
       (c < 65536) (string [(224 | c >> 12) (128 | c >> 6 & 63) (128 | c & 63)])
       (string [(240 | c >> 18) (128 | c >> 12 & 63) (128 | c >> 6 & 63) (128 | c & 63)]))
   ; a directory string's text: bmp and universal strings to utf-8, the controls escaped
   (os-str s)
    (: t (os-tag s) b (os-body s)
       w (? (t = 30) 2 (t = 28) 4 1)
       cs (map (i \ os-num (snip b (w * i) (w * i + w))) ^(#b // w))
       (os-cat (c \ (? (c < 32 || c = 127) ("\\" + os-up (b2hex (string c))) (w = 1) (string c) (os-utf8 c))) cs))
   (os-ava a)
    (os-in a @ [o v] ((: d (os-oidof o) (peep os-attrs d d)) + "=" + os-str v) "?")
   ; a Name -> "C=US, O=X, CN=Y", openssl 3's default face
   (os-dn s)
    (: rs (os-in s)
       (? (atom? rs) ""
          (join ", " (map (r \ (: as (os-in r) (? (two? as) (join " + " (map os-ava as)) "?"))) rs))))

   ; ..and the slashed face openssl's GeneralName printer uses
   (os-dn-slash s)
    (: rs (os-in s)
       (? (atom? rs) "" (os-cat (r \ "/" + (: as (os-in r) (? (two? as) (join "+" (map os-ava as)) "?"))) rs)))

   ; --- time: "Jan  1 00:00:00 2025 GMT" ---
   os-months ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
   (os-dnum b i k)
    (? (#b < i + k) -1
       (foldl (a \ j \ (: c (b (i + j)) (? (a < 0 || c < 48 || 57 < c) -1 (a * 10 + c - 48)))) 0 ^k))
   (os-2 n) (n < 10 ? ("0" + show n) (show n))
   (os-time s)
    (: t (os-tag s) b (os-body s) g (t = 24)
       o (g ? 4 2)
       y (? g (os-dnum b 0 4) (: v (os-dnum b 0 2) (? (v < 0) -1 (v < 50) (2000 + v) (1900 + v))))
       mo (os-dnum b o 2) d (os-dnum b (o + 2) 2) h (os-dnum b (o + 4) 2)
       mi (os-dnum b (o + 6) 2) sc (os-dnum b (o + 8) 2)
       (? ((t != 23 && t != 24) || y < 0 || mo < 1 || 12 < mo || d < 1 || h < 0 || mi < 0 || sc < 0) "Bad time value"
          (os-months (mo - 1) + " " + (d < 10 ? (" " + show d) (show d)) + " " + os-2 h + ":" + os-2 mi + ":"
           + os-2 sc + " " + show y + " GMT")))

   ; --- the certificate, read for printing -> a tablet | () ---
   (os-cert d)
    (: top (os-in d)
       tk (? (two? top && #top = 3) (os-in <top) 0)
       v? (two? tk && os-tag <tk = 160)
       tf (? v? >tk tk)
       ok (two? tf && 6 <= #tf && os-tag <tf = 2 && all (i \ os-tag (tf i) = 48) [1 2 3 4 5]
           && os-tag (top 1) = 48 && os-tag (top 2) = 3)
       vl (? ok (os-in (tf 3)) 0)
       sp (? ok (os-in (tf 5)) 0)
       ka (? (two? sp && #sp = 2 && os-tag <>sp = 3) (os-in <sp) 0)
       vi (? v? (os-in <tk) 0)
       ver (? v? (? (two? vi && #vi = 1 && os-tag <vi = 2) (os-num (os-body <vi)) -1) 0)
       (? (!ok || atom? vl || #vl != 2 || atom? ka || ver < 0) ()
          (: x (tablet 16)
             kb (os-body <>sp)
             ex (filter (e \ os-tag e = 163) (drop-n tf 6))
             es (? (atom? ex) () (: s (os-in <ex) (? (two? s && #s = 1) (: l (os-in <s) (? (two? l) l 'bad)) 'bad)))
             xs (? (two? es) (map os-ext es) es)
             _ (pins x 'der d 'ver ver 'serial (os-mag (os-body <tf)) 'salg (os-alg-of (tf 1))
                     'issuer (tf 2) 'subject (tf 4) 'nb <vl 'na <>vl
                     'kalg (os-oidof <ka) 'kpar (? (two? >ka) <>ka "") 'key (snip kb 1 #kb) 'spki (tf 5)
                     'exts xs 'oalg (os-alg-of (top 1)) 'sig (: sb (os-body (top 2)) (snip sb 1 #sb)))
             (? (xs = 'bad || any atom? xs) () x))))
   (drop-n l k) (? (k < 1 || atom? l) l (drop-n >l (k - 1)))
   (os-alg-of s) (: k (os-in s) (? (two? k) (os-oidof <k) ""))
   ; an extension -> [oid critical value] | ()
   (os-ext e)
    (os-in e @ [o v] (? (os-tag v = 4) [(os-oidof o) 0 (os-body v)] ())
               [o c v] (? (os-tag v = 4 && os-tag c = 1) [(os-oidof o) (os-body c = string 255 ? 1 0) (os-body v)] ())
               ())
   (os-der-in txt)                            ; pem or der text -> the first certificate's der | ()
    (: ds (os-tls 'pem-ders txt)
       (? (two? ds) <ds
          (: t (os-tlv txt 0 #txt) (? (two? t && 0 < #txt && txt 0 = 48) (snip txt 0 (t 2)) ()))))
   (os-pem d) ("-----BEGIN CERTIFICATE-----\n" + ubwrap 64 (ubenc ub64set 6 d) + "-----END CERTIFICATE-----\n")

   ; --- extensions, as openssl's printers say them: [name lines] ---
   os-extnames {"2.5.29.19" "X509v3 Basic Constraints" "2.5.29.15" "X509v3 Key Usage"
                "2.5.29.37" "X509v3 Extended Key Usage" "2.5.29.17" "X509v3 Subject Alternative Name"
                "2.5.29.18" "X509v3 Issuer Alternative Name" "2.5.29.14" "X509v3 Subject Key Identifier"
                "2.5.29.35" "X509v3 Authority Key Identifier" "1.3.6.1.5.5.7.1.1" "Authority Information Access"
                "2.5.29.31" "X509v3 CRL Distribution Points" "2.5.29.32" "X509v3 Certificate Policies"
                "2.5.29.30" "X509v3 Name Constraints" "2.5.29.36" "X509v3 Policy Constraints"
                "1.3.6.1.4.1.11129.2.4.2" "CT Precertificate SCTs" "1.3.6.1.4.1.11129.2.4.3" "CT Precertificate Poison"}
   ; the -ext spelling of each
   os-extshort {"basicConstraints" "2.5.29.19" "keyUsage" "2.5.29.15" "extendedKeyUsage" "2.5.29.37"
                "subjectAltName" "2.5.29.17" "issuerAltName" "2.5.29.18" "subjectKeyIdentifier" "2.5.29.14"
                "authorityKeyIdentifier" "2.5.29.35" "authorityInfoAccess" "1.3.6.1.5.5.7.1.1"
                "crlDistributionPoints" "2.5.29.31" "certificatePolicies" "2.5.29.32"
                "nameConstraints" "2.5.29.30" "policyConstraints" "2.5.29.36"}
   os-kus ["Digital Signature" "Non Repudiation" "Key Encipherment" "Data Encipherment" "Key Agreement"
           "Certificate Sign" "CRL Sign" "Encipher Only" "Decipher Only"]
   os-ekus {"1.3.6.1.5.5.7.3.1" "TLS Web Server Authentication" "1.3.6.1.5.5.7.3.2" "TLS Web Client Authentication"
            "1.3.6.1.5.5.7.3.3" "Code Signing" "1.3.6.1.5.5.7.3.4" "E-mail Protection"
            "1.3.6.1.5.5.7.3.8" "Time Stamping" "1.3.6.1.5.5.7.3.9" "OCSP Signing" "2.5.29.37.0" "Any Extended Key Usage"}
   ; a GeneralName
   (os-gn g)
    (: t (os-tag g) b (os-body g)
       (? (t = 130) ("DNS:" + b)
          (t = 135) ("IP Address:" + (? (#b = 4) (join "." (map (i \ show (b i)) ^4))
                                         (#b = 16) (join ":" (map (i \ os-up (os-hexn (os-num (snip b (2 * i) (2 * i + 2))))) ^8))
                                         "<invalid>"))
          (t = 129) ("email:" + b)
          (t = 134) ("URI:" + b)
          (t = 164) ("DirName:" + os-dn-slash b)
          (t = 136) ("Registered ID:" + os-oid b)
          (t = 160) "othername:<unsupported>"
          "<unsupported>"))
   (os-gns v) (: l (os-in v) (? (two? l) (join ", " (map os-gn l)) ()))
   ; a name constraint's base: an address with its mask as openssl says it
   (os-ncgn g)
    (: b (os-body g)
       (? (os-tag g = 135 && #b = 8) ("IP:" + join "." (map (i \ show (b i)) ^4) + "/" + join "." (map (i \ show (b (4 + i))) ^4))
          (os-gn g)))
   ; an unknown value: its bytes, the unprintable ones as dots
   (os-raw v) (string (map (i \ (: c (v i) (? (c < 32 || 126 < c) 46 c))) ^#v))
   (os-extlines o v)
    (: (bad x) (? (atom? x) [(os-raw v)] x)
       (bad
        (o @ "2.5.29.19"
              (: l (os-in v)
                 (? (l = 0) ()
                    (: ca (filter (e \ os-tag e = 1) l) pl (filter (e \ os-tag e = 2) l)
                       [((? (two? ca && os-body <ca = string 255) "CA:TRUE" "CA:FALSE")
                         + (? (two? pl) (", pathlen:" + show (os-num (os-body <pl))) ""))])))
             "2.5.29.15"
              (: b (os-one v)
                 (? (atom? b || <b != 3 || #<>b < 2) ()
                    (: bs <>b
                       on (filter (i \ (: k (i // 8 + 1) (k < #bs && 0 < (bs k & (128 >> i % 8))))) ^9)
                       [(join ", " (map os-kus on))])))
             "2.5.29.37"
              (: l (os-in v) (? (two? l) [(join ", " (map (e \ (: d (os-oidof e) (peep os-ekus d d))) l))] ()))
             ("2.5.29.17" || "2.5.29.18") (: g (os-gns v) (? (string? g) [g] ()))
             "2.5.29.14" (? (os-tag v = 4) [(os-up (os-colon (os-body v)))] ())
             "2.5.29.30"
              (: l (os-in v)
                 (? (atom? l) ()
                    (catmap (p \ (: h (? (os-tag p = 160) "Permitted:" (os-tag p = 161) "Excluded:" "?")
                                   gs (os-in ("0" + snip p 1 #p))
                                   (h . (? (two? gs) (map (g \ "  " + (os-in g @ [b] (os-ncgn b) "?")) gs) ()))))
                            l)))
             "2.5.29.35"
              (: l (os-in v)
                 (? (atom? l) ()
                    (: ki (filter (e \ os-tag e = 128) l) rest (filter (e \ os-tag e != 128) l)
                       kl (? (two? ki) (os-up (os-colon (os-body <ki))) "")
                       (? (atom? rest) [kl]
                          ((? (two? ki) [("keyid:" + kl)] ())
                           + map (e \ (? (os-tag e = 161) (: g (os-gns ("0" + snip e 1 #e)) (? (string? g) g "?"))
                                          ("serial:" + os-up (os-colon (os-body e))))) rest)))))
             "1.3.6.1.5.5.7.1.1"
              (: l (os-in v)
                 (? (atom? l) ()
                    (map (a \ (os-in a @ [m g] ((: d (os-oidof m) (d @ "1.3.6.1.5.5.7.48.1" "OCSP" "1.3.6.1.5.5.7.48.2" "CA Issuers" d))
                                                + " - " + os-gn g)
                                       "?")) l)))
             "2.5.29.31"
              (: l (os-in v)
                 (? (atom? l) ()
                    (catmap (p \ (: ks (os-in p)
                                   dp (? (two? ks) (filter (e \ os-tag e = 160) ks) ())
                                   fn (? (two? dp) (: w (os-in ("0" + snip <dp 1 #<dp)) (? (two? w) w ())) ())
                                   ns (? (two? fn && os-tag <fn = 160) (os-in ("0" + snip <fn 1 #<fn)) ())
                                   (? (two? ns) (["Full Name:"] + map (g \ "  " + os-gn g) ns + [""]) ["<unsupported>" ""])))
                            l)))
             "2.5.29.32"
              (: l (os-in v)
                 (? (atom? l) ()
                    (catmap (p \ (: ks (os-in p)
                                   (? (atom? ks) ["?"]
                                      (: id (os-oidof <ks)
                                         qs (? (two? >ks) (os-in <>ks) ())
                                         ([("Policy: " + (id = "2.5.29.32.0" ? "X509v3 Any Policy" id))]
                                          + (? (two? qs) (catmap os-qual qs) ()))))))
                            l)))
             ())))
   ; a policy qualifier: a cps pointer or a user notice
   (os-qual q)
    (os-in q @ [qo qv] (: d (os-oidof qo)
                         (? (d = "1.3.6.1.5.5.7.2.1") [("  CPS: " + os-body qv)]
                            (d = "1.3.6.1.5.5.7.2.2") ("  User Notice:" . os-notice qv)
                            [("  Unknown Qualifier: " + d)]))
               ())
   ; a display text up to its first nul, as openssl's %.*s says it
   (os-ctext s) (: b (os-body s) z (filter (i \ b i = 0) ^#b) (? (two? z) (snip b 0 <z) b))
   (os-notice v)
    (: ks (os-in v) l (? (two? ks) ks ())
       ref (filter (e \ os-tag e = 48) l)
       txt (filter (e \ os-tag e != 48) l)
       rl (? (two? ref)
             (: r (os-in <ref)
                (? (two? r && #r = 2)
                   (: ns (os-in (r 1)) ns2 (? (two? ns) ns ())
                      [("    Organization: " + os-ctext <r)
                       ("    Number" + (1 < #ns2 ? "s" "") + ": " + join ", " (map (n \ show (os-num (os-body n))) ns2))])
                   ()))
             ())
       (rl + (? (two? txt) [("    Explicit Text: " + os-ctext <txt)] ())))
   ; one extension, header and value lines at two indents
   (os-extblock e i j)
    (: o <e
       ((os-sp i + peep os-extnames o o + ": " + (e 1 ? "critical" ""))
        . map (l \ (? (0 < #l) (os-sp j + l) "")) (os-extlines o (e 2))))

   ; --- the key ---
   (os-rsa k) (os-in k @ [n e] [(os-mag (os-body n)) (os-mag (os-body e))] ())
   (os-bits n) (: (go n k) (? (n < 1) k (go (n >> 1) (k + 1))) (go n 0))
   ; [kind bits curve]: 'rsa 'ec 'ed25519 or the dotted oid
   (os-keyof x)
    (: a (x 'kalg)
       (? (a = "1.2.840.113549.1.1.1") (: r (os-rsa (x 'key)) ['rsa (? (two? r) (os-bits (os-num <r)) 0) ()])
          (a = "1.2.840.10045.2.1") (: c (peep os-curves (os-oidof (x 'kpar)) ()) ['ec (? (two? c) (c 2) 0) c])
          (a = "1.3.101.112") ['ed25519 253 ()]
          [a 0 ()]))
   (os-keylines x)
    (: k (os-keyof x) i (os-sp 16)
       (<k @ 'rsa (: r (os-rsa (x 'key))
                     (? (two? r)
                        (: n <r e <>r
                           ([(i + "Public-Key: (" + show (k 1) + " bit)") (i + "Modulus:")]
                            + os-dump (n 0 < 128 ? n (string 0 + n)) 15 20
                            + [(i + "Exponent: " + show (os-num e) + " (0x" + os-hexn (os-num e) + ")")]))
                        [(i + "Unable to load Public Key")]))
             'ec ([(i + "Public-Key: (" + show (k 1) + " bit)") (i + "pub:")] + os-dump (x 'key) 15 20
                  + (: c (k 2) (? (two? c) ([(i + "ASN1 OID: " + <c)] + (? (string? (c 1)) [(i + "NIST CURVE: " + c 1)] ())) ())))
             'ed25519 ([(i + "ED25519 Public-Key:") (i + "pub:")] + os-dump (x 'key) 15 20)
             ([(i + "pub:")] + os-dump (x 'key) 15 20)))

   ; --- x509 -text ---
   (os-serial-text s)
    (: n (os-num s)
       (? (#s <= 8 && n < (63 2))
          [("        Serial Number: " + show n + " (0x" + os-hexn n + ")")]
          ["        Serial Number:" ("            " + os-colon s)]))
   (os-text x)
    (: es (x 'exts)
       (["Certificate:" "    Data:"
          ("        Version: " + show (x 'ver + 1) + " (0x" + os-hexn (x 'ver) + ")")]
         + os-serial-text (x 'serial)
         + [("        Signature Algorithm: " + os-alg (x 'salg))
            ("        Issuer: " + os-dn (x 'issuer))
            "        Validity"
            ("            Not Before: " + os-time (x 'nb))
            ("            Not After : " + os-time (x 'na))
            ("        Subject: " + os-dn (x 'subject))
            "        Subject Public Key Info:"
            ("            Public Key Algorithm: " + os-alg (x 'kalg))]
         + os-keylines x
         + (? (two? es) ("        X509v3 extensions:" . catmap (e \ os-extblock e 12 16) es) ())
         + [("    Signature Algorithm: " + os-alg (x 'oalg)) "    Signature Value:"]
         + os-dump (x 'sig) 18 8))

   ; --- digests by name: [label-in-dgst label-in-fingerprint function] ---
   (os-mds _) {"md5" ["MD5" "md5" md5] "sha1" ["SHA1" "SHA1" sha1] "sha224" ["SHA2-224" "sha224" sha224]
           "sha256" ["SHA2-256" "sha256" sha256] "sha384" ["SHA2-384" "sha384" sha384]
           "sha512" ["SHA2-512" "sha512" sha512]}
   ; "-sha256" -> its row | ()
   (os-md w) (? (1 < #w && w 0 = 45) (peep (os-mds 0) (snip w 1 #w) ()) ())

   ; the input, whole: a path, or stdin for none or "-" -> text | ()
   (os-slurp f) (? (!(string? f) || f = "-") (slurp in) (uread f @ [_ t] t ()))
   (os-sink f) (? (string? f) (open f "w") out)
   (os-close p f) (? (string? f) (close p) (flush out))
   (os-bad cmd w) (say err (cmd + ": Unknown option or message digest: " + w + "\n" + cmd + ": Use -help for summary.\n"), 1)

   ; --- x509 ---
   (os-x509 as)
    (: st {'acts ()}
       (go a)
        (? (atom? a) 0
           (: w <a arg (? (two? >a) <>a ()) m (os-md w)
              (? (two? m) (pin st 'md m, go >a)
                 (elem w ["-in" "-inform" "-outform" "-out" "-ext" "-CA" "-CAkey" "-signkey" "-key" "-days"
                          "-set_serial" "-extfile" "-extensions" "-not_before" "-not_after" "-copy_extensions"])
                  (? (string? arg) (pin st w arg, (w = "-ext" ? (pin st 'acts (w . st 'acts)) 0), go >>a) (os-bad "x509" w))
                 (w = "-addext") (? (string? arg) (pin st 'addext (peep st 'addext () + [arg]), go >>a) (os-bad "x509" w))
                 (w = "-req" || w = "-CAcreateserial") (pin st w 1, go >a)
                 (elem w ["-noout" "-text" "-subject" "-issuer" "-dates" "-startdate" "-enddate"
                          "-serial" "-fingerprint" "-pubkey" "-noout"])
                  (pin st 'acts (w . st 'acts), (w = "-noout" ? (pin st 'noout 1) 0), go >a)
                 (os-bad "x509" w))))
       r (go as)
       (? (r != 0) r
          (: src (peep st "-in" ())
             nm (? (string? src) src "<stdin>")
             txt (? (st "-req") "" (os-slurp src))
             d (? (st "-req") (os-issue st) (string? txt) (os-der-in txt) ())
             x (? (string? d) (os-cert d) ())
             (? (two? d) (say err ("x509: " + <d + "\n"), 1)
                !(string? txt) (say err ("Could not open file or uri for loading certificate from " + nm + ": No such file or directory\n"), 1)
                !(string? d) (say err ("Could not find certificate from " + nm + "\n"), 1)
                !(tablet? x) (say err ("Could not read certificate from " + nm + "\n"), 1)
                (: p (os-sink (peep st "-out" ()))
                   (? !(hot? p) (say err ("x509: cannot write " + st "-out" + "\n"), 1)
                      (: _ (each (rev (st 'acts)) (w \ say p (os-x509-act x st w)))
                         _ (? (st 'noout) 0
                              (say p (? (upper (peep st "-outform" "PEM") = "DER") d (os-pem d))))
                         (os-close p (st "-out"), 0))))))))
   (os-x509-act x st w)
    (w @ "-text" (os-lines (os-text x))
         "-subject" ("subject=" + os-dn (x 'subject) + "\n")
         "-issuer" ("issuer=" + os-dn (x 'issuer) + "\n")
         "-dates" ("notBefore=" + os-time (x 'nb) + "\nnotAfter=" + os-time (x 'na) + "\n")
         "-startdate" ("notBefore=" + os-time (x 'nb) + "\n")
         "-enddate" ("notAfter=" + os-time (x 'na) + "\n")
         "-serial" ("serial=" + os-up (b2hex (x 'serial)) + "\n")
         "-fingerprint" (: m (peep st 'md (os-md "-sha1")) (m 1 + " Fingerprint=" + os-up (os-colon (hex2b (m 2 (x 'der)))) + "\n"))
         "-pubkey" ("-----BEGIN PUBLIC KEY-----\n" + ubwrap 64 (ubenc ub64set 6 (x 'spki)) + "-----END PUBLIC KEY-----\n")
         "-ext"
          (: want (map (n \ peep os-extshort n n) (split "," (st "-ext")))
             es (filter (e \ elem <e want) (x 'exts))
             (? (atom? es) "No extensions in certificate\n"
                (catmap (e \ os-lines (os-extblock e 0 4)) es)))
         "")

   ; --- making: keys, requests and certificates, the tls module's cert.l doing the work ---
   (os-keyfile f) (: t (os-slurp f) (? (string? t) (os-tls 'key-read t) ()))
   ; s to file f, or stdout for none -> 1 | 0
   (os-write f s) (: p (os-sink f) (? (hot? p) (say p s, os-close p f, 1) 0))
   ; a private key to file f the way openssl lays one, 0600: a fresh name beside f made
   ; O_EXCL (openfd 3), then renamed over f, so no link is followed and no old mode kept
   (os-keywrite f s)
    (? !(string? f) (os-write f s)
       (: hx (os-tls 'hex) rn (os-tls 'rnd)
          tmp (f + "." + hx (rn 6) + ".tmp")
          fd (openfd tmp 3)
          (? !(charm? fd) 0
             (: p (fdopen fd) _ (say p s) _ (close p)
                (? !(rename tmp f) 1 (unlink tmp, 0))))))
   ; -algorithm and -pkeyopt -> 'ed25519 | 'p256 | ()
   (os-kind alg opt)
    (: a (upper alg)
       (? (a = "ED25519") 'ed25519
          (a = "EC" && elem opt ["ec_paramgen_curve:P-256" "ec_paramgen_curve:prime256v1"]) 'p256
          ()))
   ; a verb's words: vals take a value, ones stand alone, -addext gathers -> a tablet | ['bad w]
   (os-flags as vals ones)
    (: st {'addext ()}
       (go a)
        (? (atom? a) st
           (: w <a
              (? (elem w ones) (pin st w 1, go >a)
                 (!(elem w vals) || atom? >a) ['bad w]
                 (w = "-addext") (pin st 'addext (st 'addext + [<>a]), go >>a)
                 (pin st w <>a, go >>a))))
       (go as))
   (os-hex? s) (0 < #s && all (c \ elem c (chars "0123456789abcdefABCDEF")) (chars s))
   ; -set_serial: decimal or 0x hex -> n | ()
   (os-serial s)
    (? !(string? s) ()
       (2 < #s && snip s 0 2 = "0x") (: h (snip s 2 #s) (? (os-hex? h) (os-num (hex2b (#h % 2 = 1 ? ("0" + h) h))) ()))
       (unum s))
   ; -days, -not_before, -not_after -> [nb na] | why not
   (os-validity st)
    (: now (os-now 0)
       d (unum (peep st "-days" "30"))
       nb (? (string? (st "-not_before")) (os-tls 'time-arg (st "-not_before")) now)
       na (? (string? (st "-not_after")) (os-tls 'time-arg (st "-not_after")) (charm? d && charm? nb) (nb + d * 86400) ())
       (? (!(charm? d) || d < 1) "-days wants a count of days"
          !(charm? nb) "-not_before wants [CC]YYMMDDHHMMSSZ"
          !(charm? na) "-not_after wants [CC]YYMMDDHHMMSSZ"
          [nb na]))
   ; an extfile's "name = value" lines, of section sec ("" the unnamed one)
   (os-extfile t sec)
    (: (go l cur acc)
        (? (atom? l) (rev acc)
           (: s (strip <l)
              (? (s = "" || s 0 = 35) (go >l cur acc)
                 (s 0 = 91) (go >l (strip (snip s 1 (max 1 (#s - 1)))) acc)
                 (go >l cur (? (cur = sec) (s . acc) acc)))))
       (go (lines t) "" ()))
   ; x509 -req: the request, signed by -CA and -CAkey or self-signed by -signkey (-key) -> der | [why]
   (os-issue st)
    (: ct (os-slurp (st "-in"))
       cd (? (string? ct) (: ds (os-tls 'pem-in ct "CERTIFICATE REQUEST") (? (two? ds) <ds ct)) ())
       r (? (string? cd) (os-tls 'csr-read cd) "the request does not read")
       caf (st "-CA") self (peep st "-signkey" (st "-key"))
       ca (? (string? caf) (: t (os-slurp caf) (? (string? t) (os-der-in t) ())) ())
       cx (? (string? ca) (os-tls 'x509 ca) ())
       kf (? (string? caf) (peep st "-CAkey" caf) self)
       k (? (string? kf) (os-keyfile kf) ())
       v (os-validity st)
       ef (st "-extfile")
       et (? (string? ef) (os-slurp ef) ())
       (? !(string? ct) [("cannot read the request " + (? (string? (st "-in")) (st "-in") "on stdin"))]
          !(tablet? r) [r]
          (string? v) [v]
          (string? caf && !(tablet? cx)) [("cannot read the CA certificate " + caf)]
          (!(string? caf) && !(string? self)) ["-CA with -CAkey, or -signkey, is wanted to sign"]
          (atom? k) [("cannot read a private key from " + kf)]
          (string? ef && !(string? et)) [("cannot read the extfile " + ef)]
          (: sp (os-tls 'key-spki k)
             cp (? (elem (peep st "-copy_extensions" "none") ["copy" "copyall"]) (filter two? (map (os-tls 'ext-pair) (r 'exts))) ())
             fl (? (string? et) (os-extfile et (peep st "-extensions" "")) ())
             (? (string? caf && sp != cx 'key 2) ["the CA key does not match the CA certificate"]
                (!(string? caf) && sp != r 'spki) ["the key does not match the request"]
                (os-tls 'cert-make {'subject (r 'subject) 'issuer (? (string? caf) (cx 'subject) (r 'subject))
                                    'spki (r 'spki) 'key k 'nb <v 'na (v 1) 'serial (os-serial (st "-set_serial"))
                                    'akid (? (string? ca) (os-tls 'cert-kid ca) ())
                                    'exts (["subjectKeyIdentifier=hash" "authorityKeyIdentifier=keyid"] + cp + fl + st 'addext)})))))
   ; the extensions openssl's configuration gives a self-signed certificate
   os-ca-exts ["subjectKeyIdentifier=hash" "authorityKeyIdentifier=keyid:always" "basicConstraints=critical,CA:TRUE"]
   ; --- genpkey ---
   (os-genpkey as)
    (: st (os-flags as ["-algorithm" "-pkeyopt" "-out"] [])
       kind (? (tablet? st) (os-kind (peep st "-algorithm" "") (peep st "-pkeyopt" "")) ())
       (? !(tablet? st) (os-bad "genpkey" (st 1))
          !(elem kind ['ed25519 'p256]) (say err "genpkey: made here: -algorithm ed25519, or -algorithm EC -pkeyopt ec_paramgen_curve:P-256\n", 1)
          (os-keywrite (st "-out") (os-tls 'key-pem (os-tls 'key-new kind))) 0
          (say err ("genpkey: cannot write " + st "-out" + "\n"), 1)))
   ; --- req: a request, or with -x509 a self-signed certificate ---
   (os-req as)
    (: st (os-flags as ["-key" "-newkey" "-pkeyopt" "-keyout" "-subj" "-days" "-not_before" "-not_after"
                        "-set_serial" "-addext" "-out" "-outform"]
                    ["-new" "-x509" "-nodes" "-noenc" "-batch" "-sha256"])
       kf (? (tablet? st) (st "-key") ()) nk (? (tablet? st) (st "-newkey") ())
       kind (? (string? nk) (os-kind nk (peep st "-pkeyopt" "")) ())
       k (? (string? kf) (os-keyfile kf) (elem kind ['ed25519 'p256]) (os-tls 'key-new kind) ())
       nm (? (tablet? st && string? (st "-subj")) (os-tls 'name-der (st "-subj")) ())
       v (? (tablet? st) (os-validity st) ())
       (? !(tablet? st) (os-bad "req" (st 1))
          (atom? k) (say err (? (string? kf) ("req: cannot read a private key from " + kf + "\n")
                                "req: -key FILE, or -newkey ed25519 or ec with -pkeyopt ec_paramgen_curve:P-256, is wanted\n"), 1)
          !(string? nm) (say err "req: -subj /CN=../O=.. is wanted (nothing is asked here)\n", 1)
          (string? v) (say err ("req: " + v + "\n"), 1)
          (: kw (? (string? kf) 1 (os-keywrite (peep st "-keyout" "privkey.pem") (os-tls 'key-pem k)))
             sp (os-tls 'key-spki k)
             d (? (st "-x509")
                  (os-tls 'cert-make {'subject nm 'issuer nm 'spki sp 'key k 'nb <v 'na (v 1)
                                      'serial (os-serial (st "-set_serial")) 'exts (os-ca-exts + st 'addext)})
                  (os-tls 'csr-make k nm (st 'addext)))
             der? (upper (peep st "-outform" "PEM") = "DER")
             (? (kw = 0) (say err "req: cannot write the key\n", 1)
                !(string? d) (say err ("req: " + <d + "\n"), 1)
                (os-write (st "-out") (? der? d (os-tls 'pem-out (? (st "-x509") "CERTIFICATE" "CERTIFICATE REQUEST") d))) 0
                (say err ("req: cannot write " + st "-out" + "\n"), 1)))))

   ; --- verify's reasons, as openssl numbers and says them ---
   (os-vcode x k s)
    (s @ "it has expired" [10 "certificate has expired"]
         "it is not valid yet" [9 "certificate is not yet valid or the system clock is incorrect"]
         "its validity does not read" [13 "format error in certificate's notBefore field"]
         "its signature does not verify" [7 "certificate signature failure"]
         "it is not a certificate authority" [24 "invalid CA certificate"]
         "its keyUsage does not allow signing certificates" [32 "key usage does not include certificate signing"]
         "its pathLen is exceeded" [25 "path length constraint exceeded"]
         "a critical extension it does not know" [34 "unhandled critical extension"]
         "it is not for serving tls" [26 "unsupported certificate purpose"]
         ("the chain is too long" || "too much work to find its issuer") [22 "certificate chain too long"]
         "the server sent no certificate that reads" [1 "the certificate does not read here (its key or a field)"]
         "its nameConstraints does not read" [52 "unsupported or invalid name constraint syntax"]
         "it constrains a kind of name not checked here" [51 "unsupported name constraint type"]
         (: self (tablet? x && x 'subject = x 'issuer)
            (has? t) (: m #t (m <= #s && any (i \ snip s i (i + m) = t) ^(1 + #s - m)))
            (? (snip s 0 9 = "no issuer")
                (? (self && k = 0) [18 "self-signed certificate"]
                   self [19 "self-signed certificate in certificate chain"]
                   [20 "unable to get local issuer certificate"])
               (has? "names it may not vouch for") [48 "excluded subtree violation"]
               (has? "names it may vouch for") [47 "permitted subtree violation"]
               [1 s])))
   (os-now _) (clock 0 // 1000)
   ; a file's certificates as x509s, read by the tls module's reader
   (os-x509s txt) (filter tablet? (map (os-tls 'x509) (os-tls 'pem-ders txt)))

   ; --- verify ---
   (os-verify as)
    (: st {}
       (go a fs)
        (? (atom? a) (rev fs)
           (: w <a
              (? (w = "-CAfile" || w = "-untrusted")
                  (? (two? >a) (pin st w <>a, go >>a fs) (os-bad "verify" w))
                 (1 < #w && w 0 = 45) (os-bad "verify" w)
                 (go >a (w . fs)))))
       fs (go as ())
       _ (? (charm? fs) (uleave fs) 0)
       caf (peep st "-CAfile" ()) unf (peep st "-untrusted" ())
       ct (? (string? caf) (os-slurp caf) ())
       ut (? (string? unf) (os-slurp unf) "")
       roots (? (string? caf) (? (string? ct) (os-x509s ct) ()) (os-tls 'tls-roots 0 1))
       pool (? (string? ut) (os-tls 'pem-ders ut) ())
       (one f)
        (: nm (f = "-" ? "stdin" f)
           t (os-slurp f)
           d (? (string? t) (os-der-in t) ())
           r (? (string? d) (os-tls 'chain-fail (d . pool) roots () (os-now 0)) ())
           (? !(string? t) (say err ("Could not open file or uri for loading certificate from " + nm + "\n"), 0)
              !(string? d) (say err ("Could not find certificate from " + nm + "\n"), 0)
              (r = 1) (say out (nm + ": OK\n"), 1)
              (: x <r k <>r c (os-vcode x k (r 2))
                 (say err ((? (tablet? x) (os-dn (x 'subject) + "\n") "")
                           + "error " + show <c + " at " + show k + " depth lookup: " + c 1 + "\n"
                           + "error " + nm + ": verification failed\n"), 0))))
       (? (string? caf && !(string? ct)) (say err ("Could not open file or uri for loading certificate file from " + caf + "\n"), 2)
          (string? unf && !(string? ut)) (say err ("Could not open file or uri for loading certificate file from " + unf + "\n"), 2)
          (: ok (foldl (a \ f \ one f && a) 1 (? (two? fs) fs ["-"]))
             (flush out, ok ? 0 2))))

   ; --- dgst ---
   (os-dgst as)
    (: (go a m r fs)
        (? (atom? a) [m r (rev fs)]
           (: w <a md (os-md w)
              (? (two? md) (go >a [md (os-summd w)] r fs)
                 (w = "-r") (go >a m 1 fs)
                 (w = "-hex") (go >a m r fs)
                 (w = "--") [m r ((rev fs) + >a)]
                 (1 < #w && w 0 = 45) [w]
                 (go >a m r (w . fs)))))
       o (go as [["SHA256"] (os-summd "-sha256")] 0 ())
       (? (atom? >o) (say err ("dgst: Unrecognized flag " + <o + "\ndgst: Use -help for summary.\n"), 1)
          (: lab (o 0 0 0) mk (o 0 1) r? (o 1) fs (o 2)
             (row f)
              (: nm (f = "-" ? "stdin" f)
                 v (sum-run mk f)
                 (? (atom? v) (say err (nm + ": " + (? (v = 'dir) "Is a directory" (nom? v) (uerrno v) "cannot read") + "\n"), 0)
                    (say out (? r? (<v + " *" + nm + "\n") (lab + "(" + nm + ")= " + <v + "\n")), 1)))
             ok (foldl (a \ f \ row f && a) 1 (? (two? fs) fs ["-"]))
             (flush out, ok ? 0 1))))
   ; the digest triple sum.l streams a file through
   (os-summd w)
    (w @ "-md5" sum-md5d "-sha1" sum-sha1d "-sha224" sum-sha224d "-sha384" sum-sha384d
         "-sha512" sum-sha512d sum-shad)

   ; --- rand: the os's entropy or nothing ---
   (os-entropy n)
    (: q (open "/dev/urandom" "r")
       (? !(hot? q) ()
          (: (go acc have)
              (? (n <= have) (join "" (rev acc))
                 (: c (see q) (? (c < 0) () (: p (string c + chug q) (go (p . acc) (have + #p))))))
             r (go () 0)
             (close q, (string? r ? (snip r 0 n) ())))))
   (os-rand as)
    (: (go a f o ns)
        (? (atom? a) [f o (rev ns)]
           (: w <a
              (? (w = "-hex") (go >a 'hex o ns)
                 (w = "-base64") (go >a 'b64 o ns)
                 (w = "-out" && two? >a) (go >>a f <>a ns)
                 (1 < #w && w 0 = 45) ['bad w]
                 (go >a f o (w . ns)))))
       r (go as () () ())
       n (? (two? (r 2) && atom? >(r 2)) (unum <(r 2)) ())
       (? (<r = 'bad) (os-bad "rand" (r 1))
          (!(charm? n) || n < 1)
           (say err ((? (two? (r 2)) ("Invalid size suffix " + <(r 2) + "\n") "") + "rand: Use -help for summary.\n"), 1)
          (: b (os-entropy n)
             (? !(string? b) (say err "rand: cannot read the system's entropy (/dev/urandom); no bytes written\n", 1)
                (: p (os-sink (r 1))
                   (? !(hot? p) (say err ("rand: cannot write " + r 1 + "\n"), 1)
                      (say p (<r @ 'hex (b2hex b + "\n") 'b64 (ubwrap 64 (ubenc ub64set 6 b)) b), os-close p (r 1), 0)))))))

   ; --- base64 ---
   (os-b64 as)
    (: st {}
       (go a)
        (? (atom? a) 0
           (: w <a
              (? (w = "-d") (pin st 'd 1, go >a)
                 (w = "-e") (go >a)
                 (w = "-A") (pin st 'a 1, go >a)
                 ((w = "-in" || w = "-out") && two? >a) (pin st w <>a, go >>a)
                 (os-bad "base64" w))))
       r (go as)
       (? (r != 0) r
          (: t (os-slurp (peep st "-in" ()))
             (? !(string? t) (say err ("base64: cannot open " + st "-in" + "\n"), 1)
                (: v (? (st 'd)
                        (: s (string (filter (c \ !(elem c [9 10 13 32])) (map (i \ t i) ^#t)))
                           (ubdec ub64set 6 s @ [_ b] b ()))
                        (: e (ubenc ub64set 6 t) (? (st 'a) e (ubwrap 64 e))))
                   (? !(string? v) (say err "base64: bad base64 decode\n", 1)
                      (: p (os-sink (peep st "-out" ()))
                         (? !(hot? p) (say err ("base64: cannot write " + st "-out" + "\n"), 1)
                            (say p v, os-close p (st "-out"), 0)))))))))

   ; --- s_client ---
   os-cipher {16 "TLS_AES_128_GCM_SHA256" 32 "TLS_CHACHA20_POLY1305_SHA256"}
   ; "host:port", "[v6]:port" or a bare host (443) -> [host port] | ()
   (os-hostport s)
    (: cs (filter (i \ s i = 58) ^#s)
       k (? (two? cs) (last cs) -1)
       br (0 < #s && s 0 = 91)
       (? (br && 0 < k && s (k - 1) = 93) [(snip s 1 (k - 1)) (uport (snip s (k + 1) #s))]
          br ()
          (k < 0 || two? >cs) [s 443]
          [(snip s 0 k) (uport (snip s (k + 1) #s))]))
   (os-pkey x)
    (: k (os-keyof x)
       (<k @ 'rsa ("RSA, " + show (k 1) + " (bit)")
             'ec ("EC, (" + (: c (k 2) (? (two? c) <c "?")) + ")")
             'ed25519 "ED25519, 253 (bit)"
             (<k + ", " + show (k 1) + " (bit)")))
   (os-sclient as)
    (: st {}
       (go a)
        (? (atom? a) 0
           (: w <a
              (? (elem w ["-showcerts" "-verify_return_error" "-brief" "-quiet"]) (pin st w 1, go >a)
                 ((w = "-connect" || w = "-servername") && two? >a) (pin st w <>a, go >>a)
                 (!(1 < #w && w 0 = 45) && !(st "-connect")) (pin st "-connect" w, go >a)
                 (os-bad "s_client" w))))
       r0 (go as)
       hp (? (string? (st "-connect")) (os-hostport (st "-connect")) ())
       (? (r0 != 0) r0
          !(two? hp && charm? (hp 1)) (say err "s_client: -connect HOST:PORT is required\ns_client: Use -help for summary.\n", 1)
          (: host <hp port (hp 1)
             sni (peep st "-servername" host)
             brief (st "-brief") quiet (brief || st "-quiet")
             _ (? quiet 0 (say err ("Connecting to " + host + "\n"), flush err))
             t (os-tls 'tls-open-as host port sni 'none)
             (? !(tablet? t) (say err ("s_client: " + (? (string? t) t "no connection") + "\nconnect:errno=1\n"), 1)
                (os-session t st brief quiet)))))
   (os-session t st brief quiet)
    (: ders (t 'chain)
       xs (map os-cert ders)
       rv (os-tls 'chain-fail ders (os-tls 'tls-roots 0 1) () (os-now 0))
       code (? (rv = 1) [0 "ok"] (os-vcode <rv (rv 1) (rv 2)))
       fk (? (rv = 1) -1 (rv 1))
       (dn x) (? (tablet? x) (os-dn (x 'subject)) "?")
       (idn x) (? (tablet? x) (os-dn (x 'issuer)) "?")
       ; the chain as openssl's callback walks it, the top first
       _ (? quiet 0
            (each (rev ^#xs)
                  (i \ say err ("depth=" + show i + " " + dn (xs i) + "\n"
                                + (i = fk ? ("verify error:num=" + show <code + ":" + code 1 + "\n") "")
                                + "verify return:" + (i = fk && st "-verify_return_error" ? "0" "1") + "\n"))))
       _ (flush err)
       (? (0 < <code && st "-verify_return_error")
           (say err ("s_client: certificate verify failed: " + code 1 + "\n"), (os-tls 'tls-close) t, 1)
          (: cipher (peep os-cipher (tally (t 'ckey)) "?")
             leaf (? (two? xs) <xs ())
             _ (? brief
                  (say err ("CONNECTION ESTABLISHED\nProtocol version: TLSv1.3\nCiphersuite: " + cipher
                            + "\nPeer certificate: " + dn leaf + "\n"
                            + (0 = <code ? "Verification: OK\n" ("Verification error: " + code 1 + "\n"))
                            + "Negotiated TLS1.3 group: X25519\n"))
                  quiet 0
                  (say out ("CONNECTED\n---\nCertificate chain\n"
                            + catmap (i \ (: x (xs i)
                                             (" " + show i + " s:" + dn x + "\n   i:" + idn x + "\n"
                                              + (? (tablet? x) ("   a:PKEY: " + os-pkey x + "; sigalg: " + os-alg (x 'oalg) + "\n"
                                                                + "   v:NotBefore: " + os-time (x 'nb) + "; NotAfter: " + os-time (x 'na) + "\n") "")
                                              + (? (st "-showcerts") (os-pem (ders i)) ""))))
                                     ^#xs
                            + "---\n"
                            + (? (st "-showcerts" || !(two? ders)) "" ("Server certificate\n" + os-pem <ders))
                            + "subject=" + dn leaf + "\nissuer=" + idn leaf + "\n---\n"
                            + "Negotiated TLS1.3 group: X25519\n---\n"
                            + (0 = <code ? "Verification: OK\n" ("Verification error: " + code 1 + "\n")) + "---\n"
                            + "New, TLSv1.3, Cipher is " + cipher + "\nProtocol: TLSv1.3\n"
                            + (? (tablet? leaf) ("Server public key is " + show (os-keyof leaf 1) + " bit\n") "")
                            + "Verify return code: " + show <code + " (" + code 1 + ")\n---\n")))
             _ (flush out)
             (os-pump t))))
   ; stdin to the peer and the peer to stdout, each way its own task, until the peer closes.
   ; a terminal on stdin is not read, and an empty stdin asked nothing: the session is closed
   (os-pump t)
    (: bye (_ \ (flush out, say err "DONE\n", flush err))
       (? (two? (tty 0)) ((os-tls 'tls-close) t, 0)
          (: hear (os-tls 'tls-hear) speak (os-tls 'tls-say)
             (down _) (: s (hear t) (? (string? s) (say out s, flush out, down 0) (bye 0, quit 0)))
             d (twirl down 0)
             (up n) (: c (see in) (? (c < 0) n (: p (string c + chug in) _ (speak t p) (up (n + #p)))))
             sent (up 0)
             (? (0 < sent) (catch d, 0) (bye 0, (os-tls 'tls-close) t, 0)))))

   os-usage "usage: openssl COMMAND [ARGS..]   (love kore's subset; not OpenSSL)
commands:
  x509 [-in F] [-inform PEM|DER] [-noout] [-text] [-subject] [-issuer] [-dates] [-serial]
       [-fingerprint] [-md5|-sha1|-sha256..] [-ext NAMES] [-pubkey] [-outform PEM|DER] [-out F]
  x509 -req -in CSR (-CA F [-CAkey F] | -signkey F) [-days N] [-not_before T] [-not_after T]
       [-set_serial N] [-extfile F [-extensions S]] [-addext E].. [-copy_extensions copy] [-out F]
  genpkey -algorithm ed25519 | -algorithm EC -pkeyopt ec_paramgen_curve:P-256 [-out F]
  req -new [-x509] (-key F | -newkey ed25519|ec [-pkeyopt ..] [-keyout F]) -subj /CN=..
       [-days N] [-not_before T] [-not_after T] [-set_serial N] [-addext E].. [-outform PEM|DER] [-out F]
  s_client -connect HOST:PORT [-servername N] [-showcerts] [-verify_return_error] [-brief] [-quiet]
  verify [-CAfile F] [-untrusted F] [CERT..]
  dgst [-md5|-sha1|-sha224|-sha256|-sha384|-sha512] [-r] [FILE..]
  rand [-hex|-base64] [-out F] N
  base64 [-e|-d] [-A] [-in F] [-out F]
  version
"
   (openssl-main as)
    (? (atom? as) (say err os-usage, 1)
       (: c <as a >as
          (? (elem "-help" a) (say out os-usage, 0)
             (c @ "x509" (os-x509 a)
                  "s_client" (os-sclient a)
                  "verify" (os-verify a)
                  "dgst" (os-dgst a)
                  "genpkey" (os-genpkey a)
                  "req" (os-req a)
                  "rand" (os-rand a)
                  ("base64" || "enc") (? (c = "enc" && !(elem "-base64" a)) (say err "enc: only -base64 is here\n", 1)
                                         (os-b64 (filter (w \ w != "-base64") a)))
                  "version" (say out "love kore openssl (a subset; not OpenSSL)\n", 0)
                  "help" (say out os-usage, 0)
                  (say err ("Invalid command '" + c + "'; type \"help\" for a list.\n" + os-usage), 1))))))
) ; module kore
