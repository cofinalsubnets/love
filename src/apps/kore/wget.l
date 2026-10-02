; src/apps/kore/wget.l -- wget: one url to one file, over http or https.
;
;   wget [-q] [--no-check-certificate] [--allow-downgrade] [-O FILE] URL
;
; a GET with Connection: close, redirects followed (eight, then it stops, and never from
; https down to http without --allow-downgrade), a chunked body unchunked to its last chunk,
; the rest read to the peer's close and held to its Content-Length. https rides the tls module's
; client (src/apps/tls/client.l), which verifies the server's certificate to a root in the
; host's bundle (SSL_CERT_FILE names another) or to a pin in ~/.love/tls_pins, and a
; refusal says which check failed on which certificate. --no-check-certificate, as GNU's,
; skips that and says so unless -q. the file is -O, else the url's last path word, else
; index.html. the exit codes are wget's own: 0, 1 a bad url or a dead wire, 3 the file, 4 an
; answer cut short, 5 a certificate not believed, 8 a server that answered with an error status.
(module 'kore
(borrow 'path)
(borrow 'posix)

(:
   (wg-digits s)
    (: n #s
       (go i a) (? (n <= i) a
                   (: c (s i) (? (47 < c && c < 58) (go (i + 1) ((a * 10) + (c - 48))) a)))
       (go 0 0))
   (wg-lower s) (string (map (i \ (: c (s i) (? (64 < c && c < 91) (c + 32) c))) (jot #s)))
   ; what a peer said, fit for a terminal: the C0 controls but tab and newline, and DEL, out
   (wg-plain s) (string (filter (c \ !((c < 32 && c != 9 && c != 10) || c = 127)) (map (i \ s i) ^#s)))
   ; "https://host[:port]/path" -> (tls? host port path) | ()
   (wg-url u)
    (u @ ("https://" + r) (wg-url-at 1 r) ("http://" + r) (wg-url-at 0 r) ())
   (wg-url-at tls? r)
          (: ap (r @ (a + "/" + p) [a ("/" + p)] [r "/"])
             auth <ap path <>ap
             hp (auth @ (h + ":" + p) [h (wg-digits p)] [auth (tls? ? 443 80)])
             host <hp port <>hp
             (? (0 < #host && 0 < port) [tls? host port path] ()))
   ; a Location may be bare: a path on the same origin
   (wg-resolve base loc)
    (? (5 <= #loc && (snip loc 0 4) = "http") loc
       (: b (wg-url base)
          (? (atom? b) loc
             ((<b ? "https://" "http://") + (b 1) + ":" + show (b 2) + (loc 0 = 47 ? loc ("/" + loc))))))
   ; the header block's value for a name, lowercase both sides; () when absent
   (wg-header hd name)
    (: h (wg-lower hd) k (fsub h ("\r\n" + name + ":") 0)
       (? (k < 0) ()
          (: a (k + 3 + #name)
             e (fsub hd "\r\n" a)
             v (snip hd a (e < 0 ? #hd e))
             (: (trim s) (? (0 < #s && (s 0 = 32)) (trim (snip s 1 #s)) s) (trim v)))))
   ; a chunked body, unchunked: size line, data, crlf, until a zero size; () if it ends first
   (wg-unchunk b)
    (: j (jug 0)
       (go i) (: e (fsub b "\r\n" i)
                 (? (e < 0) 0
                    (: n (: (hexn s) (: (go2 k a) (? (k >= #s) a
                                                     (: c (s k)
                                                        (? (47 < c && c < 58) (go2 (k + 1) ((a * 16) + (c - 48)))
                                                           (96 < c && c < 103) (go2 (k + 1) ((a * 16) + (c - 87)))
                                                           (64 < c && c < 71) (go2 (k + 1) ((a * 16) + (c - 55)))
                                                           a)))
                                        (go2 0 0))
                            (hexn (snip b i e)))
                       (? (n = 0) 1
                          (#b < e + 2 + n) 0
                          (say j (snip b (e + 2) (e + 2 + n)), go (e + 4 + n))))))
       (? (go 0 = 1) (slurp j) ()))
   (wg-cut host why) ("the answer from " + host + " was cut short: " + why)
   ; one round trip -> (status headers body) | () | why a tls peer was not believed, or why
   ; its answer is cut short; more is header lines to add, each ending \r\n (www asks for
   ; gzip); how is tls-open's
   (wg-once tls? host port path) (wg-ask tls? host port path "")
   (wg-ask tls? host port path more) (wg-ask-how tls? host port path more 'verify)
   (wg-ask-how tls? host port path more how)
    (: req ("GET " + path + " HTTP/1.1\r\nHost: " + host + "\r\nUser-Agent: love-wget\r\nAccept: */*\r\n" + more + "Connection: close\r\n\r\n")
       raw (? tls?
              (: t (cite 'tls 'tls-open host port how)
                 (? (string? t) ['why t]
                    !(tablet? t) ()
                    (: _ (cite 'tls 'tls-say t req)
                       r (cite 'tls 'tls-slurp t)
                       _ (close (t 's))
                       (? (nom? r) ['why (wg-cut host (t 'why))] r))))
              (: s (cite 'dns 'dial host port)
                 (? !(hot? s) ()
                    (: _ (say s req) _ (flush s) r (slurp s) _ (close s) r))))
       (? (two? raw) (raw 1)                                   ; the tls refusal, said
          !(string? raw) ()
          (: k (fsub raw "\r\n\r\n" 0)
             (? (k < 0) ()
                (: head (snip raw 0 k)
                   body (snip raw (k + 4) #raw)
                   sp (fsub head " " 0)
                   code (? (sp < 0) 0 (wg-digits (snip head (sp + 1) (sp + 4))))
                   te (wg-header head "transfer-encoding")
                   cl (wg-header head "content-length") n (? (string? cl) (wg-digits cl) -1)
                   b (? (string? te && (wg-lower te) = "chunked") (wg-unchunk body)
                        (#body < n) () (0 <= n) (snip body 0 n) body)
                   (? (string? b) [code head b]
                      (wg-cut host (? (0 <= n) (show #body + " of " + show n + " bytes came")
                                      "the chunked body stops before its last chunk"))))))))
   (wg-fetch url hops quiet how down)
    (: u (wg-url url)
       (? (atom? u) [1 ("wget: not a url: " + url)]
          (: _ (? (<u && how = 'none && !quiet) (say err ("wget: not checking the certificate of " + (u 1) + "\n")) 0)
             r (wg-ask-how <u (u 1) (u 2) (u 3) "" how)
             (? (string? r) [(? (0 = fsub r "cannot connect" 0) 1 (0 = fsub r "the answer from" 0) 4 5) ("wget: " + r)]
                (atom? r) [1 ("wget: no answer from " + (u 1))]
                (: code <r
                   loc (wg-header (r 1) "location")
                   to (? (string? loc) (wg-resolve url loc) "")
                   (? (300 <= code && code < 400 && string? loc)
                      (? (hops < 1) [1 "wget: too many redirects"]
                         (<u && starts? to "http://" && !down)
                          [1 ("wget: " + url + " sends us to " + wg-plain to + ", down to plain http; --allow-downgrade follows it")]
                         ((? quiet 0 (say err ("wget: -> " + wg-plain loc + "\n"))), wg-fetch to (hops - 1) quiet how down))
                      (200 <= code && code < 300) [0 (r 2)]
                      [8 ("wget: " + (u 1) + " answered " + show code)]))))))
   (wg-name url)
    (: u (wg-url url)
       p (? (two? u) (u 3) "/")
       nm (pbase p)
       q (fsub nm "?" 0)
       nm2 (? (q < 0) nm (snip nm 0 q))
       (? (0 < #nm2) nm2 "index.html"))
   (wget-main as)
    (: (go a q o u k w) (? (atom? a) [q o u k w]
                           (<a = "-q") (go >a 1 o u k w)
                           (<a = "--no-check-certificate") (go >a q o u 'none w)
                           (<a = "--allow-downgrade") (go >a q o u k 1)
                           (<a = "-O" && two? >a) (go >>a q <>a u k w)
                           (<a = "-h" || <a = "--help") [q o () k w]
                           (go >a q o <a k w))
       r (go as () () () 'verify ())
       quiet <r dest <>r url (r 2) how (r 3) down (r 4)
       ; a seat with a page's network and no socket (inle under a browser, src/inle/wasm): the
       ; kernel's fetch door lays the file itself, whole, and -O - has no door there
       (? !(string? url) (say err "usage: wget [-q] [--no-check-certificate] [--allow-downgrade] [-O FILE] URL\n", 1)
          (elem 'fetch (names ()))
           (: nm (? (string? dest) dest (wg-name url))
              (? (nm = "-") (say err "wget: -O - is not a door on this machine\n", 3)
                 (: c (ev 'fetch url nm)
                    (? (charm? c && c = 0) (? quiet 0 (say err ("wget: fetched -> " + nm + "\n")), 0)
                       (say err ("wget: cannot fetch " + url + (charm? c ? (" (errno " + show (0 - c) + ")") "") + "\n"), 4)))))
          (: f (wg-fetch url 8 quiet how down)
             (? !(<f = 0) (say err (<>f + "\n"), <f)
                (: nm (? (string? dest) dest (wg-name url))
                   body <>f
                   ; -O - is stdout, which carries the body and nothing else: every word is err's
                   p (? (nm = "-") out (open nm "w"))
                   (? !(hot? p) (say err ("wget: cannot write " + nm + "\n"), 3)
                      (say p body, (? (nm = "-") (flush p) (close p)), (? quiet 0 (say err ("wget: " + show #body + " bytes -> " + nm + "\n"))), 0))))))))
) ; module kore
