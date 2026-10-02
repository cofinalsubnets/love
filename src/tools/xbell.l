; src/tools/xbell.l -- the daily bell thread on x: B(n) as a png, posted as
; a reply to the post before it. a timer runs it; a run posts one number, and
; only while the thread is behind the day (utc).
;   love src/tools/xbell.l [--dry-run | --init N ID [AT] | --whoami]
; --dry-run draws next.png; --init lays a state, never over one: next is B(N),
; replying to post ID, and B(N - 1) is due on post AT's day (else ID's);
; --whoami checks the keys (one paid read). $XBELL_DIR (~/.local/share/xbell)
; holds x.com.oauth.secret ($XBELL_KEYS; oauth 1.0a `name: value` lines),
; config.l, state.l (n reply-id row, the bell triangle's row n), next.png, log.
(borrow 'json)
(borrow 'bytes)
(borrow 'posix)
(:
   home (getenv "HOME" || "")
   dir ((getenv "XBELL_DIR" || (home + "/.local/share/xbell")) + "/")
   secret-path (getenv "XBELL_KEYS" || (dir + "x.com.oauth.secret"))
   api "api.x.com"

   ; files
   (file-read p)
    (: f (open p "r") (? !(hot? f) () (slurp f @ s (close f, s))))
   (file-write p s)
    (: t (p + ".new") f (open t "w") _ (say f s) _ (close f) (rename t p))
   (log s)
    (: f (open (dir + "log") "a")
       (say f (show (clock 0 // 1000) + " " + s + "\n"), close f))
   (die s) (log s, udie 1 ("xbell: " + s))
   (cfg k d) (: s (file-read (dir + "config.l")) (peep (s ? (read s) {}) k d))

   ; "name: value" lines, pinned into t
   (pairs t s) (foldl (t \ l \ (l @ (k + ": " + v) (pin t k (trim v)) t))
                      t (split "\n" (s || "")))
   (secrets _)
    (: s (file-read secret-path)
       (? !s (die ("cannot read " + secret-path)) (pairs {} s)))
   (trim s) (: (go a b) (b > a && s (b - 1) <= 32 ? (go a (b - 1)) (snip s a b))
               (go 0 #s))
   (dec s) (foldl (a \ c \ a * 10 + c - 48) 0 (chars s))       ; "08" is 8

   ; bell
   (row-next r)
    (: (go r a acc) (r ? (go >r (a + <r) (a . acc)) (rev (a . acc)))
       (go r (r (#r - 1)) ()))
   (row-at n) (: (go k r) (k = n ? r (go (k + 1) (row-next r))) (go 0 [1]))
   digits "0123456789abcdefghijklmnopqrstuvwxyz"
   (b36 n) (: (go n acc) (n < 36 ? (string (digits n) + acc)
                              (go (n // 36) (string (digits (n % 36)) + acc)))
              (go n ""))

   ; drawing. the console's terminus 8x16, read back once through the painter:
   ; glyph c -> 16 row bytes
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
       chunk (foldl (t \ v \ pin t v (foldl (a \ x \ a + dot (v >> (7 - x) & 1))
                                            "" ^8))
                    {} ^256)
       W ((cols + 2) * 8 * scale) H ((rows + 2) * 16 * scale)
       blank (foldl (a \ _ \ a + B) "" ^W)
       pad (foldl (a \ _ \ a + B) "" ^(8 * scale))
       j (jug 0)
       (line y) (foldl (a \ _ \ (say j a, a)) y ^scale)
       (glyphrow t y) (foldl (a \ c \ a + chunk (glyphs c y)) "" (chars t))
       _ (each ^(16 * scale) (_ \ say j blank))
       (pixrow t y) (pad + glyphrow t y + pad + rep blank (cols - #t) scale)
       _ (each ^rows (r \ (: t (snip s (r * cols) (min #s (r * cols + cols)))
                          (each ^16 (y \ line (pixrow t y))))))
       _ (each ^(16 * scale) (_ \ say j blank))
       (cite 'png 'png-encode W H (slurp j)))
   ; blank pixels for a short last line
   (rep blank k scale) (snip blank 0 (k * 8 * scale * 4))

   ; base 256 on a fixed cols x rows terminal: a byte a pixel, two pixels a cell
   ; (a half block, its top the foreground). the top byte sits in the bottom
   ; right corner and the rest fill each pixel row right to left, rows rising,
   ; so the number piles up like sand; black above it is not written yet
   (b256 n) (: (go n acc) (n < 256 ? (n . acc)
                              (go (n // 256) ((n % 256) . acc)))
               (go n ()))
   esc (string 27)
   upper (string [226 150 128])                  ; u+2580, the upper half block
   ; a byte's colour: matplotlib's magma with 0 pure black, each step brighter
   ; than the last (relative luminance) and all 256 distinct, so it reads back
   magma (cats [
    "00000001000501010601010802010902020b02020d03030f030312040414050416060518"
    "06051a07061c08071e0907200a08220b09240c09260d0a290e0b2b100b2d110c2f120d31"
    "130d34140e36150e38160f3b180f3d19103f1a10421c10441d11471e114920114b21114e"
    "22115024125325125527125829115a2a115c2c115f2d11612f1163311165331067341069"
    "36106b38106c390f6e3b0f703d0f713f0f72400f74420f75440f76451077471078491078"
    "4a10794c117a4e117b4f127b51127c52137c54137d56147d57157e59157e5a167e5c167f"
    "5d177f5f187f601880621980641a80651a80671b80681c816a1c816b1d816d1d816e1e81"
    "701f81721f817320817521817621817822817922827b23827c23827e2482802582812581"
    "8326818426818627818827818928818b29818c29818e2a81902a81912b81932b80942c80"
    "962c80982d80992d809b2e7f9c2e7f9e2f7fa02f7fa1307ea3307ea5317ea6317da8327d"
    "aa337dab337cad347cae347bb0357bb2357bb3367ab5367ab73779b83779ba3878bc3978"
    "bd3977bf3a77c03a76c23b75c43c75c53c74c73d73c83e73ca3e72cc3f71cd4071cf4070"
    "d0416fd2426fd3436ed5446dd6456cd8456cd9466bdb476adc4869de4968df4a68e04c67"
    "e24d66e34e65e44f64e55064e75263e85362e95462ea5661eb5760ec5860ed5a5fee5b5e"
    "ef5d5ef05f5ef1605df2625df2645cf3655cf4675cf4695cf56b5cf66c5cf66e5cf7705c"
    "f7725cf8745cf8765cf9785df9795df97b5dfa7d5efa7f5efa815ffb835ffb8560fb8761"
    "fc8961fc8a62fc8c63fc8e64fc9065fd9266fd9467fd9668fd9869fd9a6afd9b6bfe9d6c"
    "fe9f6dfea16efea36ffea571fea772fea973feaa74feac76feae77feb078feb27afeb47b"
    "feb67cfeb77efeb97ffebb81febd82febf84fec185fec287fec488fec68afec88cfeca8d"
    "fecc8ffecd90fecf92fed194fed395fed597fed799fed89afdda9cfddc9efddea0fde0a1"
    "fde2a3fde3a5fde5a7fde7a9fde9aafdebacfcecaefceeb0fcf0b2fcf2b4fcf4b6fcf6b8"
    "fcf7b9fcf9bbfcfbbdfcfdbf"])
   sgr (map (v \ (: c (hex2b (snip magma (6 * v) (6 * v + 6)))
                    (show (c 0) + ";" + show (c 1) + ";" + show (c 2)))) ^256)
   (cells n cols rows scale)
    (: bs (b256 n) H (rows * 2) k (cols * H - #bs)
       _ (k < 0 ? (die ("B(n) outgrew the window: " + show #bs + " bytes")))
       bs (string (bs + map (_ \ 0) ^k))
       (pix y x) (bs ((H - 1 - y) * cols + cols - 1 - x))
       (cell r c) (esc + "[38;2;" + sgr (pix (2 * r) c) + "m"
                   + esc + "[48;2;" + sgr (pix (2 * r + 1) c) + "m" + upper)
       scr (screen (cask (screen () rows cols)) rows cols)
       _ (each ^rows (r \ (scribe scr $ esc + "[" + show (r + 1) + ";1H",
                           each ^cols $ c \ scribe scr (cell r c))))
       w (cols * 8) h (rows * 16)
       buf (cask (w * h * 4))
       _ (each ^rows (r \ dye scr buf w r -1 ()))
       ; xrgb words to rgba bytes, each pixel scale times across and down
       (px i) (string [(peep buf (i + 2) 0) (peep buf (i + 1) 0)
                       (peep buf i 0) 255])
       (wide x y) (rep2 (px (4 * (y * w + x))) scale)
       j (jug 0)
       _ (each ^h (y \ (: jl (jug 0)
                          _ (each ^w (x \ say jl (wide x y)))
                          l (slurp jl)
                          (each ^scale (_ \ say j l)))))
       (cite 'png 'png-encode (w * scale) (h * scale) (slurp j)))
   (rep2 q k) (foldl (a \ _ \ a + q) "" ^k)

   ; oauth 1.0a
   alnum "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
   unreserved (alnum + "-._~")
   hexd "0123456789ABCDEF"
   (pct s) (foldl (a \ i \ (s i @ c (a + (elem c unreserved ? (string c)
                                         ("%" + string (hexd (c >> 4))
                                          + string (hexd (c & 15)))))))
                  "" ^#s)
   (hmac-sha1 k m)
    (: kp (#k > 64 ? (hex2b (sha1 k)) k)
       kp (kp + zbytes (64 - #kp))
       (pad b) (string (map (i \ kp i ^ b) ^64))
       (hex2b (sha1 (pad 92 + hex2b (sha1 (pad 54 + m))))))
   b64set (alnum + "+/")
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
   (nonce _) (: f (open "/dev/urandom" "r") b (string (map (_ \ see f) ^16))
                (close f, b2hex b))
   ; the pairs go in sorted, as the signature's base string wants them
   (authz ks meth url)
    (: ps [["oauth_consumer_key" (key ks "api key" "consumer key")]
           ["oauth_nonce" (nonce 0)] ["oauth_signature_method" "HMAC-SHA1"]
           ["oauth_timestamp" (show (clock 0 // 1000))]
           ["oauth_token" (ks "access token")] ["oauth_version" "1.0"]]
       q (join "&" (map (p \ p 0 + "=" + pct (p 1)) ps))
       base (meth + "&" + pct url + "&" + pct q)
       sk (pct (key ks "api key secret" "consumer key secret") + "&"
           + pct (ks "access token secret"))
       sig (b64 (hmac-sha1 sk base))
       ("OAuth " + join ", " (map (p \ p 0 + "=\"" + pct (p 1) + "\"")
                                (ps + [["oauth_signature" sig]]))))
   (key ks a b) (ks a || ks b)               ; the portal says api or consumer
   (join sep l) (l ? (foldl (a \ x \ a + sep + x) <l >l) "")

   ; https -> [status body] | a string saying why not
   (call ks meth path body)
    (: t (cite 'tls 'tls-open api 443 'verify)
       (? (string? t) ("tls: " + t)
          (: auth (authz ks meth ("https://" + api + path))
             len (body ? ("Content-Type: application/json\r\nContent-Length: "
                          + show #body + "\r\n")
                    (meth = "POST" ? "Content-Length: 0\r\n" ""))
             req (meth + " " + path + " HTTP/1.1\r\nHost: " + api
                  + "\r\nAuthorization: " + auth
                  + "\r\nUser-Agent: xbell\r\nConnection: close\r\n"
                  + len + "\r\n" + (body || ""))
             _ (cite 'tls 'tls-say t req)
             (answer (cite 'tls 'tls-slurp t)))))
   ; a raw http answer -> [status body], the body unchunked
   (answer r)
    (r @ (head + "\r\n\r\n" + b)
       [(dec (snip head 9 12))
        (lower head @ (_ + "transfer-encoding: chunked" + _) (unchunk b) b)]
       "no answer")
   (lower s) (string (map (i \ s i @ c (64 < c < 91 ? (c + 32) c)) ^#s))
   (unchunk b)
    (: j (jug 0)
       (go s) (s @ (sz + "\r\n" + t)
                 (: n (read ("0x" + sz))
                    (n > 0 ? (say j (snip t 0 n), go (snip t (n + 2) #t)))))
       (go b, slurp j))
   ; the json answer's data.id, or die with what the server said
   (id-of what r)
    (? (string? r) (die (what + ": " + r))
       (: v (json-read (r 1)) d (two? v && v 0 ? (peep (v 1) "data" {}) {})
          (? ((r 0 = 200 || r 0 = 201) && d "id") (d "id")
             (die (what + ": " + show (r 0) + " " + r 1)))))

   (upload ks png)
    (id-of "upload" (call ks "POST" "/2/media/upload"
                          (json-show {"media" (b64 png)
                                      "media_category" "tweet_image"})))
   ; alt text on the image; a refusal is logged and the post goes on without it
   (alt ks media n)
    (: text (fill (cfg 'alt "B({n})") n)
       r (call ks "POST" "/2/media/metadata"
               (json-show {"id" media "metadata" {"alt_text" {"text" text}}}))
       ((string? r || r 0 != 200)
        && log ("alt: " + (string? r ? r (show (r 0) + " " + r 1)))))
   (tweet ks text reply media)
    (id-of "post" (call ks "POST" "/2/tweets"
                        (json-show {"text" text
                                    "reply" {"in_reply_to_tweet_id" reply}
                                    "media" {"media_ids" [media]}})))

   ; days. "yyyy-mm-dd" -> days since 1970-01-01 (hinnant's days_from_civil)
   (day-of s)
    (s @ (ys + "-" + ms + "-" + ds)
       (: m (dec ms) y (dec ys - (m <= 2 ? 1 0))
          era (y // 400) yoe (y - era * 400)
          doy ((153 * (m > 2 ? (m - 3) (m + 9)) + 2) // 5 + dec ds - 1)
          (era * 146097 + yoe * 365 + yoe // 4 - yoe // 100 + doy - 719468))
       (die ("not a day: " + s)))
   (today _) (clock 0 // 86400000)
   ; the index the thread should have reached today, from config's anchor
   (due _) (: a (cfg 'anchor-day 0)
              (cfg 'anchor-n 0 + today 0 - (string? a ? (day-of a) a)))
   ; a post id's day: the id's top bits are ms since twitter's epoch
   (id-day id) (((read id >> 22) + 1288834974657) // 86400000)

   ; the run
   (state _) (file-read (dir + "state.l") @ s (s && read s))
   (picture n row)
    ((n >= cfg 'wide-from 1000000000)
     ? (cells <row (cfg 'wide-cols 36) (cfg 'wide-rows 32) (cfg 'wide-scale 2))
       (draw (b36 <row) (cfg 'cols 0 || squarish #(b36 <row))
             (cfg 'scale 2) (cfg 'fg 16777215) (cfg 'bg 0)))
   ; columns for k characters that make the block about square (cells are 1:2)
   (squarish k) (max 16 (int ((1 / 2) (2 * k)) + 1))
   ; f with each {n} spelled as n
   (fill f n) (f @ (x + "{n}" + y) (x + show n + fill y n) f)
   (caption n) (fill (cfg 'text "") n)
   (step _)
    (: st (state 0)
       _ (? !st (die "no state; run --init N ID first"))
       n (st 0) reply (st 1) row (st 2)
       (? (n > due 0) 0
          (: ks (secrets 0)
             media (upload ks (picture n row))
             _ (alt ks media n)
             id (tweet ks (caption n) reply media)
             _ (file-write (dir + "state.l")
                           ("'" + show [(n + 1) id (row-next row)]))
             (log ("posted B(" + show n + ") as " + id)))))
   (main a)
    (a @
       ("--dry-run" . _)
        (: st (state 0) n (st 0) png (picture n (st 2))
           f (open (dir + "next.png") "w")
           _ (say f png) _ (close f)
           (puts ("B(" + show n + ") " + show #(b36 <(st 2))
                  + " chars, reply to " + st 1 + ", due through B("
                  + show (due 0) + "), caption " + show (caption n)
                  + ", next.png " + show #png + " bytes\n")))
       ("--init" . n . id . more)
        (: _ (? (file-read (dir + "state.l"))
                (die "state.l is there already; move it aside to start again"))
           n (read n) at (more ? <more id)
           _ (file-write (dir + "state.l") ("'" + show [n id (row-at n)]))
           _ (file-write (dir + "config.l")
                         ("{'anchor-n " + show (n - 1) + " 'anchor-day "
                          + show (id-day at)
                          + "\n 'scale 2 'fg 16777215 'bg 0 'text \"\"}\n"))
           (log ("init B(" + show n + ") reply to " + id)))
       ("--whoami" . _)
        (: r (call (secrets 0) "GET" "/2/users/me" ())
           (puts ((string? r ? r (show (r 0) + " " + r 1)) + "\n")))
       _ (step 0))
   (main >argv))
