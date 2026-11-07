; test/host/droid.l -- the apk's zip, binary manifest and v2 signing block read back by our
; own readers; a phone is the oracle for whether android takes the shape
; run:  cat test/00-init.l test/host/droid.l | out/love

(borrow "src/apps/droid/droid.l")
(borrow "src/apps/open.l")
(borrow '(bytes gz tls hashes))

(: dr-k (key-new 'p256)
   dr-nm (name-der "/CN=t")
   dr-c (cert-make {'spki (key-spki dr-k) 'exts () 'key dr-k 'serial 1 'issuer dr-nm 'subject dr-nm
                    'nb 1767225600 'na 3345062400})
   dr-es [["a.txt" "hello"] ["b/c" (zbytes 5000)] ["e" ""]]
   dr-z (ap-zip dr-es)
   ; the local entries: [name bytes] each, inflated
   (dr-ents z)
    (: (go i acc)
        (? (rdle z i 4 != 0x04034b50) (rev acc)
           (: cs (rdle z (i + 18) 4) us (rdle z (i + 22) 4) nl (rdle z (i + 26) 2)
              d (snip z (i + 30 + nl) (i + 30 + nl + cs))
              b (gz-inflate d us @ r (? (two? r) <>r ""))
              ok (gz-crc32 b = rdle z (i + 14) 4)
              (go (i + 30 + nl + cs) ([(snip z (i + 30) (i + 30 + nl)) (? ok b 'badcrc)] . acc))))
       (go 0 ()))
   dr-eo (#dr-z - 22)
   dr-o {'code 1 'name "1" 'target 31 'debug 1}
   dr-x (ap-axml (ap-manifest "pics.salt.t" "t" () 0 dr-o))
   dr-xp (ap-axml (ap-manifest "pics.salt.t" "t" ["android.permission.RECORD_AUDIO"] 0 dr-o))
   dr-xn (ap-axml (ap-manifest "pics.salt.t" "t" ["android.permission.INTERNET"] 0 dr-o))
   (dr-walk x)
    (: (go i acc) (? (#x <= i) [i (rev acc)] (go (i + rdle x (i + 4) 4) (rdle x i 2 . acc))) (go 8 ()))
   (dr-pool x)
    (: n (rdle x 16 4) ss (8 + rdle x 28 4)
       (map (k \ : o (ss + rdle x (36 + 4 * k) 4) l (rdle x o 2)
                  (cats (map (j \ string [(rdle x (o + 2 + 2 * j) 2)]) ^l)))
            ^n))
   ; the v2 block sits before the central directory, its magic last, its size first and last
   dr-s (v2-sign dr-z dr-k dr-c)
   dr-co (rdle dr-s (#dr-s - 6) 4)
   dr-n (rdle dr-s (dr-co - 24) 8)
   dr-b0 (dr-co - dr-n - 8)
   dr-sd (snip dr-s (dr-b0 + 32) (dr-b0 + 32 + rdle dr-s (dr-b0 + 28) 4))
   dr-p (dr-b0 + 32 + #dr-sd)
   dr-sig (snip dr-s (dr-p + 16) (dr-p + 16 + rdle dr-s (dr-p + 12) 4))
   dr-spk (key-spki dr-k)
   _ 0)

(test
 (dr-ents dr-z = dr-es)
 (rdle dr-z (dr-eo + 10) 2 = 3)
 (rdle dr-z (rdle dr-z (dr-eo + 16) 4) 4 = 0x02014b50)
 (ap-zip dr-es = dr-z))

(test
 ; a love's lib/ABI, by its e_machine
 (ap-abi (zbytes 18 + string [183]) "x" = "arm64-v8a")
 (ap-abi (zbytes 18 + string [40]) "x" = "armeabi-v7a"))

(test
 ; chunks: the pool, the resource map, then the tree
 (: w (dr-walk dr-x) (<w = #dr-x && rdle dr-x 4 4 = #dr-x && (w 1) 0 = 1 && (w 1) 1 = 0x180))
 ; the attribute names first, in resource-id order
 (: p (dr-pool dr-x) (p 0 = "label" && elem "manifest" p && elem "pics.salt.t" p && elem "activity" p))
 (: p (dr-pool dr-x) !(any (x \ !(string? x)) p))
 (: w (dr-walk dr-xp) (<w = #dr-xp && #(w 1) = #((dr-walk dr-x) 1) + 2))
 (: p (dr-pool dr-xp) (elem "uses-permission" p && elem "android.permission.RECORD_AUDIO" p))
 ; the network with no -P, and once when -P names it too
 (: p (dr-pool dr-x) (elem "uses-permission" p && elem "android.permission.INTERNET" p))
 (dr-xn = dr-x))

(test
 (snip dr-s (dr-co - 16) dr-co = "APK Sig Block 42")
 (rdle dr-s dr-b0 8 = dr-n)
 ; the block out, the end record's offset put back: the zip it was laid in
 (snip dr-s 0 dr-b0 + snip dr-s dr-co (#dr-s - 6) + wrle dr-b0 4 + snip dr-s (#dr-s - 2) #dr-s = dr-z)
 (has? dr-sd (v2-digest [(snip dr-z 0 dr-b0) (snip dr-z dr-b0 dr-eo) (snip dr-z dr-eo #dr-z)]))
 (has? dr-sd dr-c)
 (1 = sig-ok? (unhex "2a8648ce3d040302") (spki-key dr-spk (der dr-spk 0 #dr-spk)) dr-sd dr-sig))

;; the icon: the favicon's heart and red, and a resource table android reads in place
(: dr-rz (ap-zip [["resources.arsc" "abcd"] ["x" "y"]])
   dr-png (ic-png 0)
   dr-iend (fsub dr-png "IDAT" 0)
   dr-pix (gz-inflate (snip dr-png (dr-iend + 6) (dr-iend + rdbe dr-png (dr-iend - 4) 4)) (432 * 55) @ r (? (two? r) <>r ""))
   dr-q (open "src/love/quay/cga_8x8.c" "r") dr-src (slurp dr-q) _ (close dr-q)
   dr-cell (split "{" (filter (l \ has? l "// [") (lines dr-src) 3))
   dr-gl (map (w \ read w) (take 7 (split "," <(split "}" (dr-cell 1)))))
   (test (rdle dr-rz 8 2 = 0) (snip dr-rz 44 48 = "abcd")     ; stored, and on a word
         (rdbe dr-png 16 4 = 432) (rdbe dr-png 20 4 = 432)
         (#dr-pix = 432 * 55)
         (dr-pix (103 * 55 + 18) = 0) (dr-pix (104 * 55 + 14) = 0) (dr-pix (104 * 55 + 18) = 255)  ; the heart's first lit pixel
         (dr-gl = ic-rows)
         (rdle (ic-arsc 0) 0 2 = 2) (rdle (ic-arsc 0) 4 4 = #(ic-arsc 0))))
;; the service's class: the header's own sums and sizes
(: dr-dx (dx-service 0)
   (test (snip dr-dx 0 8 = ("dex\n035" + string [0]))
         (rdle dr-dx 8 4 = dx-adler (snip dr-dx 12 #dr-dx))
         (snip dr-dx 12 32 = unhex (sha1 (snip dr-dx 32 #dr-dx)))
         (rdle dr-dx 32 4 = #dr-dx) (rdle dr-dx 36 4 = 112)
         (has? dr-dx "Lpics/salt/love/Service;") (has? dr-dx "onStartCommand")))

;; window over the bridge's wire, the bridge played here
(borrow 'window)
(: dw-path ((getenv "TMPDIR" @ t (string? t ? t "/tmp")) + "/droid-face-" + show (getpid 0))
   _ (unlink dw-path)
   dw-l (listen ['unix dw-path])
   _ (setenv "LOVE_FACE" dw-path)
   (dw-rec k a b c) (string k + string a + string 0 + string 0 + wrle b 4 + wrle c 4)
   dw-got {}
   dw-srv (twirl (_ \ (: _ (await dw-l) c (accept dw-l)
                         _ (say c (dw-rec 83 0 1080 2400), flush c)
                         _ (pin dw-got 'c c)
                         0)) 0)
   dw-w (window-open 640 384 "t")
   _ (catch dw-srv)
   dw-sz (window-size dw-w)
   dc (dw-got 'c)
   _ (say dc (dw-rec 75 1 29 97 + dw-rec 75 0 29 0 + dw-rec 75 1 66 10 + dw-rec 84 0 10 20 + dw-rec 84 2 11 21
              + dw-rec 83 0 1080 1200), flush dc)
   _ (rest 50)
   dw-ev (window-events dw-w)
   _ (window-show dw-w 1 3)
   (dw-take n) (map (_ \ see dc) ^n)
   (dw-snip l n) (n < 1 ? () (<l . dw-snip >l (n - 1)))
   dw-hd (dw-take 9)
   _ (dw-take (2 * 540 * 4))
   ; typing: the paper short by the key row, sent under it; ctrl tapped on it holds for the next key
   _ (window-typing dw-w 1)
   dw-i (dw-take 2)
   ; the row is more than a socket holds: read it in a task
   (dw-beside n) (twirl (_ \ dw-take n) 0)
   dw-rd (dw-beside (9 + 540 * 96 * 4))
   dw-ev2 (window-events dw-w)
   dw-rh (dw-snip (catch dw-rd) 9)
   _ (say dc (dw-rec 84 0 115 562 + dw-rec 84 1 115 562 + dw-rec 75 1 31 99 + dw-rec 75 0 31 0), flush dc)
   _ (rest 50)
   dw-rd2 (dw-beside (2 * (9 + 540 * 96 * 4)))
   dw-ev3 (window-events dw-w)
   _ (catch dw-rd2)
   ; the clipboard: owned as 'C, asked as 'V, its answer in ten-byte 'P pieces; the primary stays here
   (dw-p t) (foldl (r \ _ \ r + string 0) (string 80 + string (tally t) + t) ^(10 - tally t))
   _ (window-own dw-w 'primary "x")
   _ (window-own dw-w 'clipboard "hé")
   dw-c (dw-take 8)
   _ (window-ask dw-w 'clipboard)
   dw-v (dw-take 1)
   _ (say dc (dw-p ("abcdefghi" + string 195) + dw-p (string 169 + "!") + dw-p ""), flush dc)
   _ (rest 50)
   dw-ev4 (window-events dw-w)
   ; the row's paste key and a keyboard's ask the same, and the row's last key types
   _ (say dc (dw-rec 84 0 450 514 + dw-rec 75 1 279 0 + dw-rec 75 0 279 0 + dw-rec 84 0 450 562), flush dc)
   _ (rest 50)
   dw-ev5 (window-events dw-w)
   dw-v2 (dw-take 2)
   dw-sz5 (window-size dw-w)
   dw-pl5 #(window-paper dw-w)
   ; the row's ≡ asks the decks; the row turns to them, a tap on one says it and the keys come back
   dw-row (9 + 540 * 96 * 4)
   (dw-tap x) (say dc (dw-rec 84 0 x 514), flush dc, rest 50, window-events dw-w)
   _ (dw-tap 510)
   dw-dk (dw-take 1)
   dw-rd11 (dw-beside dw-row)
   _ (say dc (dw-rec 68 1 (getpid 0) 1 + dw-rec 68 3 (getpid 0) 0 + dw-rec 68 255 0 0), flush dc)
   _ (rest 50)
   dw-ev11 (window-events dw-w)
   _ (catch dw-rd11)
   dw-rd12 (dw-beside (2 + dw-row))
   _ (dw-tap 200)
   dw-g (dw-snip (catch dw-rd12) 2)
   ; ..and past the last, a new one
   _ (dw-tap 510)
   _ (dw-take 1)
   dw-rd13 (dw-beside dw-row)
   _ (say dc (dw-rec 68 0 (getpid 0) 1 + dw-rec 68 255 0 0), flush dc)
   _ (rest 50)
   _ (window-events dw-w)
   _ (catch dw-rd13)
   dw-rd14 (dw-beside (2 + dw-row))
   _ (dw-tap 200)
   dw-g2 (dw-snip (catch dw-rd14) 2)
   ; the keyboard put away by hand: the row goes and the paper has its room; back, and both return
   _ (say dc (dw-rec 83 0 1080 1200), flush dc)
   _ (rest 50)
   dw-ev6 (window-events dw-w)
   dw-sz6 (window-size dw-w)
   dw-rd7 (dw-beside (9 + 540 * 96 * 4))
   _ (say dc (dw-rec 83 1 1080 800), flush dc)
   _ (rest 50)
   dw-ev7 (window-events dw-w)
   dw-rh7 (dw-snip (catch dw-rd7) 9)
   ; ..and none while nothing types, the keyboard up or not
   _ (window-typing dw-w 0)
   dw-i8 (dw-take 2)
   _ (window-events dw-w)
   _ (say dc (dw-rec 83 1 1080 900), flush dc)
   _ (rest 50)
   dw-ev8 (window-events dw-w)
   ; the size it has is no news, unless what it drew is gone
   _ (say dc (dw-rec 83 0 1080 900), flush dc)
   _ (rest 50)
   dw-ev9 (window-events dw-w)
   _ (say dc (dw-rec 83 2 1080 900), flush dc)
   _ (rest 50)
   dw-ev10 (window-events dw-w))
(test
 ([540 1200] = dw-sz)
 (dw-ev = [['down 30] ['text "a"] ['up 30] ['down 28] ['press 1 10 20] ['move 11 21] ['size 540 600]])
 (540 * 504 * 4 = dw-pl5)
 (dw-hd = [70 28 2 88 2 1 0 2 0])
 (dw-i = [73 1]) (dw-ev2 = [['size 540 504]]) ([540 504] = dw-sz5)
 (dw-rh = [70 28 2 88 2 248 1 96 0])
 (dw-ev3 = [['down 29] ['down 46] ['text "c"] ['up 46] ['up 29] ['up 46]])
 (dw-c = [67 3 0 0 0 104 195 169]) (dw-v = [86])
 (dw-ev4 = [['paste "abcdefghié!"]])
 (dw-ev5 = [['down 53] ['text "/"] ['up 53]]) (dw-v2 = [86 86])
 (dw-dk = [68]) (dw-ev11 = ()) (dw-g = [71 3]) (dw-g2 = [71 255])
 (dw-ev6 = [['size 540 600]]) (dw-sz6 = [540 600])
 (dw-ev7 = [['size 540 304]]) (dw-rh7 = [70 28 2 144 1 48 1 96 0])
 (dw-i8 = [73 0]) (dw-ev8 = [['size 540 450]])
 (dw-ev9 = ()) (dw-ev10 = [['size 540 450]]) ([540 450] = window-size dw-w))
;; thumbs: a second finger is nothing to a button's window, each its own record once asked for;
;; back is esc's place
(: _ (say dc (dw-rec 84 4 30 40 + dw-rec 75 1 4 0), flush dc)
   _ (rest 50)
   ev0 (window-events dw-w)
   on (window-thumbs dw-w)
   _ (say dc (dw-rec 84 0 10 20 + dw-rec 84 6 30 40 + dw-rec 84 5 30 41), flush dc)
   _ (rest 50)
   ev (window-events dw-w)
   (test (ev0 = [['down 1]]) (on = 1) (ev = [['finger 0 0 10 20] ['finger 1 2 30 40] ['finger 1 1 30 41]])))
(: _ (window-close dw-w) _ (close dc) _ (close dw-l) _ (unlink dw-path) 0)

; the framework's door: a fake bridge answers each op by its letter and keeps the records;
; open runs as a child, one at a time: a fork while the fake still holds the last connection
; would keep that one open
(: dj-path ((getenv "TMPDIR" @ t (string? t ? t "/tmp")) + "/droid-door-" + show (getpid 0))
   _ (unlink dj-path)
   dj-l (listen ['unix dj-path])
   _ (setenv "LOVE_DROID" dj-path)
   dj-got {'ops () 'idle 1}
   (dj-rd c n) (: (go k acc) (k < 1 ? (cats (rev acc)) (see c @ b (b < 0 ? () (go (k - 1) (string b . acc))))) (go n ()))
   (dj-ans k t) (wrle (#t + 1) 4 + string k + t)
   (dj-reply b n)
    (b 0 @ 116 (dj-ans 116 ("T" + snip b 1 #b))
           100 (dj-ans 118 "")
           109 (has? b "startActivity" ? (dj-ans 118 "") (dj-ans 104 (show n)))
           115 (has? b "throw" ? (dj-ans 120 "java.lang.SecurityException: no") (dj-ans 104 (show n)))
           (dj-ans 104 (show n)))
   (dj-serve c n) (dj-rd c 4 @ h (? !(string? h) (close c, pin dj-got 'idle 1)
                                    (: b (dj-rd c (rdle h 0 4))
                                       (pin dj-got 'ops (dj-got 'ops + [b]), say c (dj-reply b n), flush c, dj-serve c (n + 1)))))
   dj-srv (twirl (_ \ (: (go _) (await dj-l, accept dj-l @ c (pin dj-got 'idle 0, dj-serve c 0), go 0) (go 0))) ())
   (dj-idle n) (dj-got 'idle || n < 1 ? 0 (rest 10, dj-idle (n - 1)))
   (dj-run as) (: r (hark ("out/love" . as)) _ (dj-idle 500) ops (dj-got 'ops) (pin dj-got 'ops (), [<r >r ops]))
   dj-op (dj-run ["open" "ab:x"])
   dj-ox (dj-run ["open" "ab:throw"])
   dj-of (dj-run ["open" "notes.txt"])
   _ (landed? dj-srv ? 0 (freeze dj-srv))
   (dj-z l) (map (w \ cats (map (c \ c = 0 ? "|" (string c)) (chars w))) l))
(test
 (<dj-op = 0) (dj-op 1 = "")
 (dj-z (dj-op 2) = ["candroid/net/Uri" "sab:x" "k0|parse|(Ljava/lang/String;)Landroid/net/Uri;|1" "d1" "d0"
                    "candroid/content/Intent" "sandroid.intent.action.VIEW"
                    "n5|(Ljava/lang/String;Landroid/net/Uri;)V|6|2" "d6" "d5" "d2" "a"
                    "m11|startActivity|(Landroid/content/Intent;)V|7" "d7" "d11"])
 (<dj-ox = 1) (dj-z (dj-ox 2) = ["candroid/net/Uri" "sab:throw" "d0"])
 (<dj-of = 1) (dj-of 2 = ())                                  ; a file never reaches the door
 (open-link? "https://x") (open-link? "ab:x") !(open-link? "u:x") !(open-link? "c:x") !(open-link? "notes.txt") !(open-link? "a/b:c"))
(: _ (close dj-l) _ (unlink dj-path) _ (setenv "LOVE_DROID" ()) 0)

; off android: the system's opener, here a fake on PATH that keeps what it was given
(: do-d ((getenv "TMPDIR" @ t (string? t ? t "/tmp")) + "/droid-open-" + show (getpid 0))
   _ (hark ["mkdir" "-p" do-d])
   _ (each ["xdg-open" "open"] (p \ uwrite (do-d + "/" + p) ("#!/bin/sh\necho \"$0 $1\" > " + do-d + "/got\n")))
   _ (hark ["chmod" "755" (do-d + "/xdg-open") (do-d + "/open")])
   do-r (hark ["env" ("PATH=" + do-d + ":" + getenv "PATH") "out/love" "open" "https://x"])
   do-g (uread (do-d + "/got"))
   _ (hark ["rm" "-rf" do-d])
   (test (<do-r = 0) (do-g = [1 (do-d + "/" + (love-os = 'macos ? "open" "xdg-open") + " https://x\n")])))

(puts "droid: ok") (putc 10)

; the bundle's protobufs: protoc reads these against aapt2's schema, a phone or bundletool the rest
(: dr-man (ap-manifest "pics.salt.t" "t" () 1 {'code 7 'name "v" 'target 36 'debug 0})
   dr-pb (pb-xml dr-man)
   _ (test (pb-int 1 300 = string [8 172 2])
           (pb-len 2 "ab" = string [18 2 97 98])
           (has? dr-pb "android.permission.FOREGROUND_SERVICE_SPECIAL_USE")
           (has? dr-pb "android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE")
           (has? (pb-attr [1 "debuggable" 'bool 0]) (pb-len 6 (pb-len 7 (pb-int 8 0))))
           (has? (pb-attr [1 "targetSdkVersion" 'int 36]) (pb-len 6 (pb-len 7 (pb-int 6 36))))
           (has? (pb-table "p") "res/drawable/i.xml")
           (aab-path "classes.dex" = "base/dex/classes.dex")
           (aab-path "lib/a/b.so" = "base/lib/a/b.so")
           (aab-config 0 = string [10 8 18 6 49 46 49 56 46 51 18 8 10 4 10 2 8 1 18 0])
           (aab-native ["arm64-v8a"] = string [10 21 10 13] + "lib/arm64-v8a" + string [18 4 10 2 8 3])))
