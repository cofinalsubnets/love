; src/apps/droid/droid.l -- love apps on android: the face a program draws through, and the apk.
;
;   love apk [-o OUT.apk] [-p PACKAGE] [-n LABEL] [-L LOVE] [-s] [-P PERM].. MAIN.l [FILE..]
;
; the app is a NativeActivity, no dex but `-s`'s one class: bridge.c, built by our `mooncc -shared` per abi, owns
; the window, input and logcat and starts LOVE (an a64 love, already baked: its library
; directory is read-only) from lib/ABI/liblove.so. MAIN.l and the FILEs ride as assets
; in the app's data directory, love's cwd and HOME. the apk is signed (scheme v2) by a p-256
; key in ~/.love/etc/apk.pem, made on first use: android takes an update only under the same
; certificate, so keep that file.
;
; the face (the wire is bridge.c's header):
;   (face-open _)        -> a port to the bridge, () when not under one
;   (face-next s)        -> [kind a b c], () when the bridge is gone
;   (face-frame s w h fb) a frame of w*h words 0x00rrggbb, scaled onto the window
(module 'droid
(borrow '(posix bytes hashes gz tar tls cli))
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
   ; the app held sideways, or as the phone likes; nothing off a phone
   (droid-side on)
    (jni-open 0 @ s
       (port? s ? (: a (jni-act s) (charm? a ? (jni-call s a "setRequestedOrientation" "(I)V" [(on ? 6 -1)])), close s)))
   ; a uri to what views it, an ACTION_VIEW intent the activity starts: 0, or the failed step's answer
   (droid-view s u)
    (: (on r k) (two? r ? r (k r))
       (on (jni-class s "android/net/Uri") (uc \
        on ((jni-static s uc "parse" "(Ljava/lang/String;)Landroid/net/Uri;" [u]) @ r (jni-drop s uc, r)) (ur \
        on (jni-class s "android/content/Intent") (ic \
        on ((jni-new s ic "(Ljava/lang/String;Landroid/net/Uri;)V" ["android.intent.action.VIEW" ur]) @ r
            (jni-drop s ic, jni-drop s ur, r)) (i \
        on (jni-act s) (a \
        (jni-call s a "startActivity" "(Landroid/content/Intent;)V" [i]) @ r (jni-drop s i, jni-drop s a, two? r ? r 0))))))))

   ; --- the binary manifest (android's axml) ---
   ; an element is [tag attrs kids], an attribute [android? name kind value], kind 'int 'hex
   ; 'bool 'ref or 'str. attributes are known by resource id, which the map chunk gives the first
   ; strings of the pool, so those lead it, in id order.
   ax-uri "http://schemas.android.com/apk/res/android"
   ax-rid {"label" 0x01010001 "icon" 0x01010002 "name" 0x01010003 "drawable" 0x01010199 "hasCode" 0x0101000c "debuggable" 0x0101000f
           "exported" 0x01010010 "launchMode" 0x0101001d "configChanges" 0x0101001f "value" 0x01010024
           "minSdkVersion" 0x0101020c "versionCode" 0x0101021b "versionName" 0x0101021c
           "windowSoftInputMode" 0x0101022b "targetSdkVersion" 0x01010270 "extractNativeLibs" 0x010104ea
           "foregroundServiceType" 0x01010599}
   (ap-cat f l) (cats (map f l))
   (ax-chunk ty hs body) (wrle ty 2 + wrle hs 2 + wrle (8 + #body) 4 + body)
   (ax-u16 s) (ap-cat (c \ wrle c 2) (chars s))
   (ax-uniq l) (foldl (\ a s (elem s a ? a (a + [s]))) () l)
   ; a string pool, utf-16
   (ax-pool strs)
    (: (u32 v) (wrle v 4)
       offs (foldl (\ a s (a + [(last a + 4 + 2 * #(chars s))])) [0] strs)
       data (ap-cat (s \ wrle #(chars s) 2 + ax-u16 s + wrle 0 2) strs)
       (ax-chunk 1 28 (u32 #strs + u32 0 + u32 0 + u32 (28 + 4 * #strs) + u32 0
                       + ap-cat u32 (rev >(rev offs)) + data + zbytes (padk #data 4))))
   (ap-axml root)
    (: (walk e) (e @ [t at ks] (map (a \ [<a (a 1)]) at
                                    + map (a \ [0 (a 3)]) (filter (a \ a 2 = 'str) at)
                                    + [[0 t]] + catmap walk ks))
       all (walk root)
       an (map (p \ p 1) (sort (ax-uniq (map (p \ [(ax-rid (p 1)) (p 1)]) (filter (p \ <p = 1) all)))))
       strs (ax-uniq (an + ["android" ax-uri] + map (p \ p 1) (filter (p \ <p = 0) all)))
       ix {} _ (each ^#strs (i \ pin ix (strs i) i))
       (u32 v) (wrle v 4)
       pool (ax-pool strs)
       rmap (ax-chunk 0x180 8 (ap-cat (n \ u32 (ax-rid n)) an))
       (nsc ty) (ax-chunk ty 16 (u32 1 + u32 -1 + u32 (ix "android") + u32 (ix ax-uri)))
       (attr [ns n k v])
        ((? ns (u32 (ix ax-uri)) (u32 -1)) + u32 (ix n) + u32 (? (k = 'str) (ix v) -1) + wrle 8 2 + string [0]
         + (k @ 'int (string [16] + u32 v) 'hex (string [17] + u32 v) 'bool (string [18] + u32 (? v -1 0))
                'ref (string [1] + u32 v)
                (string [3] + u32 (ix v))))
       (el [t at ks])
        (: so (sort (map (a \ [(? <a (ax-rid (a 1)) -1) a]) at))
           (ax-chunk 0x102 16 (u32 1 + u32 -1 + u32 -1 + u32 (ix t) + wrle 20 2 + wrle 20 2
                               + wrle #so 2 + zbytes 6 + ap-cat (p \ attr (p 1)) so)
            + ap-cat el ks
            + ax-chunk 0x103 16 (u32 1 + u32 -1 + u32 -1 + u32 (ix t))))
       (ax-chunk 3 8 (pool + rmap + nsc 0x100 + el root + nsc 0x101)))
   dx-name "pics.salt.love.Service"                    ; bridge.c starts it by this name
   ; the resource ids of the icon's table, ic-arsc
   ic-bg 0x7f010000 ic-fg 0x7f010001 ic-icon 0x7f010002
   ; ps the permissions asked, each android's full name; the network is every app's.
   ; o: 'code 'name the version, 'target the sdk, 'debug. target 34 wants a stay service's type named
   (ap-manifest pkg label ps stay o)
    ["manifest" [[1 "versionCode" 'int (o 'code)] [1 "versionName" 'str (o 'name)] [0 "package" 'str pkg]]
      ([["uses-sdk" [[1 "minSdkVersion" 'int 26] [1 "targetSdkVersion" 'int (o 'target)]] ()]]
       + map (p \ ["uses-permission" [[1 "name" 'str p]] ()])
             (elem ap-net ps ? ps ([ap-net] + ps))
       + (stay ? [["uses-permission" [[1 "name" 'str "android.permission.FOREGROUND_SERVICE"]] ()]] ())
       + (stay && o 'target >= 34 ? [["uses-permission" [[1 "name" 'str "android.permission.FOREGROUND_SERVICE_SPECIAL_USE"]] ()]] ()) +
      [["application" [[1 "label" 'str label] [1 "icon" 'ref ic-icon] [1 "hasCode" 'bool stay] [1 "debuggable" 'bool (o 'debug)]
                      [1 "extractNativeLibs" 'bool 1]]
         ((stay ? [(o 'target >= 34
                    ? ["service" [[1 "name" 'str dx-name] [1 "exported" 'bool 0] [1 "foregroundServiceType" 'hex 0x40000000]]
                        [["property" [[1 "name" 'str "android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"]
                                      [1 "value" 'str "keeps the user's running programs alive"]] ()]]]
                    ["service" [[1 "name" 'str dx-name] [1 "exported" 'bool 0]] ()])] ()) +
         [["activity" ([[1 "name" 'str "android.app.NativeActivity"] [1 "exported" 'bool 1]
                      [1 "configChanges" 'hex 0x4a0]                   ; orientation keyboardHidden screenSize
                     [1 "windowSoftInputMode" 'hex 0x10]]             ; adjustResize: the keyboard never pans the window
                     + (stay ? [[1 "launchMode" 'int 2]] ()))          ; singleTask: the notification finds the one task
            [["meta-data" [[1 "name" 'str "android.app.lib_name"] [1 "value" 'str "bridge"]] ()]
             ["intent-filter" ()
               [["action" [[1 "name" 'str "android.intent.action.MAIN"]] ()]
                ["category" [[1 "name" 'str "android.intent.category.LAUNCHER"]] ()]]]]]])]])]

   ; --- the icon: cp437's heart, the favicon's, in the front page's red on its ground. adaptive,
   ; so a launcher fills its own shape: 108dp at the top density, the heart in the middle 66 ---
   ic-rows [0x6c 0xfe 0xfe 0xfe 0x7c 0x38 0x10]        ; cga_8x8.c's cell 3
   (ic-rgb nm)                                         ; a role of hue-page's tokyo-night -> 0xrrggbb
    (: (row k l) (? (atom? l) () (<<l = k) <l (row k >l))
       hex <>(row nm ((row 'tokyo-night (cite 'vi 'hue-page)) 1))
       (read ("0x" + snip hex 1 7)))
   ; one bit a pixel, ink on clear: 54 bytes a row, 13 of them margin, a glyph pixel 4 bytes square
   (ic-png _)
    (: (chunk ty d) (wrbe #d 4 + ty + d + wrbe (gz-crc32 (ty + d)) 4)
       blank (zbytes 55)
       (row b) (string 0 + zbytes 13
                + cats (map (x \ (b >> (7 - x)) & 1 = 1 ? (string [255 255 255 255]) (zbytes 4)) ^7)
                + zbytes 13)
       pix (cats (map (_ \ blank) ^104) + cats (map (b \ cats (map (_ \ row b) ^32)) ic-rows) + cats (map (_ \ blank) ^104))
       (string [137 80 78 71 13 10 26 10]
        + chunk "IHDR" (wrbe 432 4 + wrbe 432 4 + string [1 3 0 0 0])
        + chunk "PLTE" (zbytes 3 + wrbe (ic-rgb 'red) 3)
        + chunk "tRNS" (zbytes 1)
        + chunk "IDAT" (string [120 156] + deflate pix + wrbe (dx-adler pix) 4)
        + chunk "IEND" ""))
   ic-xml ["adaptive-icon" () [["background" [[1 "drawable" 'ref ic-bg]] ()] ["foreground" [[1 "drawable" 'ref ic-fg]] ()]]]
   ; the resource table: one package, one type, its entries in ic-bg's order
   (ic-arsc _)
    (: (u32 v) (wrle v 4) (u16 v) (wrle v 2)
       tp (ax-pool ["drawable"]) kp (ax-pool ["bg" "fg" "icon"])
       (ent k ty v) (u16 8 + u16 0 + u32 k + u16 8 + string [0 ty] + u32 v)
       spec (ax-chunk 0x202 16 (string [1 0] + u16 0 + u32 3 + zbytes 12))
       type (ax-chunk 0x201 84 (string [1 0] + u16 0 + u32 3 + u32 96 + u32 64 + zbytes 60
                                + u32 0 + u32 16 + u32 32
                                + ent 0 0x1d (0xff000000 | ic-rgb 'bg) + ent 1 3 0 + ent 2 3 1))
       pkg (ax-chunk 0x200 288 (u32 0x7f + ax-u16 "love" + zbytes 248 + u32 288 + u32 1 + u32 (288 + #tp) + u32 3 + u32 0
                                + tp + kp + spec + type))
       (ax-chunk 2 12 (u32 1 + ax-pool ["res/f.png" "res/i.xml"] + pkg)))

   ; --- a bundle's protobufs, by field number: aapt2's Resources.proto, bundletool's config.proto ---
   (pb-int f n) (dx-uleb (f << 3) + dx-uleb n)
   (pb-len f s) (dx-uleb (f << 3 | 2) + dx-uleb #s + s)
   ; an XmlAttribute: a string's text is its value, any other holds a compiled item
   (pb-attr [ns n k v])
    (: item (k @ 'int (pb-len 7 (pb-int 6 v)) 'hex (pb-len 7 (pb-int 7 v))
                 'bool (pb-len 7 (pb-int 8 (? v 1 0))) 'ref (pb-len 1 (pb-int 2 v)) "")
       (? ns (pb-len 1 ax-uri + pb-int 5 (ax-rid n)) ""
          + pb-len 2 n + (k = 'str ? (pb-len 3 v) "") + (0 < #item ? (pb-len 6 item) "")))
   (pb-el [t at ks] ns)
    (: so (sort (map (a \ [(? <a (ax-rid (a 1)) -1) a]) at))
       (pb-len 1 (ns + pb-len 3 t + ap-cat (p \ pb-len 4 (pb-attr (p 1))) so
                  + ap-cat (e \ pb-len 5 (pb-el e "")) ks)))
   ; a proto xml file, android's namespace declared at its root
   (pb-xml root) (pb-el root (pb-len 1 (pb-len 1 "android" + pb-len 2 ax-uri)))
   ic-dir "res/drawable/"
   ; ic-arsc's table: an entry is its id, its name and one value in the default config
   (pb-table pkg)
    (: (ent i nm item) (pb-len 3 (pb-len 1 (pb-int 1 i) + pb-len 2 nm + pb-len 6 (pb-len 1 "" + pb-len 2 (pb-len 4 item))))
       (file nm ty) (pb-len 5 (pb-len 1 (ic-dir + nm) + pb-int 2 ty))         ; 1 png, 3 proto xml
       (pb-len 2 (pb-len 1 (pb-int 1 0x7f) + pb-len 2 pkg
                  + pb-len 3 (pb-len 1 (pb-int 1 1) + pb-len 2 "drawable"
                              + ent 0 "bg" (pb-len 7 (pb-int 9 (0xff000000 | ic-rgb 'bg)))
                              + ent 1 "fg" (file "f.png" 1) + ent 2 "icon" (file "i.xml" 3)))))
   ; the bridge execs liblove.so, so an install must leave it unpacked: compression stays on
   ; and one split per abi, so a phone fetches only its own love
   (aab-config _) (pb-len 1 (pb-len 2 "1.18.3") + pb-len 2 (pb-len 1 (pb-len 1 (pb-int 1 1)) + pb-len 2 ""))
   ; each lib dir's abi, which that split is cut by: armeabi-v7a 2, arm64-v8a 3
   (aab-native as) (cats (map (a \ pb-len 1 (pb-len 1 ("lib/" + a) + pb-len 2 (pb-len 1 (pb-int 1 (a = "arm64-v8a" ? 3 2))))) as))

   ; --- the service's class, what `-s` adds: a Service with a constructor, a null onBind and a native
   ; onStartCommand the bridge registers, so a notification keeps the process through a swipe.
   ; dex 035's tables, each sorted as it requires ---
   (dx-adler s) (foldl (\ st x ((<st + x) % 65521 @ a [a ((<>st + a) % 65521)])) [1 0] (map s ^#s) @ [a b] (b << 16 | a))
   (dx-uleb n) (n < 128 ? (string [n]) (string [(n & 127 | 128)] + dx-uleb (n >> 7)))
   (dx-service _)
    (: (u16 v) (wrle v 2) (u32 v) (wrle v 4)
       me "Lpics/salt/love/Service;" sup "Landroid/app/Service;" in "Landroid/content/Intent;" ib "Landroid/os/IBinder;"
       strs (sort ["<init>" "I" "ILII" "LL" sup in ib me "V" "onBind" "onStartCommand"])
       (at l s) (: (go i r) (<r = s ? i (go (i + 1) >r)) (go 0 l))
       (sx s) (at strs s)
       types (sort ["I" sup in ib me "V"])
       (tx s) (at types s)
       ids (112 + 4 * #strs + 4 * #types + 12 * 3 + 8 * 4 + 32)         ; the data begins here
       (tlist l) (u32 #l + cats (map (s \ u16 (tx s)) l) + zbytes (padk (2 * #l) 4))
       tl0 (tlist [in "I" "I"]) tl1 (tlist [in])
       init (u16 1 + u16 1 + u16 1 + u16 0 + u32 0 + u32 4 + u16 0x1070 + u16 0 + u16 0 + u16 0x0e)   ; invoke-direct super, return-void
       bind (u16 3 + u16 2 + u16 0 + u16 0 + u32 0 + u32 2 + u16 0x0012 + u16 0x0011)                 ; const/4 v0 0, return-object v0
       init-off (ids + #tl0 + #tl1) bind-off (init-off + #init)
       sd-off (bind-off + #bind)
       (sdata s) (dx-uleb #s + s + string [0])
       sds (map sdata strs)
       sd (cats sds)
       soffs (foldl (\ a s (a + [(last a + #s)])) [sd-off] sds)
       cd-off (sd-off + #sd)
       cd (dx-uleb 0 + dx-uleb 0 + dx-uleb 1 + dx-uleb 2
           + dx-uleb 1 + dx-uleb 0x10001 + dx-uleb init-off
           + dx-uleb 2 + dx-uleb 1 + dx-uleb bind-off
           + dx-uleb 1 + dx-uleb 0x101 + dx-uleb 0)
       map-off (cd-off + #cd + padk (cd-off + #cd) 4)
       (item ty n off) (u16 ty + u16 0 + u32 n + u32 off)
       s-off 112 t-off (s-off + 4 * #strs) p-off (t-off + 4 * #types) m-off (p-off + 12 * 3) c-off (m-off + 8 * 4)
       mp (u32 11 + item 0 1 0 + item 1 #strs s-off + item 2 #types t-off + item 3 3 p-off
           + item 5 4 m-off + item 6 1 c-off + item 0x1001 2 ids + item 0x2001 2 init-off
           + item 0x2002 #strs sd-off + item 0x2000 1 cd-off + item 0x1000 1 map-off)
       size (map-off + #mp)
       body (u32 size + u32 112 + u32 0x12345678 + u32 0 + u32 0 + u32 map-off
             + u32 #strs + u32 s-off + u32 #types + u32 t-off + u32 3 + u32 p-off
             + u32 0 + u32 0 + u32 4 + u32 m-off + u32 1 + u32 c-off + u32 (size - ids) + u32 ids
             + cats (map u32 (rev >(rev soffs)))
             + cats (map (s \ u32 (sx s)) types)
             ; the protos by return type, then the methods by class and name
             + u32 (sx "ILII") + u32 (tx "I") + u32 ids
             + u32 (sx "LL") + u32 (tx ib) + u32 (ids + #tl0)
             + u32 (sx "V") + u32 (tx "V") + u32 0
             + cats (map (m \ u16 (tx <m) + u16 (m 1) + u32 (sx (m 2)))
                         [[sup 2 "<init>"] [me 2 "<init>"] [me 1 "onBind"] [me 0 "onStartCommand"]])
             + u32 (tx me) + u32 1 + u32 (tx sup) + u32 0 + u32 -1 + u32 0 + u32 cd-off + u32 0
             + tl0 + tl1 + init + bind + sd + cd + zbytes (map-off - cd-off - #cd) + mp)
       sig (unhex (sha1 body))
       tail (sig + body)
       ("dex\n035" + string [0] + u32 (dx-adler tail) + tail))

   ; --- the zip: every entry deflated but the resource table, which android 11 reads in place, so
   ; stored and on a word: it goes first, and its 44 bytes of header leave it there. dated 1980, so
   ; the same inputs lay the same bytes ---
   (ap-zip es)
    (: j (jug 0)
       (u16 v) (wrle v 2) (u32 v) (wrle v 4)
       (one [cd off] [nm d])
        (: raw (nm = "resources.arsc") z (raw ? d (deflate d)) c (gz-crc32 d)
           h (u16 20 + u16 0 + u16 (raw ? 0 8) + u16 0 + u16 33 + u32 c + u32 #z + u32 #d + u16 #nm + u16 0)
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
    (: f (cite 'path 'nest 0 + "/etc/apk.pem")
       t (uread f @ r (two? r ? <>r))
       (? (string? t) (: k (key-read t) c (pem-in t "CERTIFICATE") (two? c && two? k ? [k <c]))
          (: k (key-new 'p256) nm (name-der "/CN=love")
             c (cert-make {'spki (key-spki k) 'exts () 'key k 'serial 1 'issuer nm 'subject nm
                           'nb 1767225600 'na 3345062400})
             (? (string? c && (umkdirs (cite 'path 'nest 0 + "/etc") 448, uwrite f (key-pem k + pem-out "CERTIFICATE" c)))
                [k c]))))

   ; --- the bridge, compiled out of the source this love carries ---
   (bridge-src _)
    (: a (tree-tar 0) t (? (string? a) (tar-unpack a))
       (? (two? t) (foldl (\ r e (? (string? r) r (ends? (tar-get e 'nom "") "src/apps/droid/bridge.c") (tar-get e 'body "") ()))
                          () <>t)))
   ; a love's abi off its elf header
   (ap-abi lb lov) (lb 18 @ 183 "arm64-v8a" 40 "armeabi-v7a" _ (udie 1 ("apk: " + lov + " is no a64 or arm love")))
   (bridge-so tmp abi)
    (: c (bridge-src 0)
       _ (string? c ? 0 (udie 1 "apk: this love carries no src/apps/droid/bridge.c"))
       src (tmp + "/bridge.c") so (tmp + "/libbridge-" + abi + ".so")
       (uwrite src c,
        (? ((cite 'moon 'moon-run) ((abi = "arm64-v8a" ? ["-t" "a64"] ["-t" "arm" "-fpic"]) + ["-shared" "-landroid" "-llog" "-laaudio" "-ldl" "-lc" "-o" so src]) != 0)
           (udie 1 "apk: the bridge does not compile")
           (uread so @ r (? (two? r) <>r (udie 1 "apk: no bridge laid"))))))

   (apk-usage _) (puts """
    usage: love apk [-o OUT.apk] [-p PACKAGE] [-n LABEL] [-L LOVE].. [-b LINE] [-s] [-P PERM].. [-V CODE] [-v NAME] [-T SDK] [-R] MAIN.l [FILE..]
      an android app that runs MAIN.l: a window, touch and keys through the face
      (src/apps/droid/droid.l). LOVE is a baked love it ships, one per abi (arm64-v8a or
      armeabi-v7a, read off the file); on an a64 machine this one. -b starts LOVE on LINE's words instead, MAIN.l then optional. the app has the
      network; each PERM is a permission it asks for at its start, RECORD_AUDIO for the mic
      (android.permission. unless named in full).
      -s keeps the app's loves through a swipe or back: a foreground service and its notification.
      -V the version code, -v its name, -T the sdk it targets, -R not debuggable.
      the key signing it lives in ~/.love/etc/apk.pem
    """)
   (aab-usage _) (puts """
    usage: love aab [-o OUT.aab] [-p PACKAGE] [-n LABEL] [-L LOVE].. [-b LINE] [-s] [-P PERM].. [-V CODE] [-v NAME] [-T SDK] MAIN.l [FILE..]
      the app `love apk` lays, as an android app bundle for a store: not debuggable, and
      unsigned, since a store's upload key is its owner's. jarsigner signs it. a store refuses a version code it has seen.
    """)
   (ap-base p) (p @ (_ + "/" + s) (ap-base s) p)
   (ap-stem p) (ap-base p @ b (b @ (s + ".l") s b))
   (ap-or s d) (? (string? s) s d)
   (apk-opts as t)
    (as @ ("-o" . v . r) (apk-opts r (pin t 'o v)) ("-p" . v . r) (apk-opts r (pin t 'p v))
          ("-n" . v . r) (apk-opts r (pin t 'n v)) ("-L" . v . r) (apk-opts r (pin t 'L (t 'L + [v])))
          ("-b" . v . r) (apk-opts r (pin t 'b v))
          ("-V" . v . r) (apk-opts r (pin t 'code (read v))) ("-v" . v . r) (apk-opts r (pin t 'name v))
          ("-T" . v . r) (apk-opts r (pin t 'target (read v)))
          ("-s" . r) (apk-opts r (pin t 's 1))
          ("-R" . r) (apk-opts r (pin t 'R 1))
          ("-P" . v . r) (apk-opts r (pin t 'P (t 'P + [(has? v "." ? v ("android.permission." + v))])))
          (("-h" || "--help") . _) (apk-usage 0, quit 0)
          (("-" + _) . _) (apk-usage 0, quit 2)
          r (pin t 'files r))
   (apk-main as) (ap-pack 'apk as)
   (aab-main as) (ap-pack 'aab as)
   (aab-path nm) (nm = "classes.dex" ? "base/dex/classes.dex" ("base/" + nm))
   (ap-pack fmt as)
    (: t (apk-opts as {})
       aab (fmt = 'aab)
       ext (show fmt)
       fs (t 'files)
       _ (two? fs || string? (t 'b) ? 0 (aab ? (aab-usage 0) (apk-usage 0), quit 2))
       nm (? (two? fs) (ap-stem <fs) (ap-or (t 'n) "love"))
       out (ap-or (t 'o) (nm + "." + ext))
       pkg (ap-or (t 'p) ("pics.salt." + nm))
       lovs (? (two? (t 'L)) (t 'L) (love-arch = 'a64) [(selfpath 0)]
               (udie 1 "apk: name an a64 love with -L (`love seed a64 DIR`, baked once on an a64 machine)"))
       libs (map (lov \ uread lov @ r (? (two? r) (: lb <>r [(ap-abi lb lov) lb]) (udie 1 ("apk: cannot read " + lov)))) lovs)
       ks (aab ? () (apk-keys 0))
       _ (aab || two? ks ? 0 (udie 1 "apk: no key in ~/.love/etc/apk.pem, and none could be made"))
       tmp ((ap-or (getenv "TMPDIR") "/tmp") + "/love-apk-" + show (getpid 0))
       _ (mkdir tmp 448)
       abis (map (l \ (: abi <l [[("lib/" + abi + "/libbridge.so") (bridge-so tmp abi)] [("lib/" + abi + "/liblove.so") <>l]])) libs)
       ins (map (f \ [("assets/app/" + ap-base f) (uread f @ r (? (two? r) <>r (udie 1 ("apk: cannot read " + f))))]) fs)
       stay (t 's = 1)
       target (? (charm? (t 'target)) (t 'target) aab 36 31)
       ; a target past 33 asks for its notification
       ps (t 'P + (stay && target >= 33 ? ["android.permission.POST_NOTIFICATIONS"] ()))
       label (ap-or (t 'n) nm)
       man (ap-manifest pkg label ps stay {'code (? (charm? (t 'code)) (t 'code) 1) 'name (ap-or (t 'name) "1")
                                           'target target 'debug (aab || t 'R = 1 ? 0 1)})
       rest ([["assets/argv" (? (string? (t 'b)) (foldl (a \ w \ a + w + string [0]) "" (filter (w \ 0 < #w) (split " " (t 'b))))
                                (ap-base <fs + string [0]))]]
             + (two? ps ? [["assets/perms" (cats (map (p \ p + string [0]) ps))]] ())
             + catmap id abis
             + (stay ? [["classes.dex" (dx-service 0)] ["assets/stay" label]] ()) + ins)
       z (aab ? (ap-zip ([["BundleConfig.pb" (aab-config 0)] ["base/native.pb" (aab-native (map cap libs))]
                          ["base/manifest/AndroidManifest.xml" (pb-xml man)]
                          ["base/resources.pb" (pb-table pkg)]
                          [("base/" + ic-dir + "f.png") (ic-png 0)] [("base/" + ic-dir + "i.xml") (pb-xml ic-xml)]]
                         + map (e \ [(aab-path <e) (e 1)]) rest))
                (v2-sign (ap-zip ([["resources.arsc" (ic-arsc 0)]
                                   ["res/f.png" (ic-png 0)] ["res/i.xml" (ap-axml ic-xml)]
                                   ["AndroidManifest.xml" (ap-axml man)]] + rest)) <ks (ks 1)))
       (? (uwrite out z)
          (puts (aab ? ("aab: " + out + " (" + pkg + ") -- unsigned\n")
                       ("apk: " + out + " (" + pkg + ") -- adb install -r " + out + "\n")), 0)
          (udie 1 (ext + ": cannot write " + out))))

   door (udoor 'apk apk-main apk-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'apk door)
   s (cite 'verbs 'fire ["apk" "droid.l"])
   _ (two? s ? (quit (door >s)) 0)
   aab-door (udoor 'aab aab-main aab-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'aab aab-door)
   s2 (cite 'verbs 'fire ["aab"])
   _ (two? s2 ? (quit (aab-door >s2)) 0))
) ; module droid
