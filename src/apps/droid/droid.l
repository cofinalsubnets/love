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
   am-usage """
    usage: am start|broadcast [-a ACTION] [-d URI] [-t TYPE] [-n PKG/CLASS] [-p PKG] [-c CATEGORY]..
                              [-e KEY VALUE].. [-f FLAGS]
      an intent, started as an activity or sent as a broadcast, through the bridge's door
      (LOVE_DROID): android's own am is refused an app's uid
    """
   pm-usage """
    usage: pm list packages [-f] | pm path PACKAGE
      the packages this app can see (android 11 on shows an app only those its manifest
      queries, or all with QUERY_ALL_PACKAGES: love apk -P), or where one's apk lies
    """
   settings-usage """
    usage: settings get system|secure|global KEY | settings put system KEY VALUE
      a setting's value, null when unset; put needs the user's WRITE_SETTINGS grant, and
      secure and global are android's own to write
    """
   dr-ns {"system" "android/provider/Settings$System" "secure" "android/provider/Settings$Secure"
          "global" "android/provider/Settings$Global"}
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

   ; --- the framework's door (LOVE_DROID; the ops are bridge.c's header) ---
   ; an answer is a handle's number, () for null, a primitive's text, or [kind text] for
   ; what was thrown ('x) or refused ('e): a found-test is (two? r). a session holds 256
   ; handles: let go what is done with
   (jni-open _) (getenv "LOVE_DROID" @ p (string? p ? (connect ['unix p])))
   (jni-rd s n) (: (go k acc) (k < 1 ? (two? acc ? (cats (rev acc)) "") (see s @ c (c < 0 ? () (go (k - 1) (string c . acc))))) (go n ()))
   (jni-op s body)
    (: _ (say s (wrle #body 4 + body), flush s)
       n (jni-rd s 4) k (string? n ? (see s) -1) t (0 <= k ? (jni-rd s (rdle n 0 4 - 1)))
       (? !(string? t) ['e "the bridge hung up"]
          (k @ 104 (read t) 122 () 118 t 116 t
               120 ['x t] ['e t])))
   ; an op on arguments: a text becomes a String for it, let go after; a number is its
   ; decimal, () null
   (jni-str s t) (jni-op s ("s" + t))
   (jni-cmd s pre as)
    (: hs (map (x \ string? x ? (jni-str s x) x) as)
       bad (filter two? hs)
       (? (two? bad) <bad
          (: r (jni-op s (pre + cats (map (x \ string 0 + (charm? x ? (show x) "")) hs)))
             (each ^#as (i \ string? (as i) ? (jni-drop s (hs i)) 0), r))))
   (jni-act s) (jni-op s "a")
   (jni-class s nm) (jni-op s ("c" + nm))
   (jni-call s h nm sig as) (jni-cmd s ("m" + show h + string 0 + nm + string 0 + sig) as)
   (jni-static s c nm sig as) (jni-cmd s ("k" + show c + string 0 + nm + string 0 + sig) as)
   (jni-new s c sig as) (jni-cmd s ("n" + show c + string 0 + sig) as)
   (jni-get s h nm ty) (jni-op s ("g" + show h + string 0 + nm + string 0 + ty))
   (jni-sget s c nm ty) (jni-op s ("f" + show c + string 0 + nm + string 0 + ty))
   (jni-text s h) (jni-op s ("t" + show h))
   (jni-drop s h) (charm? h ? (jni-op s ("d" + show h)) 0)

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

   ; --- am, pm and settings over the door ---
   (dr-door who) (jni-open 0 @ s (hot? s ? s (udie 1 (who + ": not under android's bridge (no LOVE_DROID)"))))
   (dr-ok who r) (two? r ? (udie 1 (who + ": " + (r 1))) r)
   (am-opts as t)
    (as @ ("-a" . v . r) (am-opts r (pin t 'a v)) ("-d" . v . r) (am-opts r (pin t 'd v))
          ("-t" . v . r) (am-opts r (pin t 't v)) ("-n" . v . r) (am-opts r (pin t 'n v))
          ("-p" . v . r) (am-opts r (pin t 'p v)) ("-c" . v . r) (am-opts r (pin t 'c (t 'c + [v])))
          (("-e" || "--es") . k . v . r) (am-opts r (pin t 'e (t 'e + [[k v]])))
          ("-f" . v . r) (am-opts r (pin t 'f (read v)))
          () t
          _ (udie 2 am-usage))
   (am-main as)
    (: verb <as
       _ (elem verb ["start" "broadcast"] ? 0 (udie 2 am-usage))
       t (am-opts >as {})
       s (dr-door "am")
       (ok r) (dr-ok "am" r)
       i (ok (jni-new s (ok (jni-class s "android/content/Intent")) "()V" ()))
       (on nm sig as) (jni-drop s (ok (jni-call s i nm sig as)))
       it "Landroid/content/Intent;"
       uri (string? (t 'd) ? (ok (jni-static s (ok (jni-class s "android/net/Uri")) "parse" "(Ljava/lang/String;)Landroid/net/Uri;" [(t 'd)])))
       ty (string? (t 't) ? (t 't))
       _ (string? (t 'a) ? (on "setAction" ("(Ljava/lang/String;)" + it) [(t 'a)]) 0)
       _ (? (charm? uri && string? ty) (on "setDataAndType" ("(Landroid/net/Uri;Ljava/lang/String;)" + it) [uri ty])
            (charm? uri) (on "setData" ("(Landroid/net/Uri;)" + it) [uri])
            (string? ty) (on "setType" ("(Ljava/lang/String;)" + it) [ty])
            0)
       _ (string? (t 'n) ?
            (: cn (ok (jni-static s (ok (jni-class s "android/content/ComponentName")) "unflattenFromString"
                                  "(Ljava/lang/String;)Landroid/content/ComponentName;" [(t 'n)]))
               (charm? cn ? (on "setComponent" ("(Landroid/content/ComponentName;)" + it) [cn])
                  (udie 2 ("am: not a component: " + t 'n))))
            0)
       _ (string? (t 'p) ? (on "setPackage" ("(Ljava/lang/String;)" + it) [(t 'p)]) 0)
       _ (each (t 'c) (c \ on "addCategory" ("(Ljava/lang/String;)" + it) [c]))
       _ (each (t 'e) (kv \ on "putExtra" ("(Ljava/lang/String;Ljava/lang/String;)" + it) kv))
       _ (charm? (t 'f) ? (on "addFlags" ("(I)" + it) [(t 'f)]) 0)
       go (verb = "start")
       (puts ((go ? "Starting: " "Broadcasting: ") + ok (jni-text s i) + "\n"),
        ok (jni-call s (ok (jni-act s)) (go ? "startActivity" "sendBroadcast") ("(" + it + ")V") [i]),
        close s, 0))
   (pm-main as)
    (: s (dr-door "pm")
       (ok r) (dr-ok "pm" r)
       pk (ok (jni-call s (ok (jni-act s)) "getPackageManager" "()Landroid/content/pm/PackageManager;" ()))
       (field h nm ty) (ok (jni-get s h nm ty))
       (text h nm) (field h nm "Ljava/lang/String;" @ f (charm? f ? (ok (jni-text s f) @ x (jni-drop s f, x)) ""))
       (src pi) (field pi "applicationInfo" "Landroid/content/pm/ApplicationInfo;" @ ai (text ai "sourceDir" @ x (jni-drop s ai, x)))
       (listed f?)
        (: l (ok (jni-call s pk "getInstalledPackages" "(I)Ljava/util/List;" [0]))
           n (read (ok (jni-call s l "size" "()I" ())))
           (each ^n (i \ : pi (ok (jni-call s l "get" "(I)Ljava/lang/Object;" [i]))
                         (puts ("package:" + (f? ? (src pi + "=") "") + text pi "packageName" + "\n"), jni-drop s pi))))
       (as @ ["list" "packages"] (listed 0, close s, 0)
             ["list" "packages" "-f"] (listed 1, close s, 0)
             ["path" p] (: ai (ok (jni-call s pk "getApplicationInfo" "(Ljava/lang/String;I)Landroid/content/pm/ApplicationInfo;" [p 0]))
                           (puts ("package:" + text ai "sourceDir" + "\n"), close s, 0))
             _ (udie 2 pm-usage)))
   (settings-main as)
    (: ns (two? >as ? (dr-ns (as 1)))
       _ (string? ns && (as @ ["get" _ _] 1 ["put" _ _ _] 1 _ 0) ? 0 (udie 2 settings-usage))
       s (dr-door "settings")
       (ok r) (dr-ok "settings" r)
       cr (ok (jni-call s (ok (jni-act s)) "getContentResolver" "()Landroid/content/ContentResolver;" ()))
       c (ok (jni-class s ns))
       sig "(Landroid/content/ContentResolver;Ljava/lang/String;"
       (? (<as = "get")
          (: v (ok (jni-static s c "getString" (sig + ")Ljava/lang/String;") [cr (as 2)]))
             (puts ((charm? v ? (ok (jni-text s v)) "null") + "\n"), close s, 0))
          (: w (ok (jni-static s c "putString" (sig + "Ljava/lang/String;)Z") [cr (as 2) (as 3)]))
             (close s, w = "1" ? 0 (udie 1 ("settings: not written: " + as 2))))))

   door (udoor 'apk apk-main apk-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'apk door 'am (udoor 'am am-main am-usage 1 1) 'pm (udoor 'pm pm-main pm-usage 1 1)
           'settings (udoor 'settings settings-main settings-usage 1 1))
   s (cite 'verbs 'fire ["apk" "droid.l"])
   _ (two? s ? (quit (door >s)) 0))
) ; module droid
