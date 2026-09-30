; src/apps/kore/www.l -- www: a web page in a terminal, its links numbered.
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
; a page asks for gzip and is unzipped (src/apps/gz.l); one in latin-1 or windows-1252, by its
; header or its own <meta>, is re-spelled as utf-8, and any other charset is taken as utf-8.
; a <base href> is what the links resolve against. an image is its alt text, and on a
; terminal a png, jpeg or gif is drawn under it as it comes near the screen, two pixels a
; cell (src/apps/kore/pic.l). the window changing width lays the page again, the same link at
; the top.
;
; gopher:// and gemini:// open too. a gopher menu lays its text lines as they are and its
; items as links with their kind, (DIR) (TXT) (?) ..; a search item is a field, sent after a
; tab. gemini's text/gemini is laid as a page, headings, lists, quotes and preformatted
; blocks; its ask for input is a field, the answer sent back as the query. a gemini
; server's key is pinned the first time and held to after -- the protocol's trust
; on first use -- in ~/.love/gemini_hosts; a changed one is refused, and says which line
; to delete to take it.
;
; out of scope, and said: forms that POST, scripts, cookies, pictures other than png, jpeg
; and gif, and a gif's motion. an https server is verified as wget's is (its
; client: a root in the host's bundle, or a pin in ~/.love/tls_pins), and a refusal says why.
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
           (? (atom? l) acc
              (: s <l end? (atom? >l)
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
   ; where a server may send us: http or https to https, http to http, gemini to gemini.
   ; never file: or gopher:, never down from https. a url typed or clicked is not asked
   (ww-hop? from to)
    (: a <(ww-split from) b <(ww-split to)
       (? (a = "gemini:") (b = "gemini:")
          !(a = "http:" || a = "https:") 0
          (b = "https:") 1
          (b = "http:" && a = "http:")))
   (ww-nohop url to) [1 ("www: " + wg-plain url + " sends us to " + wg-plain to + ", which is not followed")]
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
          (sc = "gopher:") (ww-gopher url)
          (sc = "gemini:") (ww-gemini url hops)
          !(sc = "http:" || sc = "https:") [1 ("www: no door for " + sc + " urls")]
          (: w (wg-url u0)
             r (? (two? w) (wg-ask <w (w 1) (w 2) (w 3) "Accept-Encoding: gzip\r\n") ())
             (? (string? r) [1 ("www: " + r)]                      ; the certificate refused, and why
                (atom? r) [1 ("www: no answer from " + url)]
                (: code <r hd (r 1)
                   loc (wg-header hd "location")
                   (? (300 <= code < 400 && string? loc)
                       (: to (ww-resolve url loc)
                          (? (hops < 1) [1 "www: too many redirects"]
                             !(ww-hop? url to) (ww-nohop url to)
                             (ww-get to (hops - 1))))
                      (: ct (wg-header hd "content-type")
                         k (ww-kind (? (string? ct) ct ""))
                         b (? k (ww-body (? (string? ct) ct "") (wg-header hd "content-encoding") (r 2)) ())
                         (? !k [1 ("www: " + url + " is " + ct + ", not a page")]
                            !(string? b) [1 ("www: " + url + " sent a gzip body that does not open")]
                            [0 url k b code]))))))))
   ; -- gopher and gemini: each answer built into html lapiz reads, or text ---------
   ; a page built here: html's own characters escaped, a url's bytes past the unreserved
   ; percent-encoded, lines without their CR
   (ww-esc1 c) (? (c = 38) "&amp;" (c = 60) "&lt;" (c = 62) "&gt;" (c = 34) "&quot;" (string c))
   (ww-esc s) (: o (jug 0) _ (map (i \ say o (ww-esc1 (s i))) (jot #s)) (slurp o))
   (ww-alnum? c) ((47 < c < 58) || (64 < c < 91) || (96 < c < 123))
   (ww-penc s keep)
    (: o (jug 0) hx "0123456789ABCDEF"
       (one c) (? (ww-alnum? c || elem c keep) (string c)
                  ("%" + string (hx (c >> 4)) + string (hx (c & 15))))
       _ (map (i \ say o (one (s i))) (jot #s))
       (slurp o))
   (ww-lns s) (map (l \ ? (0 < #l && (l (#l - 1) = 13)) (snip l 0 (#l - 1)) l) (usplit 10 s))
   ; a url's host and port, the port the scheme's own when none is said
   (ww-hostport u dflt)
    (: a (ww-split u) au (snip (a 1) 2 #(a 1)) hp (ww-cut au ":")
       [<hp (? (1 < #(hp 1)) (: n (unum (snip (hp 1) 1 #(hp 1))) (? (charm? n) n dflt)) dflt)])
   ; the answer to a field, off a query this page's form made (?NAME=v), else ()
   (ww-answer q nm) (? (starts? q ("?" + nm + "=")) (ww-dec q (2 + #nm) #q 1) ())

   ; gopher (RFC 1436; its urls, RFC 4266: gopher://host[:port]/Tselector). a menu's lines
   ; are Tdisplay TAB selector TAB host TAB port, a lone "." after the last. i and 3 lines
   ; are text, laid as they are; the rest are links, each with its kind; a search (7) is a
   ; field to answer, sent after a TAB. h with a URL: selector goes to that url
   (ww-gkind t) (? (t = 49) "(DIR)" (t = 48) "(TXT)" (t = 55) "(?)" (t = 104) "(HTML)"
                   (elem t '(57 53 115 103 73 100)) "(BIN)" (elem t '(56 84)) "(TEL)"
                   ("(" + string t + ")"))
   (ww-gurl h p t sel)
    ("gopher://" + h + (? (p = 70) "" (":" + show p)) + "/" + string t + ww-penc sel '(47 45 46 95 126))
   (ww-pre s) ("<pre><code>" + ww-esc s + "</code></pre>\n")
   (ww-link href txt) ("<a href=\"" + ww-esc href + "\">" + ww-esc txt + "</a>")
   (ww-gmenu s)
    (: o (jug 0) run (tablet 1) _ (pin run 's "")
       (flush-run _) (: r (run 's) _ (pin run 's "") (? (0 < #r) (say o (ww-pre r)) 0))
       (line l)
        (? (l = "." || #l < 1) 0
           (: t (l 0) f (usplit 9 (snip l 1 #l))
              disp (? (two? f) <f "") sel (? (1 < #f) (f 1) "") host (? (2 < #f) (f 2) "")
              port (: n (? (3 < #f) (unum (f 3)) ()) (? (charm? n) n 70))
              (? (t = 105 || t = 51) (pin run 's (run 's + disp + "\n"))
                 (: _ (flush-run 0)
                    href (? (t = 104 && starts? sel "URL:") (snip sel 4 #sel)
                            (t = 55) ("form:" + ww-gurl host port t sel + "?search=")
                            (ww-gurl host port t sel))
                    (say o ("<p>" + ww-gkind t + " " + ww-link href disp + "</p>\n"))))))
       (go ls) (? (two? ls) (? (<ls = ".") 0 (line <ls, go >ls)) 0)
       _ (go (ww-lns s))
       _ (flush-run 0)
       (slurp o))
   ; a text item's lines, its ".." back to "." and its closing "." gone
   (ww-gtxt s) (: ls (ww-lns s)
                  (go l) (? (atom? l) () (<l = ".") () ((? (starts? <l "..") (snip <l 1 #<l) <l) . go >l))
                  (unlines (go ls)))
   (ww-gopher url)
    (: p (ww-split url) hp (ww-hostport url 70) path (p 2) q (p 3)
       t (? (#path < 2) 49 (path 1))
       sel (? (#path < 2) "" (ww-dec path 2 #path 0))
       term (? (#q < 2) () (: a (ww-answer q "search") (? (string? a) a (ww-dec q 1 #q 0))))
       s (cite 'dns 'dial <hp (hp 1))
       (? !(hot? s) [1 ("www: no answer from " + url)]
          (: _ (say s (sel + (? (string? term) ("\t" + term) "") + "\r\n")) _ (flush s)
             b (slurp s) _ (close s)
             (? (t = 49 || t = 55) [0 url 'html (ww-gmenu b) 200]
                (t = 48) [0 url 'text (ww-gtxt b) 200]
                (t = 104) [0 url 'html b 200]
                [1 ("www: " + url + " is a gopher " + ww-gkind t + " item, not a page")]))))

   ; gemini: the url alone on a line, over tls on 1965; the answer's first line a status and
   ; a meta, then the body. 1x asks for input, a field that sends it back as the query; 2x
   ; is the page, text/gemini laid as html and other text as it is; 3x goes elsewhere; the
   ; rest are the server's refusals, said. the server's key is pinned the first time and held
   ; to after (trust on first use, the protocol's own), host:port and "spki:" and the sha-256
   ; of its SubjectPublicKeyInfo a line in ~/.love/gemini_hosts -- the key, so a renewed
   ; certificate over it still holds; an older line without the prefix is a whole
   ; certificate's hash, and holds as that. a changed one is refused and says how to take it
   (ww-pinfile _) (cite 'tls 'pin-path "gemini_hosts")
   (ww-pin key fp cfp)
    (: path (ww-pinfile 0)
       old (cite 'tls 'pin-of path key)
       (? (string? old) (? (old = fp || old = cfp) ()
                           ("the key of " + key + " has changed: it was " + old + ", now " + fp
                            + "; delete its line in " + path + " to take the new one"))
          (: _ (mkdir (snip path 0 (#path - 13)) 448)
             a (open path "a")
             _ (? (hot? a) (say a (key + " " + fp + "\n"), close a) 0)
             ())))
   (ww-gtext s)
    (: o (jug 0) st (tablet 3) _ (pins st 'pre 0 'ul 0 'buf "")
       (block _) (: b (st 'buf) _ (pin st 'buf "") (say o (ww-pre b)))
       (ul on) (? (on = (st 'ul)) 0 (say o (? on "<ul>\n" "</ul>\n"), pin st 'ul on))
       (trim s) (: (a i) (? (i < #s && ((s i = 32) || (s i = 9))) (a (i + 1)) i) (snip s (a 0) #s))
       (line l)
        (? ((st 'pre) = 1)
            (? (starts? l "```") (block 0, pin st 'pre 0)
               (pin st 'buf (st 'buf + l + "\n")))
           (starts? l "```") (ul 0, pin st 'pre 1)
           (starts? l "* ") (ul 1, say o ("<li>" + ww-esc (trim (snip l 2 #l)) + "</li>\n"))
           (ul 0, (? (starts? l "=>")
                  (: r (trim (snip l 2 #l))
                     k ((: (g i) (? (#r <= i || (r i = 32) || (r i = 9)) i (g (i + 1)))) 0)
                     href (snip r 0 k) lab (trim (snip r k #r))
                     (? (0 < #href) (say o ("<p>" + ww-link href (? (0 < #lab) lab href) + "</p>\n")) 0))
                 (starts? l "###") (say o ("<h3>" + ww-esc (trim (snip l 3 #l)) + "</h3>\n"))
                 (starts? l "##") (say o ("<h2>" + ww-esc (trim (snip l 2 #l)) + "</h2>\n"))
                 (starts? l "#") (say o ("<h1>" + ww-esc (trim (snip l 1 #l)) + "</h1>\n"))
                 (starts? l ">")
                  (say o ("<blockquote>\n<p>" + ww-esc (trim (snip l 1 #l)) + "</p>\n</blockquote>\n"))
                 (0 < #(trim l)) (say o ("<p>" + ww-esc l + "</p>\n"))
                 0)))
       _ (map line (ww-lns s))
       _ (? ((st 'pre) = 1) (block 0) (ul 0))
       (slurp o))
   (ww-gemini url hops)
    (: p (ww-split url) hp (ww-hostport url 1965) q (p 3)
       a (ww-answer q "input")
       u (? (string? a) (ww-join [(p 0) (p 1) (p 2) ("?" + ww-penc a '(45 46 95 126)) ""]) (ww-nofrag url))
       t (cite 'tls 'tls-open <hp (hp 1) 'pin-only)
       (? (string? t) [1 ("www: " + t)]
          (: bad (ww-pin (<hp + ":" + show (hp 1)) ("spki:" + sha256 (t 'spki)) (sha256 (t 'cert)))
             (? (string? bad) ((cite 'tls 'tls-close t), [1 ("www: " + bad)])
                (: _ (cite 'tls 'tls-say t (u + "\r\n"))
                   b0 (cite 'tls 'tls-slurp t) _ (close (t 's))
                   b (? (string? b0) b0 "")
                   k (wg-find b "\r\n" 0)
                   hd (? (k < 0) "" (snip b 0 k)) body (? (k < 0) "" (snip b (k + 2) #b))
                   code (? (2 <= #hd) (unum (snip hd 0 2)) ())
                   meta (? (3 < #hd) (snip hd 3 #hd) "")
                   (? !(string? b0) [1 ("www: " + wg-cut <hp (t 'why))]
                      !(charm? code) [1 ("www: " + url + " answered no gemini status")]
                      (code < 20)
                       (: form ("form:" + ww-join [(p 0) (p 1) (p 2) "" ""] + "?input=")
                          lab (? (code = 11) "[answer, unshown]" "[answer]")
                          [0 u 'html ("<p>" + ww-esc meta + "</p>\n<p>" + ww-link form lab + "</p>\n") 200])
                      (code < 30) (: mime (? (0 < #meta) (wg-lower meta) "text/gemini")
                                     (? (starts? mime "text/gemini") [0 u 'html (ww-gtext body) 200]
                                        (starts? mime "text/") [0 u 'text body 200]
                                        [1 ("www: " + url + " is " + meta + ", not a page")]))
                      (code < 40) (: to (ww-resolve url meta)
                                     (? (hops < 1) [1 "www: too many redirects"]
                                        !(ww-hop? url to) (ww-nohop url to)
                                        (ww-get to (hops - 1))))
                      (code < 60) [1 ("www: " + url + " -- " + hd)]
                      [1 ("www: " + url + " wants a client certificate (" + hd + ")")]))))))

   ; a body as it came -> utf-8 text, or () for a gzip that does not open: the content
   ; coding undone, then a latin-1 page (by its header, else its own <meta>) re-spelled
   (ww-body ct ce b)
    (: z (? (string? ce && wg-lower ce = "gzip") (cite 'gz 'gz-unzip b) [1 b])
       (? (atom? z) ()
          (: t <>z cs (: c (ww-cs ct) (? #c c (ww-cs (snip t 0 (min #t 4096)))))
             (? (elem cs ww-latins) (ww-latin t) t))))
   ; the charset a content type or a <meta> names, lower case, or ""
   (ww-cs s)
    (: t (wg-lower s) k (wg-find t "charset=" 0)
       (? (k < 0) ""
          (: i (k + 8) i2 (? (i < #t && elem (t i) '(34 39)) (i + 1) i)
             (snip t i2 ((: (g j) (? (#t <= j || elem (t j) '(34 39 59 32 62 47 9 10 13)) j (g (j + 1)))) i2)))))
   ; latin-1 -> utf-8, windows-1252's printing characters where latin-1 has controls
   (ww-latin s)
    (: n #s o (jug 0) tb (tablet 0)
       _ (map (i \ pin tb (128 + i) (utf8 (? (i < 32) (ww-1252 i) (128 + i)))) ^128)
       (go i st) (? (n <= i) (say o (snip s st n), slurp o)
                    (s i < 128) (go (i + 1) st)
                    (say o (snip s st i), say o (tb (s i)), go (i + 1) (i + 1)))
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
    (? !(starts? u "form:") (ww-resolve base u)
       (: t (snip u 5 #u) q (ww-cut t "?") p (ww-split (ww-resolve base <q))
          ("form:" + ww-join [(p 0) (p 1) (p 2) <>q ""])))
   ; a fetched page -> [lines urls anchors lines-of-links], the urls absolute, an anchor
   ; [name line], and the line each link n was laid on at (n - 1)
   (ww-lay g w)
    (: url (g 1) k (g 2) body (g 3)
       (? (k = 'text) [(lines body) () () ()]
          (: p (cite 'lapiz 'ttpage (cite 'lapiz 'htread body) w)
             base (ww-base url body)
             [(lines <p) (map (ww-abs base) (p 1)) (p 2) (p 3)])))
   ; s from i to n with each %XX back to its byte, and a + a space when plus?
   (ww-dec s i n plus?)
    (: o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (s i = 37 && i + 2 < n && 0 <= hexv (s (i + 1)) && 0 <= hexv (s (i + 2)))
                  (put o (hexv (s (i + 1)) * 16 + hexv (s (i + 2))), go (i + 3))
                 (put o (? (plus? && s i = 43) 32 (s i)), go (i + 1)))
       (go i))
   ; a fragment's name: the # off and each %XX back to its byte, the way an id is spelled
   (ww-unpct s) (ww-dec s 1 #s 0)
   (ww-qenc s) (cite 'lapiz 'hpe s)      ; typed text as a form sends it
   ; the line a named place was laid on, or -1
   (ww-place st nm) ((: (g l) (? (atom? l) -1 (<(<l) = nm) <>(<l) (g >l))) (st 'anchors))
   (ww-anchor st fr) (ww-place st (ww-unpct fr))
   ; where the page's content starts past its menus -- lapiz's " main", else " article"
   (ww-main st) (: l (ww-place st " main") (? (0 <= l) l (ww-place st " article")))
   ; the page poured plain, then its references numbered, as lynx -dump lays them
   (ww-dump ls urls)
    (: n #urls
       (ref i) ((upad (#(show n) + 4) (show (i + 1) + ". ")) + urls i + "\n")
       (wg-plain (usgr (unlines ls) + (? n ("\nReferences\n\n" + foldl (\ a i (a + ref i)) "" ^n) ""))))

   ; -- pictures -----------------------------------------------------------------
   ; on a terminal a picture is drawn under the line lapiz laid its mark on (" img SRC"),
   ; two pixels a cell: the upper the colour of a ▀, the lower its background. one is
   ; fetched when it comes near the screen, and kept by url for the session
   (ww-marks p)
    (foldl (\ acc a (? (starts? <a " img ") ([(a 1) (snip <a 5 #<a)] . acc) acc)) () (rev (p 2)))
   ; an image's bytes, redirects followed, or (). a file: picture only on a file: page
   (ww-fetch from url hops)
    (: p (ww-split url) sc <p
       (? (sc = "file:") (? (<(ww-split from) = "file:") (: r (uread (p 2)) (? (two? r) <>r ())) ())
          !(sc = "http:" || sc = "https:") ()
          (: w (wg-url (ww-nofrag url))
             r (? (two? w) (wg-ask <w (w 1) (w 2) (w 3) "") ())
             (? (atom? r) ()
                (: code <r loc (wg-header (r 1) "location")
                   (? ((300 <= code < 400) && string? loc && 0 < hops)
                       (: to (ww-resolve url loc) (? (ww-hop? url to) (ww-fetch url to (hops - 1)) ()))
                      (200 <= code < 300) (r 2)
                      ()))))))
   ; bytes -> [w h rgba], or 'none for what cannot be drawn: a png, jpeg or gif (its first
   ; frame) of up to 4 megapixels
   (ww-picture b)
    (: d (pic-size b)
       (? (atom? d || 4194304 < (d 0 * d 1)) 'none
          (: r (pic-decode b) (? (two? r) r 'none))))
   ; a picture as rows of cells at most cols wide and rows tall, set in at the text's own
   ; margin where there is room for it
   (ww-art im cols0 rows deep)
    (: pad (? (20 < cols0) "     " "")
       (map (r \ pad + r) (pic-art im (cols0 - #pad) rows deep)))
   ; each drawn picture as [line rows], off the marks of the raw layout
   (ww-arts st p)
    (: g (st 'page) base (ww-base (g 1) (g 3)) c (st 'imgs)
       deep (pic-deep 0)
       rows (max 2 (pgbody st - 1))
       (foldl (\ acc m (: im (peep c (ww-resolve base (m 1)) 'none)
                          (? (im = 'none) acc (acc + [[<m (ww-art im (pgwidth st) rows deep)]]))))
              () (ww-marks p)))
   ; a line of the raw layout -> where it lands with the pictures in
   (ww-shift ins l) (foldl (\ n a (? (<a < l) (n + #(a 1)) n)) l ins)
   ; the pictures' rows spliced in under their lines, the links and anchors moved with them
   (ww-splice p ins)
    (: t (foldl (\ t a (pin t <a (peep t <a () + a 1))) (tablet 0) ins)
       ls (: (go l i acc) (? (atom? l) (rev acc)
                              (go >l (i + 1) (foldl (\ acc r (r . acc)) (<l . acc) (peep t i ()))))
             (go <p 0 ()))
       [ls (p 1) (map (a \ [<a (ww-shift ins (a 1))]) (p 2))
        (map (l \ ? (l < 0) l (ww-shift ins l)) (p 3))])
   ; a raw layout into the pager with the pictures fetched so far, the view where it was
   (ww-load st p)
    (: ins (ww-arts st p) q (ww-splice p ins) top (st 'top)
       _ (pins st 'raw p 'ins ins 'urls (q 1) 'anchors (q 2) 'links (q 3))
       _ (pgload st <q (st 'url))
       (pggo st top))
   ; fetch the pictures whose marks are on the screen or the one after, then lay them in
   (ww-pictures st)
    (: p (st 'raw) g (st 'page)
       (? (atom? p || two? (st 'sav)) 0
          (: base (ww-base (g 1) (g 3)) c (st 'imgs) ins (st 'ins)
             top (pgtopline st) end (pglast st) reach (end + (end - top))
             due (filter (m \ (: l (ww-shift ins <m) u (ww-resolve base (m 1))
                               (top <= l <= reach && nil? (peep c u ()))))
                         (ww-marks p))
             (? (atom? due) 0
                (: n #due
                   _ (map (i \ (: u (ww-resolve base (due i 1))
                                  _ (pgmsg st ("fetching picture " + show (i + 1) + " of " + show n + " ..."))
                                  _ (puts (pgframe st)) _ (flush out)
                                  (pin c u (ww-picture (ww-fetch (g 1) u 4)))))
                          ^n)
                   _ (pgmsg st "")
                   (ww-load st p))))))

   ; -- the keys over less's ----------------------------------------------------
   ; a browser key leaves 'go -- [url push? top] -- for the face to fetch; the rest is less
   (ww-goto st u)
    (: p (ww-split u) sc <p fr (p 4)
       (? (0 < #fr && ww-nofrag u = ww-nofrag (st 'url))
           ; a place on this page: a step in the history, and no fetch
           (: ln (ww-anchor st fr)
              (? (ln < 0) (pgmsg st ("no anchor " + fr + " on this page"))
                 (pin st 'hist ([(st 'url) (st 'top)] . st 'hist), pin st 'url u, pgline! st ln)))
          (sc = "form:") (ww-field st u)
          !(elem sc '("http:" "https:" "file:" "gopher:" "gemini:")) (pgmsg st ("no door for " + u))
          (pin st 'go [u 1 -1], st)))
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
            (0 < d) ((: (g k l) (? (atom? l) k (top <= <l) k (g (k + 1) >l))) 1 ls)
            ((: (g k l acc) (? (atom? l || end <= <l) acc (g (k + 1) >l (? (0 <= <l) k acc)))) 1 ls 0))
       (? !(0 < k <= n) (pgmsg st (? (0 < n) "no more links this way" "no links on this page"))
          (: l (ls (k - 1))
             _ (? (l < 0 || 0 <= ww-seen st k) 0 (pgline! st l))
             _ (pins st 'cur k 'hi ("[" + show k + "]"))
             (pgmsg st (show k + ": " + (st 'urls) (k - 1))))))
   ; back within a page is a scroll; back to another page is a fetch
   (ww-back st)
    (? (pgback st) st
       (: h (st 'hist)
          (? (atom? h) (pgmsg st "no previous page")
             (ww-nofrag <(<h) = ww-nofrag (st 'url))
              (pins st 'hist >h 'url <(<h), pggo st <>(<h))
             (pins st 'hist >h 'go [<(<h) 0 <>(<h)], st))))
   (ww-norm st c)
    (: cn (st 'cnt) n (pgcnt st 0)
       spend (_ \ (pins st 'cnt "" 'msg ""))
       (? ((c = 13 || c = 10) && 0 < #cn)
           (: _ (spend ()) u (ww-link st n) (? u (ww-goto st u) (pgmsg st ("no link " + show n))))
          ((c = 13 || c = 10) && 0 <= ww-seen st (st 'cur))
           (spend (), ww-goto st (ww-link st (st 'cur)))
          (c = 9 || c = 265) (spend (), ww-tab st (? (c = 9) 1 -1))
          (c = 85) (spend (), (? !(#cn) (pgmsg st (st 'url))
                         (: u (ww-link st n) (pgmsg st (? u (show n + ": " + u) ("no link " + show n))))))
          (c = 111) (spend (), pgask st 111)
          (c = 109) (: _ (spend ()) l (ww-main st)
                       (? (0 <= l) (pgline! st l) (pgmsg st "no main content marked on this page")))
          (c = 66 || c = 127 || c = 8) (spend (), ww-back st)
          (c = 114) (spend (), pin st 'go [(st 'url) 0 (st 'top)], st)
          (c = 104 || c = 72)
           (spend (), (? (two? (st 'sav)) st
                 (pin st 'sav [(st 'ls) (st 'file) (st 'top)], pgload st (lines ww-help) "HELP")))
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
       _ (pins st 'url (g 1) 'page g 'lw (pgwidth st))
       _ (ww-load st (ww-lay g (pgwidth st)))
       _ (pins st 'cur 0 'hi "")
       fr (ww-split (g 1) 4)
       ln (? (0 <= top) -1 (0 < #fr) (ww-anchor st fr) (ww-main st))
       _ (? (0 <= ln) (pgline! st ln) (pggo st (? (0 <= top) top 0)))
       (pgmsg st (? (200 <= (g 4) < 300) (g 1) ((g 1) + " answered " + show (g 4)))))
   (ww-new w h)
    (: st (pgnew (tablet 0) w h)
       _ (pins st 'url "" 'urls () 'anchors () 'links () 'hist () 'go () 'page () 'lw 0 'cur 0 'field "")
       _ (pins st 'raw () 'ins () 'imgs (tablet 0))
       st)
   ; the window changed width: the page laid again at the new one, with the link that was
   ; first on the screen as far down it as before (the help, laid by less, just rewraps)
   (ww-fit st)
    (: g (st 'page) w (pgwidth st)
       (? ((atom? g) || st 'lw = w || two? (st 'sav)) 0
          (: ls (st 'links) top (pgtopline st) nl (st 'nl)
             k ((: (f k l) (? (atom? l) 0 (top <= <l) k (f (k + 1) >l))) 1 ls)
             off (? (0 < k) (ls (k - 1) - top) 0)
             _ (ww-load st (ww-lay g w))
             _ (pin st 'lw w)
             (pgline! st (? (0 < k) (st 'links (k - 1) - off) (0 < nl) ((top * st 'nl) // nl) 0)))))

   ; -- the face -----------------------------------------------------------------
   (ww-do st)
    (: g (st 'go)
       (? (atom? g) 0
          (: _ (pin st 'go ())
             _ (pgmsg st ("fetching " + <g + " ..."))
             _ (puts (pgframe st)) _ (flush out)
             r (ww-get <g 8)
             (? (<r = 0) (ww-show st r <>g (g 2)) (pgmsg st <>r)))))
   (ww-ride st kq)
    (: e (string 27)
       _ (raw 1)
       _ (puts (e + "[?1049h"))
       (fin _) (puts (e + "[0m" + e + "[?1049l"), flush out, raw 0, 0)
       (go pend)
        (: _ (ww-do st)
           _ (pgresize st)
           _ (ww-fit st)
           _ (ww-pictures st)
           _ (puts (pgframe st)) _ (flush out)
           kr (pgkey kq pend)
           c <kr
           (? (c < 0) (fin ())
              (ww-step st c, (? (st 'quit) (fin ()) (go <>kr)))))
       (go -1))
   (www-main as)
    (: t (tablet 0)
       o (uopt as t '(119) '(101) ())                       ; -w takes a value
       _ (? (two? o) () (udie 2 ww-usage))
       _ (: c (uoptbad as t '(119)) (? !c () (udie 2 ("www: unknown option -" + string c))))
       us <>>o
       _ (? (two? us && atom? >us) () (udie 2 ww-usage))
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
