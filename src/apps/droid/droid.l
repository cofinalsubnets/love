; src/apps/droid/droid.l -- love apps on android: the face a program draws through, and the apk.
;
;   love apk [-o OUT.apk] [-p PACKAGE] [-n LABEL] [-L LOVE] [-P PERM].. MAIN.l [FILE..]
;
; the app is a NativeActivity with no dex: bridge.c, built by our `mooncc -t a64 -shared`, owns
; the window, input and logcat and starts LOVE (an a64 love, already baked: its library
; directory is read-only) from lib/arm64-v8a/liblove.so. MAIN.l and the FILEs ride as assets
; in the app's data directory, love's cwd and HOME. the apk is signed (scheme v2) by a p-256
; key in ~/.love/etc/apk.pem, made on first use: android takes an update only under the same
; certificate, so keep that file.
;
; the face (the wire is bridge.c's header):
;   (face-open _)        -> a port to the bridge, () when not under one
;   (face-next s)        -> [kind a b c], () when the bridge is gone
;   (face-frame s w h fb) a frame of w*h words 0x00rrggbb, scaled onto the window
(module 'droid
(borrow 'posix)
(borrow 'bytes)
(borrow 'hashes)
(borrow 'gz)
(borrow 'tar)
(borrow 'tls)
(:
   ap-net "android.permission.INTERNET"           ; a normal permission: granted at install, never asked
   ; --- the face ---
   (face-open _) (getenv "LOVE_FACE" @ p (string? p ? (connect ['unix p])))
   (face-next s)
    (: k (see s)
       (k < 0 ? ()
          (: a (see s) _ (see s) _ (see s)
             (i32 _) (: v (foldl (\ v i (v | (see s << (8 * i)))) 0 ^4) (? (v >= 2147483648) (v - 4294967296) v))
             b (i32 0) c (i32 0)
             [k a b c])))
   (face-frame s w h fb) (say s ("F" + wrle w 2 + wrle h 2 + wrle 0 2 + wrle h 2), say s fb, flush s)

   ; --- the binary manifest (android's axml) ---
   ; an element is [tag attrs kids], an attribute [android? name kind value], kind 'int 'hex
   ; 'bool or 'str. attributes are known by resource id, which the map chunk gives the first
   ; strings of the pool, so those lead it, in id order.
   ax-uri "http://schemas.android.com/apk/res/android"
   ax-rid {"label" 0x01010001 "name" 0x01010003 "hasCode" 0x0101000c "debuggable" 0x0101000f
           "exported" 0x01010010 "configChanges" 0x0101001f "value" 0x01010024
           "minSdkVersion" 0x0101020c "versionCode" 0x0101021b "versionName" 0x0101021c
           "windowSoftInputMode" 0x0101022b "targetSdkVersion" 0x01010270 "extractNativeLibs" 0x010104ea}
   (ap-cat f l) (cats (map f l))
   (ax-chunk ty hs body) (wrle ty 2 + wrle hs 2 + wrle (8 + #body) 4 + body)
   (ax-u16 s) (ap-cat (c \ wrle c 2) (chars s))
   (ax-uniq l) (foldl (\ a s (elem s a ? a (a + [s]))) () l)
   (ap-axml root)
    (: (walk e) (e @ [t at ks] (map (a \ [<a (a 1)]) at
                                    + map (a \ [0 (a 3)]) (filter (a \ a 2 = 'str) at)
                                    + [[0 t]] + catmap walk ks))
       all (walk root)
       an (map (p \ p 1) (sort (ax-uniq (map (p \ [(ax-rid (p 1)) (p 1)]) (filter (p \ <p = 1) all)))))
       strs (ax-uniq (an + ["android" ax-uri] + map (p \ p 1) (filter (p \ <p = 0) all)))
       ix {} _ (each ^#strs (i \ pin ix (strs i) i))
       (u32 v) (wrle v 4)
       offs (foldl (\ a s (a + [(last a + 4 + 2 * #(chars s))])) [0] strs)
       data (ap-cat (s \ wrle #(chars s) 2 + ax-u16 s + wrle 0 2) strs)
       pool (ax-chunk 1 28 (u32 #strs + u32 0 + u32 0 + u32 (28 + 4 * #strs) + u32 0
                            + ap-cat u32 (rev >(rev offs)) + data + zbytes (padk #data 4)))
       rmap (ax-chunk 0x180 8 (ap-cat (n \ u32 (ax-rid n)) an))
       (nsc ty) (ax-chunk ty 16 (u32 1 + u32 -1 + u32 (ix "android") + u32 (ix ax-uri)))
       (attr [ns n k v])
        ((? ns (u32 (ix ax-uri)) (u32 -1)) + u32 (ix n) + u32 (? (k = 'str) (ix v) -1) + wrle 8 2 + string [0]
         + (k @ 'int (string [16] + u32 v) 'hex (string [17] + u32 v) 'bool (string [18] + u32 (? v -1 0))
                (string [3] + u32 (ix v))))
       (el [t at ks])
        (: so (sort (map (a \ [(? <a (ax-rid (a 1)) -1) a]) at))
           (ax-chunk 0x102 16 (u32 1 + u32 -1 + u32 -1 + u32 (ix t) + wrle 20 2 + wrle 20 2
                               + wrle #so 2 + zbytes 6 + ap-cat (p \ attr (p 1)) so)
            + ap-cat el ks
            + ax-chunk 0x103 16 (u32 1 + u32 -1 + u32 -1 + u32 (ix t))))
       (ax-chunk 3 8 (pool + rmap + nsc 0x100 + el root + nsc 0x101)))
   ; ps the permissions asked, each android's full name; the network is every app's
   (ap-manifest pkg label ps)
    ["manifest" [[1 "versionCode" 'int 1] [1 "versionName" 'str "1"] [0 "package" 'str pkg]]
      ([["uses-sdk" [[1 "minSdkVersion" 'int 26] [1 "targetSdkVersion" 'int 31]] ()]]
       + map (p \ ["uses-permission" [[1 "name" 'str p]] ()])
             (elem ap-net ps ? ps ([ap-net] + ps)) +
      [["application" [[1 "label" 'str label] [1 "hasCode" 'bool 0] [1 "debuggable" 'bool 1]
                      [1 "extractNativeLibs" 'bool 1]]
         [["activity" [[1 "name" 'str "android.app.NativeActivity"] [1 "exported" 'bool 1]
                      [1 "configChanges" 'hex 0x4a0]                   ; orientation keyboardHidden screenSize
                     [1 "windowSoftInputMode" 'hex 0x10]]             ; adjustResize: the keyboard never pans the window
            [["meta-data" [[1 "name" 'str "android.app.lib_name"] [1 "value" 'str "bridge"]] ()]
             ["intent-filter" ()
               [["action" [[1 "name" 'str "android.intent.action.MAIN"]] ()]
                ["category" [[1 "name" 'str "android.intent.category.LAUNCHER"]] ()]]]]]]]])]

   ; --- the zip: every entry deflated, dated 1980, so the same inputs lay the same bytes ---
   (ap-zip es)
    (: j (jug 0)
       (u16 v) (wrle v 2) (u32 v) (wrle v 4)
       (one [cd off] [nm d])
        (: z (deflate d) c (gz-crc32 d)
           h (u16 20 + u16 0 + u16 8 + u16 0 + u16 33 + u32 c + u32 #z + u32 #d + u16 #nm + u16 0)
           (say j ("PK" + string [3 4] + h + nm), say j z,
            [(cd + "PK" + string [1 2] + u16 20 + h + u16 0 + u16 0 + u16 0 + u32 0 + u32 off + nm)
             (off + 30 + #nm + #z)]))
       r (foldl one ["" 0] es)
       (say j <r,
        say j ("PK" + string [5 6] + u16 0 + u16 0 + u16 #es + u16 #es + u32 #<r + u32 (r 1) + u16 0),
        slurp j))

   ; --- apk signature scheme v2: the zip's three sections digested in 1 MiB chunks, the
   ; digest signed, the block laid before the central directory ---
   (ap-sha s) (unhex (sha256 s))
   (ap-lp s) (wrle #s 4 + s)
   (v2-digest ss)
    (: cs (catmap (s \ map (i \ snip s i (min #s (i + 1048576))) (map (* 1048576) ^((#s + 1048575) // 1048576))) ss)
       (ap-sha (string [90] + wrle #cs 4 + ap-cat (c \ ap-sha (string [165] + wrle #c 4 + c)) cs)))
   (v2-sign z key cert)
    (: eo (#z - 22) co (rdle z (eo + 16) 4)
       s0 (snip z 0 co) s1 (snip z co eo) s2 (snip z eo #z)
       sd (ap-lp (ap-lp (wrle 0x201 4 + ap-lp (v2-digest [s0 s1 s2]))) + ap-lp (ap-lp cert) + ap-lp "")
       sg (ap-lp sd + ap-lp (ap-lp (wrle 0x201 4 + ap-lp (key-sign key sd))) + ap-lp (key-spki key))
       v2 (ap-lp (ap-lp sg))
       pr (wrle (4 + #v2) 8 + wrle 0x7109871a 4 + v2)
       n (#pr + 24)
       blk (wrle n 8 + pr + wrle n 8 + "APK Sig Block 42")
       (s0 + blk + s1 + snip s2 0 16 + wrle (co + #blk) 4 + snip s2 20 #s2))

   ; --- the key and its certificate, made once ---
   (apk-keys _)
    (: f (getenv "HOME" + "/.love/etc/apk.pem")
       t (uread f @ r (two? r ? <>r))
       (? (string? t) (: k (key-read t) c (pem-in t "CERTIFICATE") (two? c && two? k ? [k <c]))
          (: k (key-new 'p256) nm (name-der "/CN=love")
             c (cert-make {'spki (key-spki k) 'exts () 'key k 'serial 1 'issuer nm 'subject nm
                           'nb 1767225600 'na 3345062400})
             (? (string? c && (umkdirs (getenv "HOME" + "/.love/etc") 448, uwrite f (key-pem k + pem-out "CERTIFICATE" c)))
                [k c]))))

   ; --- the bridge, compiled out of the source this love carries ---
   (bridge-src _)
    (: a (tree-tar 0) t (? (string? a) (tar-unpack a))
       (? (two? t) (foldl (\ r e (? (string? r) r (ends? (tar-get e 'nom "") "src/apps/droid/bridge.c") (tar-get e 'body "") ()))
                          () <>t)))
   (bridge-so tmp)
    (: c (bridge-src 0)
       _ (string? c ? 0 (udie 1 "apk: this love carries no src/apps/droid/bridge.c"))
       src (tmp + "/bridge.c") so (tmp + "/libbridge.so")
       (uwrite src c,
        (? ((cite 'moon 'moon-run) ["-t" "a64" "-shared" "-landroid" "-llog" "-laaudio" "-ldl" "-lc" "-o" so src] != 0)
           (udie 1 "apk: the bridge does not compile")
           (uread so @ r (? (two? r) <>r (udie 1 "apk: no bridge laid"))))))

   (apk-usage _) (puts """
    usage: love apk [-o OUT.apk] [-p PACKAGE] [-n LABEL] [-L LOVE] [-b LINE] [-P PERM].. MAIN.l [FILE..]
      an android app (arm64) that runs MAIN.l: a window, touch and keys through the face
      (src/apps/droid/droid.l). LOVE is the a64 love it ships, baked; on an a64 machine
      this one. -b starts LOVE on LINE's words instead, MAIN.l then optional. the app has the
      network; each PERM is a permission it asks for at its start, RECORD_AUDIO for the mic
      (android.permission. unless named in full).
      the key signing it lives in ~/.love/etc/apk.pem
    """)
   (ap-base p) (p @ (_ + "/" + s) (ap-base s) p)
   (ap-stem p) (ap-base p @ b (b @ (s + ".l") s b))
   (ap-or s d) (? (string? s) s d)
   (apk-opts as t)
    (as @ ("-o" . v . r) (apk-opts r (pin t 'o v)) ("-p" . v . r) (apk-opts r (pin t 'p v))
          ("-n" . v . r) (apk-opts r (pin t 'n v)) ("-L" . v . r) (apk-opts r (pin t 'L v))
          ("-b" . v . r) (apk-opts r (pin t 'b v))
          ("-P" . v . r) (apk-opts r (pin t 'P (t 'P + [(has? v "." ? v ("android.permission." + v))])))
          (("-h" || "--help") . _) (apk-usage 0, quit 0)
          (("-" + _) . _) (apk-usage 0, quit 2)
          r (pin t 'files r))
   (apk-main as)
    (: t (apk-opts as {})
       fs (t 'files)
       _ (two? fs || string? (t 'b) ? 0 (apk-usage 0, quit 2))
       nm (? (two? fs) (ap-stem <fs) (ap-or (t 'n) "love"))
       out (ap-or (t 'o) (nm + ".apk"))
       pkg (ap-or (t 'p) ("pics.salt." + nm))
       lov (? (string? (t 'L)) (t 'L) (love-arch = 'a64) (selfpath 0)
              (udie 1 "apk: name an a64 love with -L (`love seed a64 DIR`, baked once on an a64 machine)"))
       lb (uread lov @ r (? (two? r) <>r (udie 1 ("apk: cannot read " + lov))))
       ks (apk-keys 0)
       _ (two? ks ? 0 (udie 1 "apk: no key in ~/.love/etc/apk.pem, and none could be made"))
       tmp ((ap-or (getenv "TMPDIR") "/tmp") + "/love-apk-" + show (getpid 0))
       _ (mkdir tmp 448)
       so (bridge-so tmp)
       ins (map (f \ [("assets/app/" + ap-base f) (uread f @ r (? (two? r) <>r (udie 1 ("apk: cannot read " + f))))]) fs)
       ps (t 'P)
       z (ap-zip ([["AndroidManifest.xml" (ap-axml (ap-manifest pkg (ap-or (t 'n) nm) ps))]
                ["lib/arm64-v8a/libbridge.so" so] ["lib/arm64-v8a/liblove.so" lb]
                ["assets/argv" (? (string? (t 'b)) (foldl (a \ w \ a + w + string [0]) "" (filter (w \ 0 < #w) (split " " (t 'b))))
                                  (ap-base <fs + string [0]))]]
                + (two? ps ? [["assets/perms" (cats (map (p \ p + string [0]) ps))]] ()) + ins))
       (? (uwrite out (v2-sign z <ks (ks 1))) (puts ("apk: " + out + " (" + pkg + ") -- adb install -r " + out + "\n"), 0)
          (udie 1 ("apk: cannot write " + out))))

   door (udoor 'apk apk-main apk-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'apk door)
   s (cite 'verbs 'fire ["apk" "droid.l"])
   _ (two? s ? (quit (door >s)) 0))
) ; module droid
