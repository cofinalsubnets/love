; test/host/droid.l -- the apk's zip, binary manifest and v2 signing block read back by our
; own readers; a phone is the oracle for whether android takes the shape
; run:  cat test/00-init.l test/host/droid.l | out/love

(borrow "src/apps/droid/droid.l")
(borrow 'bytes)
(borrow 'gz)
(borrow 'tls)

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
   dr-x (ap-axml (ap-manifest "pics.salt.t" "t" ()))
   dr-xp (ap-axml (ap-manifest "pics.salt.t" "t" ["android.permission.RECORD_AUDIO"]))
   dr-xn (ap-axml (ap-manifest "pics.salt.t" "t" ["android.permission.INTERNET"]))
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
   _ (say dc (dw-rec 84 0 482 514 + dw-rec 75 1 279 0 + dw-rec 75 0 279 0 + dw-rec 84 0 482 562), flush dc)
   _ (rest 50)
   dw-ev5 (window-events dw-w)
   dw-v2 (dw-take 2))
(test
 ([540 1200] = dw-sz)
 (dw-ev = [['down 30] ['text "a"] ['up 30] ['down 28] ['press 1 10 20] ['move 11 21] ['size 540 600]])
 (540 * 504 * 4 = #(window-paper dw-w))
 (dw-hd = [70 28 2 88 2 1 0 2 0])
 (dw-i = [73 1]) (dw-ev2 = [['size 540 504]]) ([540 504] = window-size dw-w)
 (dw-rh = [70 28 2 88 2 248 1 96 0])
 (dw-ev3 = [['down 29] ['down 46] ['text "c"] ['up 46] ['up 29] ['up 46]])
 (dw-c = [67 3 0 0 0 104 195 169]) (dw-v = [86])
 (dw-ev4 = [['paste "abcdefghié!"]])
 (dw-ev5 = [['down 53] ['text "/"] ['up 53]]) (dw-v2 = [86 86]))
(: _ (window-close dw-w) _ (close dc) _ (close dw-l) _ (unlink dw-path) 0)

; the framework's door: a fake bridge answers each op by its letter and keeps the records;
; am, pm and settings run as children by their verbs, one at a time: a fork while the fake
; still holds the last connection would keep that one open
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
           109 (? (has? b "startActivity") (dj-ans 118 "") (has? b "size") (dj-ans 118 "2") (dj-ans 104 (show n)))
           107 (has? b "putString" ? (dj-ans 120 "java.lang.SecurityException: no") (dj-ans 104 (show n)))
           (dj-ans 104 (show n)))
   (dj-serve c n) (dj-rd c 4 @ h (? !(string? h) (close c, pin dj-got 'idle 1)
                                    (: b (dj-rd c (rdle h 0 4))
                                       (pin dj-got 'ops (dj-got 'ops + [b]), say c (dj-reply b n), flush c, dj-serve c (n + 1)))))
   dj-srv (twirl (_ \ (: (go _) (await dj-l, accept dj-l @ c (pin dj-got 'idle 0, dj-serve c 0), go 0) (go 0))) ())
   (dj-idle n) (dj-got 'idle || n < 1 ? 0 (rest 10, dj-idle (n - 1)))
   (dj-run as) (: r (hark ("out/love" . as)) _ (dj-idle 500) ops (dj-got 'ops) (pin dj-got 'ops (), [<r >r ops]))
   dj-am (dj-run ["am" "start" "-a" "V" "-d" "u:x"])
   dj-pm (dj-run ["pm" "list" "packages"])
   dj-sg (dj-run ["settings" "get" "secure" "k"])
   dj-sp (dj-run ["settings" "put" "system" "k" "v"])
   _ (landed? dj-srv ? 0 (freeze dj-srv))
   (dj-z l) (map (w \ cats (map (c \ c = 0 ? "|" (string c)) (chars w))) l))
(test
 (<dj-am = 0) (dj-am 1 = "Starting: T1\n")
 (dj-z (dj-am 2) = ["candroid/content/Intent" "n0|()V" "candroid/net/Uri" "su:x"
                    "k2|parse|(Ljava/lang/String;)Landroid/net/Uri;|3" "d3" "sV"
                    "m1|setAction|(Ljava/lang/String;)Landroid/content/Intent;|6" "d6" "d7"
                    "m1|setData|(Landroid/net/Uri;)Landroid/content/Intent;|4" "d10" "t1" "a"
                    "m13|startActivity|(Landroid/content/Intent;)V|1"])
 (<dj-pm = 0) (dj-pm 1 = "package:T5\npackage:T10\n")
 (dj-z (dj-pm 2) = ["a" "m0|getPackageManager|()Landroid/content/pm/PackageManager;"
                    "m1|getInstalledPackages|(I)Ljava/util/List;|0" "m2|size|()I"
                    "m2|get|(I)Ljava/lang/Object;|0" "g4|packageName|Ljava/lang/String;" "t5" "d5" "d4"
                    "m2|get|(I)Ljava/lang/Object;|1" "g9|packageName|Ljava/lang/String;" "t10" "d10" "d9"])
 (<dj-sg = 0) (dj-sg 1 = "T4\n")
 (dj-z (dj-sg 2) = ["a" "m0|getContentResolver|()Landroid/content/ContentResolver;" "candroid/provider/Settings$Secure"
                    "sk" "k2|getString|(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;|1|3" "d3" "t4"])
 (<dj-sp = 1) (dj-sp 1 = "") (any (w \ has? w "putString") (dj-sp 2))
 (rev (dj-sp 2) @ ("d4" . "d3" . _) 1 _ 0))                  ; let go though it threw
(: _ (close dj-l) _ (unlink dj-path) _ (setenv "LOVE_DROID" ()) 0)

(puts "droid: ok") (putc 10)
