; src/tools/xbell.l -- the daily bell thread: B(n) in base 36 (test/bell.l's numbers), drawn
; as a png and posted to x as a reply to the post before it. a timer runs it often; a run
; posts at most one number, and only while the thread is behind the day (utc).
;
;   love src/tools/xbell.l                  post the next number if one is due
;   love src/tools/xbell.l --dry-run        draw it to next.png, post nothing
;   love src/tools/xbell.l --init N ID [AT] next is B(N), replying to post ID; B(N - 1) is
;                                           due on post AT's day (else ID's)
;   love src/tools/xbell.l --whoami         check the keys (one paid read)
;
; ~/.local/share/xbell/ ($XBELL_DIR) holds the keys, config.l, state.l, next.png and log. the
; keys are oauth 1.0a, `name: value` lines in x.com.oauth.secret ($XBELL_KEYS). state.l is
; (n reply-id row): row is the bell triangle's row n, whose head is B(n).
(borrow 'json)
(borrow 'bytes)
(borrow 'posix)
(:
   home (getenv "HOME" || "")
   dir ((getenv "XBELL_DIR" || (home + "/.local/share/xbell")) + "/")
   secret-path (getenv "XBELL_KEYS" || (dir + "x.com.oauth.secret"))
   api "api.x.com"

   ; files
   (file-read p) (: f (open p "r") (? !(hot? f) () (slurp f @ s (close f, s))))
   (file-write p s) (: t (p + ".new") f (open t "w") _ (say f s) _ (close f) (rename t p))
   (log s) (: f (open (dir + "log") "a") _ (say f (show (clock 0 // 1000) + " " + s + "\n")) (close f))
   (die s) (log s, udie 1 ("xbell: " + s))
   (cfg k d) (: s (file-read (dir + "config.l")) (peep (s ? (read s) {}) k d))

   ; "api key: v" lines -> pinned into t by the words before the colon
   (pairs t s)
    (foldl (t \ l \ (: k (findsub l ": ")
                      (k < 0 ? t (pin t (snip l 0 k) (trim (snip l (k + 2) #l))))))
           t (split "\n" (s || "")))
   (secrets _)
    (: s (file-read secret-path)
       (? !s (die ("cannot read " + secret-path)) (pairs {} s)))
   (trim s) (: (go a b) (b > a && s (b - 1) <= 32 ? (go a (b - 1)) (snip s a b))
               (go 0 #s))

   ; bell
   (row-next r)
    (: (go r a acc) (r ? (go >r (a + <r) (a . acc)) (rev (a . acc)))
       (go r (r (#r - 1)) ()))
   (row-at n) (: (go k r) (k = n ? r (go (k + 1) (row-next r))) (go 0 [1]))
   digits "0123456789abcdefghijklmnopqrstuvwxyz"
   (b36 n) (: (go n acc) (n < 36 ? (string (digits n) + acc)
                              (go (n // 36) (string (digits (n % 36)) + acc)))
              (go n ""))

   ; drawing
   ; the console's terminus 8x16, read back once through the painter: glyph c -> 16 row bytes
   glyphs
    (: cs digits n #cs
       scr (screen (cask (screen () 1 n)) 1 n)
       _ (scribe scr cs)
       w (n * 8) buf (cask (w * 16 * 4))
       _ (dye scr buf w 0 -1 ())
       (bit x y) ((peep buf (4 * (y * w + x)) 0) > 127 ? 1 0)
       (rowbyte i y) (foldl (a \ x \ a * 2 + bit (i * 8 + x) y) 0 ^8)
       (foldl (t \ i \ pin t (cs i) (map (rowbyte i) ^16)) {} ^n))
   (rgba c) (string [(c >> 16 & 255) (c >> 8 & 255) (c & 255) 255])
   ; a png of s wrapped at cols, scale pixels a dot, a margin of one cell
   (draw s cols scale fg bg)
    (: rows ((#s + cols - 1) // cols)
       F (rgba fg) B (rgba bg)
       (dot b) (foldl (a \ _ \ a + (b ? F B)) "" ^scale)
       ; the scaled pixels of one glyph row byte, made once per byte value
       chunk (foldl (t \ v \ pin t v (foldl (a \ x \ a + dot (v >> (7 - x) & 1)) "" ^8)) {} ^256)
       W ((cols + 2) * 8 * scale) H ((rows + 2) * 16 * scale)
       blank (foldl (a \ _ \ a + B) "" ^W)
       pad (foldl (a \ _ \ a + B) "" ^(8 * scale))
       j (jug 0)
       (line y) (foldl (a \ _ \ (say j a, a)) y ^scale)
       _ (each ^(16 * scale) (_ \ say j blank))
       _ (each ^rows (r \ (: t (snip s (r * cols) (min #s (r * cols + cols)))
                          (each ^16 (y \ line (pad + (foldl (a \ c \ a + chunk (glyphs c y)) "" (chars t))
                                                + pad + rep blank (cols - #t) scale))))))
       _ (each ^(16 * scale) (_ \ say j blank))
       (cite 'png 'png-encode W H (slurp j)))
   ; blank pixels for a short last line
   (rep blank k scale) (snip blank 0 (k * 8 * scale * 4))

   ; oauth 1.0a
   unreserved "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
   hexd "0123456789ABCDEF"
   (pct s) (foldl (a \ i \ (: c (s i)
                             (a + (elem c unreserved ? (string c)
                                     ("%" + string (hexd (c >> 4)) + string (hexd (c & 15)))))))
                  "" ^#s)
   (hmac-sha1 k m)
    (: kp (#k > 64 ? (hex2b (sha1 k)) k)
       kp (kp + zbytes (64 - #kp))
       (pad b) (string (map (i \ kp i ^ b) ^64))
       (hex2b (sha1 (pad 92 + hex2b (sha1 (pad 54 + m))))))
   b64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (b64 s)
    (: n #s j (jug 0)
       (at i) (i < n ? (s i) 0)
       (go i) (? (i < n)
                 (: v (at i << 16 | at (i + 1) << 8 | at (i + 2))
                    q (string [(b64set (v >> 18 & 63)) (b64set (v >> 12 & 63))
                               (i + 1 < n ? (b64set (v >> 6 & 63)) 61)
                               (i + 2 < n ? (b64set (v & 63)) 61)])
                    (say j q, go (i + 3))))
       _ (go 0)
       (slurp j))
   (nonce _) (: f (open "/dev/urandom" "r") b (string (map (_ \ see f) ^16)) (close f, b2hex b))
   ; the pairs go in sorted, as the signature's base string wants them
   (authz ks meth url)
    (: ps [["oauth_consumer_key" (key ks "api key" "consumer key")] ["oauth_nonce" (nonce 0)]
           ["oauth_signature_method" "HMAC-SHA1"] ["oauth_timestamp" (show (clock 0 // 1000))]
           ["oauth_token" (ks "access token")] ["oauth_version" "1.0"]]
       q (join "&" (map (p \ p 0 + "=" + pct (p 1)) ps))
       base (meth + "&" + pct url + "&" + pct q)
       sk (pct (key ks "api key secret" "consumer key secret") + "&" + pct (ks "access token secret"))
       sig (b64 (hmac-sha1 sk base))
       ("OAuth " + join ", " (map (p \ p 0 + "=\"" + pct (p 1) + "\"")
                                (ps + [["oauth_signature" sig]]))))
   (key ks a b) (ks a || ks b)                           ; the portal says api or consumer
   (join sep l) (l ? (foldl (a \ x \ a + sep + x) <l >l) "")

   ; https
   ; -> [status body] | a string saying why not
   (call ks meth path body)
    (: t (cite 'tls 'tls-open api 443 'verify)
       (? (string? t) ("tls: " + t)
          (: req (meth + " " + path + " HTTP/1.1\r\nHost: " + api + "\r\n"
                  + "Authorization: " + authz ks meth ("https://" + api + path) + "\r\n"
                  + "User-Agent: xbell\r\nConnection: close\r\n"
                  + (body ? ("Content-Type: application/json\r\nContent-Length: "
                             + show #body + "\r\n")
                            (meth = "POST" ? "Content-Length: 0\r\n" ""))
                  + "\r\n" + (body || ""))
             _ (cite 'tls 'tls-say t req)
             r (cite 'tls 'tls-slurp t)
             k (findsub r "\r\n\r\n")
             (? (k < 0) "no answer"
                (: head (snip r 0 k) b (snip r (k + 4) #r)
                   [(read (snip head 9 12))
                    ((findsub (lower head) "transfer-encoding: chunked") < 0 ? b (unchunk b))])))))
   (lower s) (string (map (i \ (: c (s i) (64 < c && c < 91 ? (c + 32) c))) ^#s))
   (unchunk b)
    (: j (jug 0)
       (go p) (: e (findsub (snip b p #b) "\r\n")
                 n (e < 0 ? 0 (read ("0x" + snip b p (p + e))))
                 (? (n > 0) (say j (snip b (p + e + 2) (p + e + 2 + n)), go (p + e + 4 + n))))
       _ (go 0)
       (slurp j))
   ; the json answer's data.id, or die with what the server said
   (id-of what r)
    (? (string? r) (die (what + ": " + r))
       (: v (json-read (r 1)) d ((two? v && v 0) ? (peep (v 1) "data" {}) {})
          (? ((r 0 = 200 || r 0 = 201) && peep d "id" ()) (peep d "id" ())
             (die (what + ": " + show (r 0) + " " + r 1)))))

   (upload ks png)
    (id-of "upload" (call ks "POST" "/2/media/upload"
                          (json-show {"media" (b64 png) "media_category" "tweet_image"})))
   (tweet ks text reply media)
    (id-of "post" (call ks "POST" "/2/tweets"
                        (json-show {"text" text "reply" {"in_reply_to_tweet_id" reply}
                                    "media" {"media_ids" [media]}})))

   ; days
   ; "yyyy-mm-dd" -> days since 1970-01-01 (hinnant's days_from_civil)
   (day-of s)
    (: y (read (snip s 0 4)) m (read (strip0 (snip s 5 7))) d (read (strip0 (snip s 8 10)))
       y (m <= 2 ? (y - 1) y)
       era (y // 400) yoe (y - era * 400)
       doy ((153 * (m > 2 ? (m - 3) (m + 9)) + 2) // 5 + d - 1)
       doe (yoe * 365 + yoe // 4 - yoe // 100 + doy)
       (era * 146097 + doe - 719468))
   (strip0 s) (s 0 = 48 ? (snip s 1 #s) s)
   (today _) (clock 0 // 86400000)
   ; the index the thread should have reached today, from config's anchor
   (due _) (: a (cfg 'anchor-day 0) (cfg 'anchor-n 0 + today 0 - (string? a ? (day-of a) a)))
   ; a post id's day: the id's top bits are ms since twitter's epoch
   (id-day id) ((((read id) >> 22) + 1288834974657) // 86400000)

   ; the run
   (state _) (: s (file-read (dir + "state.l")) (s ? (read s) ()))
   (picture n row)
    (draw (b36 <row) (cfg 'cols 0 || max 16 (int ((1 / 2) (2 * #(b36 <row))) + 1))
          (cfg 'scale 2) (cfg 'fg 16777215) (cfg 'bg 0))
   (caption n) (: f (cfg 'text "") (f @ "" "" (subst f "{n}" (show n))))
   (subst s a b) (: k (findsub s a) (k < 0 ? s (snip s 0 k + b + subst (snip s (k + #a) #s) a b)))
   (step _)
    (: st (state 0)
       _ (? !st (die "no state; run --init N ID first"))
       n (st 0) reply (st 1) row (st 2)
       (? (n > due 0) 0
          (: ks (secrets 0)
             media (upload ks (picture n row))
             id (tweet ks (caption n) reply media)
             _ (file-write (dir + "state.l") ("'" + show [(n + 1) id (row-next row)]))
             (log ("posted B(" + show n + ") as " + id)))))
   (main a)
    (a @
       ("--dry-run" . _)
        (: st (state 0) n (st 0) png (picture n (st 2)) f (open (dir + "next.png") "w")
           _ (say f png) _ (close f)
           (puts ("B(" + show n + ") " + show #(b36 <(st 2)) + " chars, reply to " + st 1
                  + ", due through B(" + show (due 0) + "), caption " + show (caption n)
                  + ", next.png " + show #png + " bytes\n")))
       ("--init" . n . id . more)
        (: n (read n) at (more ? <more id) _ (file-write (dir + "state.l") ("'" + show [n id (row-at n)]))
           _ (file-write (dir + "config.l")
                         ("{'anchor-n " + show (n - 1) + " 'anchor-day " + show (id-day at)
                          + "\n 'scale 2 'fg 16777215 'bg 0 'text \"\"}\n"))
           (log ("init B(" + show n + ") reply to " + id)))
       ("--whoami" . _)
        (: r (call (secrets 0) "GET" "/2/users/me" ())
           (puts ((string? r ? r (show (r 0) + " " + r 1)) + "\n")))
       _ (step 0))
   (main >argv))
