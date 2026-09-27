; apps/kore/www.l -- www: a web page in a terminal, its links numbered.
;
;   www [-w COLS] URL|FILE        www en.wikipedia.org/wiki/Lisp     www index.html
;
; the three hard parts live elsewhere: wget's round trip fetches (wget.l), lapiz lays the page
; out with every link as [n] (ttpage), and less's engine pages it (less.l). www owns the url
; arithmetic, the history, and a few keys over less's:
;
;   N RETURN   follow link N          N U   link N's url      U   this page's url
;   TAB        the next link on screen, shift-TAB the one before, RETURN follows it
;   o URL      open a url             B  BACKSPACE   back     r   reload
;   m          the page's content     h   the help            every other key is less's
;
; a form that sends by GET shows each text field as a link, [n][name____]: following it
; asks for the text, and RETURN sends the form with it (lapiz lays the rest of the form's
; controls into the link, as they stand). a form that POSTs shows no field.
; a url without a scheme is https, unless it names a file here -- that opens as file:, and
; its links resolve against it. not a terminal: the page is poured plain with its references
; after it, as lynx -dump does, and a server's error status is the exit 8 wget gives it.
;
; a #name lands on the line lapiz laid that id on (ttpage's anchors): on this page as a step
; in the history with no fetch, on another after it loads. a page opened without one opens
; where its own content starts, past its menus (lapiz's " main" / " article" marks), and m
; goes back there; g is still the top.
;
; a page asks for gzip and is unzipped (apps/gz.l); one in latin-1 or windows-1252, by its
; header or its own <meta>, is re-spelled as utf-8, and any other charset is taken as utf-8.
; a <base href> is what the links resolve against. an image is its alt text. the window
; changing width lays the page again, the same link at the top.
;
; out of scope, and said: forms that POST, scripts, cookies, and the pictures themselves.
; the tls peer is not verified (wget's client).
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ww-usage "usage: www [-w COLS] URL|FILE"
   ww-help
    "  kore www -- a web page, its links numbered [n]

  N RETURN          follow link N              N U       show link N's url
  TAB  shift-TAB    the next / last link       RETURN    follow it (a field: fill it in)
  U                 this page's url            r         reload
  o URL             open a url                 B  BS     back a page
  m                 the page's content         g         the very top
  h                 this page                  q         quit (or out of this page)

  and less's keys for the rest: SPACE b j k d u g G /PATTERN n N
"

   ; windows-1252's 0x80..0x9f as code points; latin-1 is it for the rest, as a browser reads it
   ww-1252 [8364 129 8218 402 8222 8230 8224 8225 710 8240 352 8249 338 141 381 143
            144 8216 8217 8220 8221 8226 8211 8212 732 8482 353 8250 339 157 382 376]
   ww-latins '("iso-8859-1" "iso8859-1" "latin1" "l1" "windows-1252" "cp1252" "us-ascii" "ascii")

   ; -- the url arithmetic (RFC 3986 5.2) ---------------------------------------
   ; a url -> [scheme auth path query frag], each part keeping its delimiter ("https:"
   ; "//host" "?q" "#f") and "" when absent, so the parts concatenate back to the url
   (ww-cut s c) (: k (wg-find s c 0) (? (k < 0) [s ""] [(snip s 0 k) (snip s k #s)]))
   (ww-schc? c) ((96 < c < 123) || (64 < c < 91) || (47 < c < 58) || c = 43 || c = 45 || c = 46)
   (ww-split u)
    (: fr (ww-cut u "#") qr (ww-cut <fr "?") r <qr
       c (wg-find r ":" 0)
       sc? (0 < c && (64 < (r 0) < 91 || 96 < (r 0) < 123)
                  && (: (g i) (? (c <= i) 1 (ww-schc? (r i)) (g (i + 1)) 0) (g 0)))
       sc (? sc? (wg-lower (snip r 0 (c + 1))) "")
       t (? sc? (snip r (c + 1) #r) r)
       au? (1 < #t && t 0 = 47 && t 1 = 47)
       k (? au? (: j (wg-find t "/" 2) (? (j < 0) #t j)) 0)
       [sc (snip t 0 k) (snip t k #t) <>qr <>fr])
   (ww-join p) ((p 0) + (p 1) + (p 2) + (p 3) + (p 4))
   ; . and .. out of an absolute path; a path ending in either keeps its trailing slash
   (ww-dots p)
    (? !(0 < #p && p 0 = 47) p
       (: sg >(usplit 47 p)
          (go l acc)
           (? !(two? l) acc
              (: s <l end? !(two? >l)
                 a2 (? (s = "..") (? (two? acc) >acc acc) (s = ".") acc (s . acc))
                 (go >l (? (end? && (s = "." || s = "..")) ("" . a2) a2))))
          ("/" + ujoinc 47 (rev (go sg ())))))
   (ww-resolve base ref)
    (: b (ww-split base) r (ww-split ref)
       sc (r 0) au (r 1) pa (r 2) qu (r 3) fr (r 4)
       (ww-join
        (? #sc [sc au (ww-dots pa) qu fr]
           #au [(b 0) au (ww-dots pa) qu fr]
           !(#pa) [(b 0) (b 1) (b 2) (? #qu qu (b 3)) fr]
           (pa 0 = 47) [(b 0) (b 1) (ww-dots pa) qu fr]
           (: bp (b 2)
              dir (? (#(b 1) && !(#bp)) "/"
                     (: (g i) (? (i < 0) "" (bp i = 47) (snip bp 0 (i + 1)) (g (i - 1))) (g (#bp - 1))))
              [(b 0) (b 1) (ww-dots (dir + pa)) qu fr]))))
   (ww-nofrag u) (: p (ww-split u) (ww-join [(p 0) (p 1) (p 2) (p 3) ""]))
   ; what a person typed -> a url: a scheme stays, a file here opens as file:, the rest is https
   (ww-arg s)
    (? (0 <= wg-find s "://" 0) s
       (two? (uread s)) ("file://" + ww-dots (? (0 < #s && s 0 = 47) s (cwd 0 + "/" + s)))
       ("https://" + s))

   ; -- the fetch ---------------------------------------------------------------
   ; one url -> [0 url kind body code] where url is where the redirects ended and kind is
   ; 'html or 'text, else [1 complaint]. quiet: the screen is raw while this runs
   (ww-kind ct)
    (: t (wg-lower ct)
       (? (!(#t) || 0 <= wg-find t "html" 0) 'html (0 <= wg-find t "text/" 0) 'text ()))
   (ww-get url hops)
    (: p (ww-split url) sc <p u0 (ww-nofrag url)
       (? (sc = "file:")
           (: r (uread (p 2)) nm (p 2)
              htm? (: (suf? x) (#x < #nm && x = snip nm (#nm - #x) #nm) (suf? ".html" || suf? ".htm"))
              (? (two? r) [0 url (? htm? 'html 'text) (ww-body (? htm? "text/html" "") () <>r) 200]
                 [1 ("www: cannot open " + nm)]))
          !(sc = "http:" || sc = "https:") [1 ("www: no door for " + sc + " urls")]
          (: w (wg-url u0)
             r (? (two? w) (wg-ask <w (w 1) (w 2) (w 3) "Accept-Encoding: gzip\r\n") ())
             (? !(two? r) [1 ("www: no answer from " + url)]
                (: code <r hd (r 1)
                   loc (wg-header hd "location")
                   (? (300 <= code < 400 && string? loc)
                       (? (hops < 1) [1 "www: too many redirects"] (ww-get (ww-resolve url loc) (hops - 1)))
                      (: ct (wg-header hd "content-type")
                         k (ww-kind (? (string? ct) ct ""))
                         b (? k (ww-body (? (string? ct) ct "") (wg-header hd "content-encoding") (r 2)) ())
                         (? !k [1 ("www: " + url + " is " + ct + ", not a page")]
                            !(string? b) [1 ("www: " + url + " sent a gzip body that does not open")]
                            [0 url k b code]))))))))
   ; a body as it came -> utf-8 text, or () for a gzip that does not open: the content
   ; coding undone, then a latin-1 page (by its header, else its own <meta>) re-spelled
   (ww-body ct ce b)
    (: z (? (string? ce && wg-lower ce = "gzip") ((cite 'gz 'gz-unzip) b) [1 b])
       (? !(two? z) ()
          (: t <>z cs (: c (ww-cs ct) (? #c c (ww-cs (snip t 0 (min #t 4096)))))
             (? (elem cs ww-latins) (ww-latin t) t))))
   ; the charset a content type or a <meta> names, lower case, or ""
   (ww-cs s)
    (: t (wg-lower s) k (wg-find t "charset=" 0)
       (? (k < 0) ""
          (: i (k + 8) i2 (? (i < #t && elem (t i) '(34 39)) (i + 1) i)
             (snip t i2 ((: (g j) (? (#t <= j || elem (t j) '(34 39 59 32 62 47 9 10 13)) j (g (j + 1)))) i2)))))
   (ww-u8 v) (? (v < 2048) (string (192 + v // 64) + string (128 + v % 64))
                (string (224 + v // 4096) + string (128 + v // 64 % 64) + string (128 + v % 64)))
   ; latin-1 -> utf-8, windows-1252's printing characters where latin-1 has controls
   (ww-latin s)
    (: n #s o (jug 0) tb (tablet 0)
       _ (map (i \ pin tb (128 + i) (ww-u8 (? (i < 32) (ww-1252 i) (128 + i)))) ^128)
       (go i st) (? (n <= i) (: _ (say o (snip s st n)) (slurp o))
                    (s i < 128) (go (i + 1) st)
                    (: _ (say o (snip s st i)) _ (say o (tb (s i))) (go (i + 1) (i + 1))))
       (go 0 0))
   ; what a page's links resolve against: its <base href>, else the page itself
   (ww-base url b)
    (: k (: k1 (wg-find b "<base" 0) (? (0 <= k1) k1 (wg-find b "<BASE" 0)))
       e (? (k < 0) -1 (wg-find b ">" k))
       t (? (e < 0) "" (snip b k e))
       j (wg-find (wg-lower t) "href=" 0)
       h (? (j < 0) ""
            (: i (j + 5) q (? (i < #t) (t i) 0)
               (? (elem q '(34 39)) (: z (wg-find t (string q) (i + 1)) (? (z < 0) "" (snip t (i + 1) z)))
                  (snip t i ((: (g x) (? (#t <= x || elem (t x) '(32 9 10 13)) x (g (x + 1)))) i)))))
       (? #h (ww-resolve url h) url))
   ; a link off the page made absolute. a form field's (form:ACTION?PAIRS) resolves its
   ; action and keeps its pairs, which are the query the form sends
   (ww-abs base u)
    (? !(ww-pre? "form:" u) (ww-resolve base u)
       (: t (snip u 5 #u) q (ww-cut t "?") p (ww-split (ww-resolve base <q))
          ("form:" + ww-join [(p 0) (p 1) (p 2) <>q ""])))
   (ww-pre? p s) (#p <= #s && p = snip s 0 #p)
   ; a fetched page -> [lines urls anchors lines-of-links], the urls absolute, an anchor
   ; [name line], and the line each link n was laid on at (n - 1)
   (ww-lay g w)
    (: url (g 1) k (g 2) body (g 3)
       (? (k = 'text) [(lines body) () () ()]
          (: p ((cite 'lapiz 'ttpage) ((cite 'lapiz 'htread) body) w)
             base (ww-base url body)
             [(lines <p) (map (ww-abs base) (p 1)) (p 2) (p 3)])))
   ; s from i to n with each %XX back to its byte, and a + a space when plus?
   (ww-dec s i n plus?)
    (: o (jug 0)
       (hx c) (? (47 < c < 58) (c - 48) (96 < c < 103) (c - 87) (64 < c < 71) (c - 55) -1)
       (go i) (? (n <= i) (slurp o)
                 (s i = 37 && i + 2 < n && 0 <= hx (s (i + 1)) && 0 <= hx (s (i + 2)))
                  (: _ (put o (hx (s (i + 1)) * 16 + hx (s (i + 2)))) (go (i + 3)))
                 (: _ (put o (? (plus? && s i = 43) 32 (s i))) (go (i + 1))))
       (go i))
   ; a fragment's name: the # off and each %XX back to its byte, the way an id is spelled
   (ww-unpct s) (ww-dec s 1 #s 0)
   ; typed text as a form sends it: a space a +, the rest past the unreserved %XX
   (ww-qenc s)
    (: o (jug 0) hx "0123456789ABCDEF"
       (go i) (? (#s <= i) (slurp o)
                 (: c (s i)
                    _ (? ((96 < c < 123) || (64 < c < 91) || (47 < c < 58) || elem c '(45 46 95 126)) (put o c)
                         (c = 32) (put o 43)
                         (: _ (put o 37) _ (put o (hx (c // 16))) (put o (hx (c % 16)))))
                    (go (i + 1))))
       (go 0))
   ; the line a named place was laid on, or -1
   (ww-place st nm) ((: (g l) (? (one? l) -1 (<(<l) = nm) <>(<l) (g >l))) (st 'anchors))
   (ww-anchor st fr) (ww-place st (ww-unpct fr))
   ; where the page's content starts past its menus -- lapiz's " main", else " article"
   (ww-main st) (: l (ww-place st " main") (? (0 <= l) l (ww-place st " article")))
   ; the page poured plain, then its references numbered, as lynx -dump lays them
   (ww-dump ls urls)
    (: n #urls
       (ref i) ((upad (#(show n) + 4) (show (i + 1) + ". ")) + urls i + "\n")
       (usgr (unlines ls) + (? n ("\nReferences\n\n" + foldl (\ a i (a + ref i)) "" ^n) "")))

   ; -- the keys over less's ----------------------------------------------------
   ; a browser key leaves 'go -- [url push? top] -- for the face to fetch; the rest is less
   (ww-goto st u)
    (: p (ww-split u) sc <p fr (p 4)
       (? (0 < #fr && ww-nofrag u = ww-nofrag (st 'url))
           ; a place on this page: a step in the history, and no fetch
           (: ln (ww-anchor st fr)
              (? (ln < 0) (pgmsg st ("no anchor " + fr + " on this page"))
                 (: _ (pin st 'hist ([(st 'url) (st 'top)] . st 'hist))
                    _ (pin st 'url u)
                    (pgline! st ln))))
          (sc = "form:") (ww-field st u)
          !(sc = "http:" || sc = "https:" || sc = "file:") (pgmsg st ("no door for " + u))
          (: _ (pin st 'go [u 1 -1]) st)))
   (ww-link st n)
    (: us (st 'urls) (? (0 < n <= #us) (us (n - 1)) ()))
   ; a form's field: ask for its text, what it holds already typed in. what follows the last
   ; = is the field's own value, and what is sent puts the text there
   (ww-rfind s cs i) (? (i < 0) -1 (elem (s i) cs) i (ww-rfind s cs (i - 1)))
   (ww-field st u)
    (: k (ww-rfind u '(61) (#u - 1)) j (ww-rfind u '(38 63) k)
       _ (pgask st (ww-dec u (j + 1) k 1 + ": "))
       (pins st 'cmd (ww-dec u (k + 1) #u 1) 'field (snip u 5 (k + 1))))
   ; link n's line when it is on the screen, else -1
   (ww-seen st n)
    (: ls (st 'links) l (? (0 < n <= #ls) (ls (n - 1)) -1)
       (? (0 <= l && pgtopline st <= l < pglast st) l -1))
   ; TAB: the link after the current one, or the first on the screen; d -1 the one before,
   ; or the last on the screen. one off the screen is scrolled to
   (ww-tab st d)
    (: ls (st 'links) n #ls top (pgtopline st) end (pglast st) cur (st 'cur)
       k (? (0 < cur && 0 <= ww-seen st cur) (cur + d)
            (0 < d) ((: (g k l) (? (one? l) k (top <= <l) k (g (k + 1) >l))) 1 ls)
            ((: (g k l acc) (? (one? l || end <= <l) acc (g (k + 1) >l (? (0 <= <l) k acc)))) 1 ls 0))
       (? !(0 < k <= n) (pgmsg st (? (0 < n) "no more links this way" "no links on this page"))
          (: l (ls (k - 1))
             _ (? (l < 0 || 0 <= ww-seen st k) 0 (pgline! st l))
             _ (pins st 'cur k 'hi ("[" + show k + "]"))
             (pgmsg st (show k + ": " + (st 'urls) (k - 1))))))
   ; back within a page is a scroll; back to another page is a fetch
   (ww-back st)
    (? (pgback st) st
       (: h (st 'hist)
          (? !(two? h) (pgmsg st "no previous page")
             (ww-nofrag <(<h) = ww-nofrag (st 'url))
              (: _ (pins st 'hist >h 'url <(<h)) (pggo st <>(<h)))
             (: _ (pins st 'hist >h 'go [<(<h) 0 <>(<h)]) st))))
   (ww-norm st c)
    (: cn (st 'cnt) n (pgcnt st 0)
       spend (\ _ (pins st 'cnt "" 'msg ""))
       (? ((c = 13 || c = 10) && 0 < #cn)
           (: _ (spend ()) u (ww-link st n) (? u (ww-goto st u) (pgmsg st ("no link " + show n))))
          ((c = 13 || c = 10) && 0 <= ww-seen st (st 'cur))
           (: _ (spend ()) (ww-goto st (ww-link st (st 'cur))))
          (c = 9 || c = 265) (: _ (spend ()) (ww-tab st (? (c = 9) 1 -1)))
          (c = 85) (: _ (spend ())
                      (? !(#cn) (pgmsg st (st 'url))
                         (: u (ww-link st n) (pgmsg st (? u (show n + ": " + u) ("no link " + show n))))))
          (c = 111) (: _ (spend ()) (pgask st 111))
          (c = 109) (: _ (spend ()) l (ww-main st)
                       (? (0 <= l) (pgline! st l) (pgmsg st "no main content marked on this page")))
          (c = 66 || c = 127 || c = 8) (: _ (spend ()) (ww-back st))
          (c = 114) (: _ (spend ()) _ (pin st 'go [(st 'url) 0 (st 'top)]) st)
          (c = 104 || c = 72)
           (: _ (spend ())
              (? (two? (st 'sav)) st
                 (: _ (pin st 'sav [(st 'ls) (st 'file) (st 'top)]) (pgload st (lines ww-help) "HELP"))))
          (pgstep st c)))
   (ww-step st c)
    (? (st 'mode = 'c && st 'lead = 111)
        (? (c = 13 || c = 10)
            (: u (st 'cmd) _ (pins st 'mode 'n 'cmd "") (? #u (ww-goto st (ww-arg u)) st))
           (pgstep st c))
       (st 'mode = 'c && string? (st 'lead))                  ; a form field's text
        (? (c = 13 || c = 10)
            (: v (st 'cmd) _ (pins st 'mode 'n 'cmd "" 'lead 47) (ww-goto st (st 'field + ww-qenc v)))
           (pgstep st c))
       (st 'mode = 'n) (ww-norm st c)
       (pgstep st c))
   ; a fetched page into the state: the old one onto the history when asked, the new one
   ; laid at the width and opened where it was left (a back, a reload: top), or fresh
   ; (top -1) at its fragment's place, else where its content starts, else at the top
   (ww-show st g push top)
    (: _ (? (push && #(st 'url)) (pin st 'hist ([(st 'url) (st 'top)] . st 'hist)) 0)
       p (ww-lay g (pgwidth st))
       _ (pgload st <p (g 1))
       _ (pins st 'url (g 1) 'urls (p 1) 'anchors (p 2) 'links (p 3) 'page g 'lw (pgwidth st))
       _ (pins st 'cur 0 'hi "")
       fr ((ww-split (g 1)) 4)
       ln (? (0 <= top) -1 (0 < #fr) (ww-anchor st fr) (ww-main st))
       _ (? (0 <= ln) (pgline! st ln) (pggo st (? (0 <= top) top 0)))
       (pgmsg st (? (200 <= (g 4) < 300) (g 1) ((g 1) + " answered " + show (g 4)))))
   (ww-new w h)
    (: st (pgnew (tablet 0) w h)
       _ (pins st 'url "" 'urls () 'anchors () 'links () 'hist () 'go () 'page () 'lw 0 'cur 0 'field "")
       st)
   ; the window changed width: the page laid again at the new one, with the link that was
   ; first on the screen as far down it as before (the help, laid by less, just rewraps)
   (ww-fit st)
    (: g (st 'page) w (pgwidth st)
       (? (!(two? g) || st 'lw = w || two? (st 'sav)) 0
          (: ls (st 'links) top (pgtopline st) nl (st 'nl)
             k ((: (f k l) (? (one? l) 0 (top <= <l) k (f (k + 1) >l))) 1 ls)
             off (? (0 < k) (ls (k - 1) - top) 0)
             p (ww-lay g w)
             _ (pgload st <p (g 1))
             _ (pins st 'urls (p 1) 'anchors (p 2) 'links (p 3) 'lw w)
             (pgline! st (? (0 < k) ((p 3) (k - 1) - off) (0 < nl) ((top * st 'nl) // nl) 0)))))

   ; -- the face -----------------------------------------------------------------
   (ww-do st)
    (: g (st 'go)
       (? !(two? g) 0
          (: _ (pin st 'go ())
             _ (pgmsg st ("fetching " + <g + " ..."))
             _ (puts (pgframe st)) _ (flush out)
             r (ww-get <g 8)
             (? (<r = 0) (ww-show st r <>g (g 2)) (pgmsg st <>r)))))
   (ww-ride st kq)
    (: e (string 27)
       _ (raw 1)
       _ (puts (e + "[?1049h"))
       (fin _) (: _ (puts (e + "[0m" + e + "[?1049l")) _ (flush out) _ (raw 0) 0)
       (go pend)
        (: _ (ww-do st)
           _ (pgresize st)
           _ (ww-fit st)
           _ (puts (pgframe st)) _ (flush out)
           kr (pgkey kq pend)
           c <kr
           (? (c < 0) (fin ())
              (: _ (ww-step st c) (? (st 'quit) (fin ()) (go <>kr)))))
       (go -1))
   (www-main as)
    (: t (tablet 0)
       o (uopt as t '(119) '(101) ())                       ; -w takes a value
       _ (? (two? o) () (udie 2 ww-usage))
       _ (: c (uoptun t '(119)) (? (nil? c) () (udie 2 ("www: unknown option -" + string c))))
       us <>>o
       _ (? (two? us && one? >us) () (udie 2 ww-usage))
       ws (tty 1)
       hw (? (two? ws) (pgwin ws) [24 80])
       v (uoptv t 119)
       w (? (string? v) (: n (uatoi v) (? (0 < n) n 80)) <>hw)
       g (ww-get (ww-arg <us) 8)
       _ (? (<g = 0) () (udie 1 <>g))
       (? (two? ws)
           (: st (ww-new w <hw) _ (ww-show st g 0 -1) (ww-ride st in))
          (: p (ww-lay g w)
             _ (puts (ww-dump <p (p 1)))
             (? (200 <= (g 4) < 300) 0 8)))))
) ; module 'kore
