; src/apps/chucho/mime.l -- a message as it travels (RFC 5322, MIME 2045-2047, 2231): the head
; split from the body, the headers unfolded, encoded words and transfer encodings undone,
; charsets brought to utf-8, multiparts walked to their leaves, dates and addresses read.
; pure: a message is a string in and data out.
;
;   (mime-split m)        -> [head body] at the first empty line, crlf read as lf
;   (mime-heads h)        -> [[name value] ..], names lowercased, folds joined
;   (mime-get hs n)       -> the first n's value, "" when absent
;   (mime-words s)        -> encoded words (=?cs?B|Q?..?=) decoded to utf-8
;   (mime-b64 s) (mime-qp s) (mime-b64e s) -> the transfer encodings undone, and base64 made
;   (mime-utf8 s cs)      -> s from charset cs to utf-8
;   (mime-ctype v)        -> [type {param value}], type and names lowercased
;   (mime-leaves m)       -> the leaves to show: [type params heads body name], body decoded;
;                            an alternative keeps the one part a reader wants
;   (mime-date s)         -> [secs y m d hh mm zone-minutes] | ()
;   (mime-addrs s)        -> [[name addr] ..], names decoded
;   (mime-head-enc s)     -> s as a header may carry it: an encoded word when not ascii
(module (mime mime-split mime-heads mime-get mime-words mime-b64 mime-qp mime-b64e mime-utf8
         mime-ctype mime-leaves mime-date mime-addrs mime-head-enc mime-num mime-ascii?)
(borrow 'cal)
(:
 ; windows-1252's 0x80..0x9f, 0 where it leaves a hole
 mime-1252 [8364 0 8218 402 8222 8230 8224 8225 710 8240 352 8249 338 0 381 0
            0 8216 8217 8220 8221 8226 8211 8212 732 8482 353 8250 339 0 382 376]
 mime-b64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 mime-mons ["jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec"]
 ; the north american zones 822 names, in minutes east
 mime-zones {"ut" 0 "gmt" 0 "utc" 0 "z" 0 "est" -300 "edt" -240 "cst" -360 "cdt" -300
             "mst" -420 "mdt" -360 "pst" -480 "pdt" -420}

 ; --- the head and the body -----------------------------------------------------------
 (mime-split m)
  (: t (replace m "\r\n" "\n")
     (? (#t && t 0 = 10) ["" (snip t 1 #t)]
        (t @ (h + "\n\n" + b) [h b] [t ""])))
 ; a header's name owes no space: an mbox "From " line is not one
 (mime-heads h)
  (: (fold ls acc)
      (atom? ls ? (rev acc)
         (<ls @ l
            (? (#l = 0) (fold >ls acc)
               (ws? (l 0)) (fold >ls (acc @ ([n v] . r) ([n (v + " " + strip l)] . r) acc))
               (findsub l ":" @ k
                  (? (k < 1 || has? (snip l 0 k) " ") (fold >ls acc)
                     (fold >ls ([(lower (snip l 0 k)) (strip (snip l (k + 1) #l))] . acc)))))))
     (fold (lines h) ()))
 (mime-get hs n) (: (go l) (l @ ([k v] . r) (k = n ? v (go r)) "") (go hs))

 ; --- the transfer encodings ------------------------------------------------------------
 ; base64, lenient: anything outside the alphabet is skipped, and = ends nothing early
 (mime-b64v c)
  (? (65 <= c <= 90) (c - 65) (97 <= c <= 122) (c - 71) (48 <= c <= 57) (c + 4)
     (c = 43) 62 (c = 47) 63 -1)
 (mime-b64 s)
  (: j (jug 0) n #s
     (go i a m)
      (n <= i ? (slurp j)
         (mime-b64v (s i) @ d
            (? (d < 0) (go (i + 1) a m)
               (: a2 ((a << 6) | d) m2 (m + 6)
                  (m2 < 8 ? (go (i + 1) a2 m2)
                     (: k (m2 - 8)
                        (put j ((a2 >> k) & 255), go (i + 1) (a2 & ((1 << k) - 1)) k)))))))
     (go 0 0 0))
 (mime-b64e s)
  (: j (jug 0) n #s
     (ch v) (put j (mime-b64set (v & 63)))
     (go i)
      (n <= i ? (slurp j)
         (: b0 (s i) b1 (i + 1 < n ? (s (i + 1)) 0) b2 (i + 2 < n ? (s (i + 2)) 0)
            v ((b0 << 16) | (b1 << 8) | b2)
            (ch (v >> 18), ch (v >> 12),
             (i + 1 < n ? (ch (v >> 6)) (put j 61)),
             (i + 2 < n ? (ch v) (put j 61)),
             go (i + 3))))
     (go 0))
 ; quoted-printable; u reads _ as a space, the Q of an encoded word
 (mime-qpx s u)
  (: j (jug 0) n #s
     (hex? i) (i < n && 0 <= hexv (s i))
     (go i)
      (n <= i ? (slurp j)
         (s i @ c
            (? (c = 95 && u) (put j 32, go (i + 1))
               (c != 61) (put j c, go (i + 1))
               (i + 1 < n && s (i + 1) = 10) (go (i + 2))
               (hex? (i + 1) && hex? (i + 2))
                (put j (hexv (s (i + 1)) * 16 + hexv (s (i + 2))), go (i + 3))
               (put j c, go (i + 1)))))
     (go 0))
 (mime-qp s) (mime-qpx s 0)

 ; --- charsets: latin-1 and windows-1252 widen to utf-8, the rest pass as they are -------
 (mime-latin s w?)
  (jug 0 @ j (each ^#s (i \ (s i @ c (? (c < 128) (put j c)
                                        (w? && c < 160 && 0 < mime-1252 (c - 128)) (say j (utf8 (mime-1252 (c - 128))))
                                        (say j (utf8 c))))),
              slurp j))
 (mime-ascii? s) (: (go i) (? (#s <= i) 1 (127 < s i) 0 (go (i + 1))) (go 0))
 (mime-utf8 s cs)
  (lower cs @ c
     (? (mime-ascii? s) s
        (elem c ["iso-8859-1" "iso8859-1" "latin1" "iso-8859-15" "l1"]) (mime-latin s 0)
        (elem c ["windows-1252" "cp1252" "us-ascii" "ascii"]) (mime-latin s 1)
        s))

 ; --- encoded words -------------------------------------------------------------------
 ; the word at i -> [text end] | (); a charset may carry a language after a *
 (mime-word s i)
  (: a (fsub s "?" (i + 2))
     b (a < 0 ? -1 (fsub s "?" (a + 1)))
     e (b < 0 ? -1 (fsub s "?=" (b + 1)))
     (? (e < 0 || b != a + 2) ()
        (: cs (snip s (i + 2) a) en (lower (snip s (a + 1) b)) tx (snip s (b + 1) e)
           k (findsub cs "*")
           raw (en = "b" ? (mime-b64 tx) (mime-qpx tx 1))
           [(mime-utf8 raw (k < 0 ? cs (snip cs 0 k))) (e + 2)])))
 ; the space between two encoded words is not part of the text
 (mime-words s)
  (: j (jug 0) n #s
     (at? i) (i + 1 < n && s i = 61 && s (i + 1) = 63)
     (skip i) (i < n && ws? (s i) ? (skip (i + 1)) i)
     (go i w?)
      (n <= i ? (slurp j)
         (? (at? i) (mime-word s i @ r (two? r ? (say j <r, go <>r 1) (put j 61, go (i + 1) 0)))
            (w? && ws? (s i))
             (skip i @ k (at? k && two? (mime-word s k) ? (go k 1) (put j (s i), go (i + 1) 0)))
            (put j (s i), go (i + 1) 0)))
     (? (has? s "=?") (go 0 0) s))
 ; a header value as it may travel: ascii as it is, else one encoded word
 (mime-head-enc s) (mime-ascii? s ? s ("=?utf-8?B?" + mime-b64e s + "?="))

 ; --- content-type and its parameters ---------------------------------------------------
 ; v cut at the semicolons outside quotes
 (mime-semis v)
  (: (go i st q acc)
      (? (#v <= i) (rev ((snip v st i) . acc))
         (v i = 34) (go (i + 1) st !q acc)
         (v i = 59 && !q) (go (i + 1) (i + 1) q ((snip v st i) . acc))
         (go (i + 1) st q acc))
     (go 0 0 0 ()))
 (mime-unq s)
  (? (2 <= #s && s 0 = 34 && s (#s - 1) = 34) (replace (replace (snip s 1 (#s - 1)) "\\\"" "\"") "\\\\" "\\")
     s)
 ; RFC 2231's name*=charset'lang'%xx: the percents undone, the charset honoured
 (mime-pct s)
  (: j (jug 0) n #s
     (go i)
      (n <= i ? (slurp j)
         (? (s i = 37 && i + 2 < n && 0 <= hexv (s (i + 1)) && 0 <= hexv (s (i + 2)))
             (put j (hexv (s (i + 1)) * 16 + hexv (s (i + 2))), go (i + 3))
            (put j (s i), go (i + 1))))
     (go 0))
 (mime-2231 v)
  (: a (findsub v "'") b (a < 0 ? -1 (fsub v "'" (a + 1)))
     (b < 0 ? v (mime-utf8 (mime-pct (snip v (b + 1) #v)) (snip v 0 a))))
 (mime-ctype v)
  (: ps (mime-semis v)
     t (lower (strip <ps))
     (add m p)
      (findsub p "=" @ k
         (? (k < 0) m
            (: nm (lower (strip (snip p 0 k))) val (mime-unq (strip (snip p (k + 1) #p)))
               (ends? nm "*" ? (pin m (snip nm 0 (#nm - 1)) (mime-2231 val)) (pin m nm val)))))
     [(#t ? t "text/plain") (foldl add {} >ps)])

 ; --- the multipart walk ----------------------------------------------------------------
 ; the parts between the delimiter lines; the preamble and epilogue dropped, and a body
 ; that never closes keeps its last part
 (mime-parts b bd)
  (: d ("\n--" + bd) t ("\n" + b) nt #t
     ; the next delimiter line at or after i -> [its start, its end, close?] | ()
     (next i)
      (fsub t d i @ k
         (? (k < 0) ()
            (: e (fsub t "\n" (k + 1)) e2 (e < 0 ? nt e)
               tl (strip (snip t (k + #d) e2))
               (? (#tl = 0) [k e2 0]
                  (starts? tl "--") [k e2 1]
                  (next (k + 1))))))
     (go i acc)
      (next i @ r
         (? (atom? r) (rev (i < nt ? ((snip t i nt) . acc) acc))
            (: acc2 ((snip t i <r) . acc)
               (r 2 ? (rev acc2) (go (<>r + 1) acc2)))))
     (next 0 @ r0 (? (atom? r0) () (r0 2) () (go (<>r0 + 1) ()))))
 (mime-body hs b)
  (lower (strip (mime-get hs "content-transfer-encoding")) @ e
     (? (e = "base64") (mime-b64 b) (e = "quoted-printable") (mime-qp b) b))
 (mime-fname hs pm)
  (: cd <>(mime-ctype (mime-get hs "content-disposition"))
     f (cd "filename")
     (? (string? f) (mime-words f) (string? (pm "name")) (mime-words (pm "name")) ""))
 (mime-text? lf) (starts? <lf "text/plain")
 (mime-walk hs b d)
  (: ct (mime-ctype (mime-get hs "content-type"))
     t <ct pm <>ct bd (pm "boundary")
     (sub p) (mime-split p @ [h2 b2] (mime-walk (mime-heads h2) b2 (d + 1)))
     ; of an alternative's renderings, the first with plain text, else the richest
     (pick ks l) (? (atom? l) <(rev ks) (any mime-text? <l) <l (pick ks >l))
     (? (starts? t "multipart/" && string? bd && d < 12)
         (: ks (map sub (mime-parts b bd))
            (? (t = "multipart/alternative" && two? ks) (pick ks ks)
               (catmap (k \ k) ks)))
        [[t pm hs (mime-body hs b) (mime-fname hs pm)]]))
 (mime-leaves m) (mime-split m @ [h b] (mime-walk (mime-heads h) b 0))

 ; --- dates: "Thu, 30 Sep 2026 20:22:55 -0400", read leniently, its fields in its zone -----
 (mime-num s) (: (go i a) (? (#s <= i) a (48 <= s i <= 57) (go (i + 1) (a * 10 + s i - 48)) -1)
                 (#s ? (go 0 0) -1))
 (mime-mon s) (: (go l i) (? (atom? l) 0 (starts? (lower s) <l) i (go >l (i + 1))) (go mime-mons 1))
 (mime-zone s)
  (? (5 <= #s && (s 0 = 43 || s 0 = 45) && 0 <= mime-num (snip s 1 5))
      (: v (mime-num (snip s 1 5)) mn (v // 100 * 60 + v % 100) (s 0 = 45 ? (0 - mn) mn))
     (mime-zones (lower s)))
 (mime-date s)
  (: ts (words (replace s "," " "))
     f {}
     (tok w)
      (: n (mime-num w) c (findsub w ":")
         (? (0 <= c) (map mime-num (split ":" w) @ hms (pin f 'hms hms))
            (0 < mime-mon w && !(f 'm)) (pin f 'm (mime-mon w))
            (!(f 'z) && (mime-zone w) != ()) (pin f 'z (mime-zone w))
            (1000 <= n) (pin f 'y n)
            (0 < n && n < 32 && !(f 'd)) (pin f 'd n)
            (0 <= n && n < 100 && (f 'd) && !(f 'y)) (pin f 'y (n < 50 ? (n + 2000) (n + 1900)))
            f))
     (each ts tok,
      (: y (f 'y) m (f 'm) d (f 'd) hms (f 'hms) z (f 'z)
         (? (!y || !m || !d) ()
            (: hh (two? hms ? (max 0 <hms) 0) mm (two? hms && two? >hms ? (max 0 <>hms) 0)
               ss (two? hms && two? >hms && two? >>hms ? (max 0 <>>hms) 0)
               zm (charm? z ? z 0)
               secs (epoch-days y m d * 86400 + hh * 3600 + mm * 60 + ss - zm * 60)
               [secs y m d hh mm zm])))))

 ; --- addresses -------------------------------------------------------------------------
 ; a list cut at the commas outside quotes, angle brackets and comments
 (mime-commas v)
  (: (go i st q a p acc)
      (? (#v <= i) (rev ((snip v st i) . acc))
         (v i @ c
            (? (c = 34) (go (i + 1) st !q a p acc)
               q (go (i + 1) st q a p acc)
               (c = 60) (go (i + 1) st q 1 p acc)
               (c = 62) (go (i + 1) st q 0 p acc)
               (c = 40) (go (i + 1) st q a (p + 1) acc)
               (c = 41) (go (i + 1) st q a (max 0 (p - 1)) acc)
               (c = 44 && !a && p = 0) (go (i + 1) (i + 1) q a p ((snip v st i) . acc))
               (go (i + 1) st q a p acc))))
     (go 0 0 0 0 0 ()))
 (mime-addr1 x)
  (: s (strip x) lt (findsub s "<") gt (fsub s ">" (max 0 lt))
     (? (0 <= lt && lt < gt) [(mime-words (mime-unq (strip (snip s 0 lt)))) (strip (snip s (lt + 1) gt))]
        (findsub s "(" @ k
           (? (k < 0) ["" s]
              (: e (fsub s ")" k)
                 [(mime-words (snip s (k + 1) (e < 0 ? #s e))) (strip (snip s 0 k))])))))
 (mime-addrs s) (filter (a \ #(a 1) || #(a 0)) (map mime-addr1 (mime-commas s))))
) ; module mime
