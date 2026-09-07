; apps/kore/wget.l -- wget: one url to one file, over http or https.
;
;   wget [-q] [-O FILE] URL
;
; a GET with Connection: close, redirects followed (eight, then it stops), a chunked
; body unchunked, the rest read to the peer's close. https rides the tls module's
; client (apps/tls/client.l) -- ⚠ which does not verify the peer, and says so once
; per fetch unless -q. the file is -O, else the url's last path word, else index.html.
; the exit codes are wget's own: 0, 1 a bad url or a dead wire, 3 the file, 8 a server
; that answered with an error status.
(module 'kore
(:
   (wg-digits s)
    (: n #s
       (go i a) (? (n <= i) a
                   (: c (s i) (? ((47 < c) && (c < 58)) (go (i + 1) ((a * 10) + (c - 48))) a)))
       (go 0 0))
   (wg-find s sub from)                                                ; first index of sub at/after from, else -1
    (: n #s m #sub
       (go i) (? ((n - m) < i) -1 ((snip s i (i + m)) = sub) i (go (i + 1)))
       (go from))
   (wg-lower s) (string (map (\ i (: c (s i) (? ((64 < c) && (c < 91)) (c + 32) c))) (jot #s)))
   ; "https://host[:port]/path" -> (tls? host port path) | ()
   (wg-url u)
    (: tls? ((8 <= #u) && ((snip u 0 8) = "https://"))
       plain? ((7 <= #u) && ((snip u 0 7) = "http://"))
       (? (!tls? && !plain?) ()
          (: r (snip u (tls? ? 8 7) #u) m #r
             k (: (sl i) (? (m <= i) m (r i = 47) i (sl (i + 1))) (sl 0))
             auth (snip r 0 k)
             path (? (k < m) (snip r k m) "/")
             c (: a #auth (cn i) (? (a <= i) -1 (auth i = 58) i (cn (i + 1))) (cn 0))
             host (? (c < 0) auth (snip auth 0 c))
             port (? (c < 0) (tls? ? 443 80) (wg-digits (snip auth (c + 1) #auth)))
             (? ((0 < #host) && (0 < port)) [tls? host port path] ()))))
   ; a Location may be bare: a path on the same origin
   (wg-resolve base loc)
    (? ((5 <= #loc) && ((snip loc 0 4) = "http")) loc
       (: b (wg-url base)
          (? !(two? b) loc
             ((<b ? "https://" "http://") + (b 1) + ":" + show (b 2) + (loc 0 = 47 ? loc ("/" + loc))))))
   ; the header block's value for a name, lowercase both sides; () when absent
   (wg-header hd name)
    (: h (wg-lower hd) k (wg-find h ("\r\n" + name + ":") 0)
       (? (k < 0) ()
          (: a (k + 3 + #name)
             e (wg-find hd "\r\n" a)
             v (snip hd a (e < 0 ? #hd e))
             (: (trim s) (? ((0 < #s) && (s 0 = 32)) (trim (snip s 1 #s)) s) (trim v)))))
   ; a chunked body, unchunked: size line, data, crlf, until a zero size
   (wg-unchunk b)
    (: j (jug 0)
       (go i) (: e (wg-find b "\r\n" i)
                 (? (e < 0) 0
                    (: n (: (hexn s) (: (go2 k a) (? (k >= #s) a
                                                     (: c (s k)
                                                        (? ((47 < c) && (c < 58)) (go2 (k + 1) ((a * 16) + (c - 48)))
                                                           ((96 < c) && (c < 103)) (go2 (k + 1) ((a * 16) + (c - 87)))
                                                           ((64 < c) && (c < 71)) (go2 (k + 1) ((a * 16) + (c - 55)))
                                                           a)))
                                        (go2 0 0))
                            (hexn (snip b i e)))
                       (? (n = 0) 0
                          (: _ (say j (snip b (e + 2) (e + 2 + n)))
                             (go (e + 4 + n)))))))
       _ (go 0)
       (slurp j))
   ; one round trip -> (status headers body) | ()
   (wg-once tls? host port path)
    (: req ("GET " + path + " HTTP/1.1\r\nHost: " + host + "\r\nUser-Agent: love-wget\r\nAccept: */*\r\nConnection: close\r\n\r\n")
       raw (? tls?
              (: t ((from 'tls 'tls-dial) host port)
                 (? !(tablet? t) ()
                    (: _ ((from 'tls 'tls-say) t req)
                       r ((from 'tls 'tls-slurp) t)
                       _ (close (t 's))
                       r)))
              (: s ((from 'dns 'dial) host port)
                 (? !(hot? s) ()
                    (: _ (say s req) _ (flush s) r (slurp s) _ (close s) r))))
       (? !(string? raw) ()
          (: k (wg-find raw "\r\n\r\n" 0)
             (? (k < 0) ()
                (: head (snip raw 0 k)
                   body (snip raw (k + 4) #raw)
                   sp (wg-find head " " 0)
                   code (? (sp < 0) 0 (wg-digits (snip head (sp + 1) (sp + 4))))
                   te (wg-header head "transfer-encoding")
                   [code head (? ((string? te) && ((wg-lower te) = "chunked")) (wg-unchunk body) body)])))))
   (wg-fetch url hops quiet)
    (: u (wg-url url)
       (? !(two? u) [1 ("wget: not a url: " + url)]
          (: _ (? (<u && !quiet) (say err "wget: the peer is not verified\n") 0)
             r (wg-once <u (u 1) (u 2) (u 3))
             (? !(two? r) [1 ("wget: no answer from " + (u 1))]
                (: code <r
                   loc (wg-header (r 1) "location")
                   (? ((300 <= code) && (code < 400) && (string? loc))
                      (? (hops < 1) [1 "wget: too many redirects"]
                         (: _ (? quiet 0 (say err ("wget: -> " + loc + "\n")))
                            (wg-fetch (wg-resolve url loc) (hops - 1) quiet)))
                      ((200 <= code) && (code < 300)) [0 (r 2)]
                      [8 ("wget: " + (u 1) + " answered " + show code)]))))))
   (wg-name url)
    (: u (wg-url url)
       p (? (two? u) (u 3) "/")
       k (: (go i) (? (i < 0) -1 (p i = 47) i (go (i - 1))) (go (#p - 1)))
       nm (snip p (k + 1) #p)
       q (wg-find nm "?" 0)
       nm2 (? (q < 0) nm (snip nm 0 q))
       (? (0 < #nm2) nm2 "index.html"))
   (wget-main as)
    (: (go a q o u) (? !(two? a) [q o u]
                       (<a = "-q") (go >a 1 o u)
                       ((<a = "-O") && (two? >a)) (go >>a q <>a u)
                       ((<a = "-h") || (<a = "--help")) [q o ()]
                       (go >a q o <a))
       r (go as () () ())
       quiet <r out <>r url (r 2)
       (? !(string? url) (say err "usage: wget [-q] [-O FILE] URL\n", 1)
          (: f (wg-fetch url 8 quiet)
             (? !(<f = 0) (say err (<>f + "\n"), <f)
                (: nm (? (string? out) out (wg-name url))
                   body <>f
                   p (? (nm = "-") out (open nm "w"))
                   (? !(hot? p) (say err ("wget: cannot write " + nm + "\n"), 3)
                      (: _ (say p body)
                         _ (? (nm = "-") (flush p) (close p))
                         _ (? quiet 0 (say err ("wget: " + show #body + " bytes -> " + nm + "\n")))
                         0))))))))
) ; module kore
