; apps/kore/www.l -- www: a web page in a terminal, its links numbered.
;
;   www [-w COLS] URL|FILE        www en.wikipedia.org/wiki/Lisp     www index.html
;
; the three hard parts live elsewhere: wget's round trip fetches (wget.l), lapiz lays the page
; out with every link as [n] (ttpage), and less's engine pages it (less.l). www owns the url
; arithmetic, the history, and a few keys over less's:
;
;   N RETURN   follow link N          N U   link N's url      U   this page's url
;   o URL      open a url             B  BACKSPACE   back     r   reload
;   h          the help               every other key is less's
;
; a url without a scheme is https, unless it names a file here -- that opens as file:, and
; its links resolve against it. not a terminal: the page is poured plain with its references
; after it, as lynx -dump does, and a server's error status is the exit 8 wget gives it.
;
; a #name lands on the line lapiz laid that id on (ttpage's anchors): on this page as a step
; in the history with no fetch, on another after it loads.
;
; out of scope, and said: forms, scripts, cookies, images, and any charset but utf-8. the
; tls peer is not verified (wget's client).
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ww-usage "usage: www [-w COLS] URL|FILE"
   ww-help
    "  kore www -- a web page, its links numbered [n]

  N RETURN          follow link N              N U       show link N's url
  U                 this page's url            r         reload
  o URL             open a url                 B  BS     back a page
  h                 this page                  q         quit (or out of this page)

  and less's keys for the rest: SPACE b j k d u g G /PATTERN n N
"

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
              (? (two? r) [0 url (? htm? 'html 'text) <>r 200] [1 ("www: cannot open " + nm)]))
          !(sc = "http:" || sc = "https:") [1 ("www: no door for " + sc + " urls")]
          (: w (wg-url u0)
             r (? (two? w) (wg-once <w (w 1) (w 2) (w 3)) ())
             (? !(two? r) [1 ("www: no answer from " + url)]
                (: code <r hd (r 1)
                   loc (wg-header hd "location")
                   (? (300 <= code < 400 && string? loc)
                       (? (hops < 1) [1 "www: too many redirects"] (ww-get (ww-resolve url loc) (hops - 1)))
                      (: ct (wg-header hd "content-type")
                         k (ww-kind (? (string? ct) ct ""))
                         (? k [0 url k (r 2) code] [1 ("www: " + url + " is " + ct + ", not a page")]))))))))
   ; a fetched page -> [lines urls anchors], the urls absolute against the page's own and
   ; an anchor [name line]
   (ww-lay g w)
    (: url (g 1) k (g 2) body (g 3)
       (? (k = 'text) [(lines body) () ()]
          (: p ((cite 'lapiz 'ttpage) ((cite 'lapiz 'htread) body) w)
             [(lines <p) (map (ww-resolve url) (p 1)) (p 2)])))
   ; a fragment's name: the # off and each %XX back to its byte, the way an id is spelled
   (ww-unpct s)
    (: n #s o (jug 0)
       (hx c) (? (47 < c < 58) (c - 48) (96 < c < 103) (c - 87) (64 < c < 71) (c - 55) -1)
       (go i) (? (n <= i) (slurp o)
                 (s i = 37 && i + 2 < n && 0 <= hx (s (i + 1)) && 0 <= hx (s (i + 2)))
                  (: _ (put o (hx (s (i + 1)) * 16 + hx (s (i + 2)))) (go (i + 3)))
                 (: _ (put o (s i)) (go (i + 1))))
       (go 1))
   ; the line a fragment lands on, or -1
   (ww-anchor st fr)
    (: nm (ww-unpct fr)
       ((: (g l) (? (one? l) -1 (<(<l) = nm) <>(<l) (g >l))) (st 'anchors)))
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
          !(sc = "http:" || sc = "https:" || sc = "file:") (pgmsg st ("no door for " + u))
          (: _ (pin st 'go [u 1 0]) st)))
   (ww-link st n)
    (: us (st 'urls) (? (0 < n <= #us) (us (n - 1)) ()))
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
          (c = 85) (: _ (spend ())
                      (? !(#cn) (pgmsg st (st 'url))
                         (: u (ww-link st n) (pgmsg st (? u (show n + ": " + u) ("no link " + show n))))))
          (c = 111) (: _ (spend ()) (pgask st 111))
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
       (st 'mode = 'n) (ww-norm st c)
       (pgstep st c))
   ; a fetched page into the state: the old one onto the history when asked, the new one
   ; laid at the width and opened where it was left (a back, a reload), else at its
   ; fragment's place, else at the top
   (ww-show st g push top)
    (: _ (? (push && #(st 'url)) (pin st 'hist ([(st 'url) (st 'top)] . st 'hist)) 0)
       p (ww-lay g (pgwidth st))
       _ (pgload st <p (g 1))
       _ (pins st 'url (g 1) 'urls (p 1) 'anchors (p 2))
       ln (: fr ((ww-split (g 1)) 4) (? (top = 0 && 0 < #fr) (ww-anchor st fr) -1))
       _ (? (0 <= ln) (pgline! st ln) (pggo st top))
       (pgmsg st (? (200 <= (g 4) < 300) (g 1) ((g 1) + " answered " + show (g 4)))))
   (ww-new w h) (: st (pgnew (tablet 0) w h) _ (pins st 'url "" 'urls () 'anchors () 'hist () 'go ()) st)

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
           (: st (ww-new w <hw) _ (ww-show st g 0 0) (ww-ride st in))
          (: p (ww-lay g w)
             _ (puts (ww-dump <p (p 1)))
             (? (200 <= (g 4) < 300) 0 8)))))
) ; module 'kore
