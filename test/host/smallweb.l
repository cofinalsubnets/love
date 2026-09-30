; --- test/host/smallweb.l: www's gopher and gemini ---------------------------------------
; gopher against a hole served by a love process: a menu's text lines laid as they are and
; its items as links with their kinds, a text item's dots, a search answered. gemini, where
; python3 and openssl are here, against a tls server of python's that also asks for a client
; certificate (an empty one goes back): a text/gemini page's every kind of line, plain text,
; an ask for input and its answer, a redirect, a refusal, and the pinned certificate held to
; -- a new one refused until its line goes. www runs with HOME in out/, so the pins it
; writes are the test's own.
;   cat test/00-init.l test/host/smallweb.l | out/love
(borrow 'posix)
(: K (cite 'kore)
   love <cmdline
   dir ((cwd 0) + "/out/.smallweb-" + show (getpid 0))
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 448)
   home0 (getenv "HOME")
   _ (setenv "HOME" dir)
   (has? t s) (0 <= (K 'wg-find) t s 0)
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (rest 2, waitfor pid)))
   (put p s) (: q (open p "w") _ (say q s) (close q))
   ; www on a pipe, where it pours the page and its references (on a pty it would wait for
   ; keys); its complaints are stderr, so they ride along
   (www u) (: r (hark ["sh" "-c" (love + " kore www '" + u + "' 2>&1")]) [(? (two? r) >r "") <r])

   ; -- gopher ---------------------------------------------------------------------------
   gp (test-free 0)
   gs (show gp)
   _ (put (dir + "/hole.l") ("(borrow 'posix)
(: l (listen " + gs + ") _ (close (open \"" + dir + "/hole.up\" \"w\"))
   (ln x) (x + \"\\r\\n\")
   menu (ln \"iWelcome to the test hole\\tfake\\t(NULL)\\t0\" + ln \"i  ascii   art\\tfake\\t(NULL)\\t0\"
         + ln \"0About this hole\\t/about\\t127.0.0.1\\t" + gs + "\" + ln \"1A deeper menu\\t/deep\\t127.0.0.1\\t" + gs + "\"
         + ln \"7Search here\\t/find\\t127.0.0.1\\t" + gs + "\" + ln \"hA web page\\tURL:https://example.org/\\t127.0.0.1\\t" + gs + "\"
         + ln \"3oops, an error line\\t\\terror.host\\t1\" + ln \".\")
   (line c a) (: b (see c) (? ((b < 0) || (b = 10)) a (line c (a + string b))))
   (answer sel) (? (sel = \"\") menu (sel = \"/about\") \"Line one\\r\\n..dotted\\r\\n.\\r\\n\"
                   (sel = \"/find\\tlove kore\") (ln \"iyou searched for love kore\\t\\t\\t0\" + ln \".\")
                   (ln \"3no such selector\\t\\t\\t0\" + ln \".\"))
   (serve k) (? (k < 1) 0 (: c (accept l) s (line c \"\") sel (? ((0 < #s) && (s (#s - 1) = 13)) (snip s 0 (#s - 1)) s)
                             _ (say c (answer sel)) _ (flush c) _ (close c) (serve (k - 1))))
   _ (serve 3)
   0)
"))
   srv (tether [love (dir + "/hole.l")])
   _ (test-until (\ s !(two? s)) (\ _ (stat (dir + "/hole.up"))))   ; it listens: it takes three, so no probe
   m (www ("gopher://127.0.0.1:" + gs + "/"))
   a (www ("gopher://127.0.0.1:" + gs + "/0/about"))
   f (www ("gopher://127.0.0.1:" + gs + "/7/find?search=love+kore"))
   _ (waitfor <srv)
   _ (test (has? <m "Welcome to the test hole") (has? <m "  ascii   art")
           (has? <m "(TXT) [1]About this hole") (has? <m "(DIR) [2]A deeper menu")
           (has? <m "(?) [3]Search here") (has? <m "(HTML) [4]A web page") (has? <m "oops, an error line")
           (has? <m ("gopher://127.0.0.1:" + gs + "/0/about")) (has? <m ("form:gopher://127.0.0.1:" + gs + "/7/find?search="))
           (has? <m "https://example.org/") (m 1 = 0)
           (has? <a "Line one") (has? <a ".dotted") !(has? <a "..dotted") (a 1 = 0)
           (has? <f "you searched for love kore"))

   ; -- gemini ---------------------------------------------------------------------------
   py? (: q (open "/usr/bin/python3" "r") (? (hot? q) (close q, 1) 0))
   ssl? (: q (open "/usr/bin/openssl" "r") (? (hot? q) (close q, 1) 0))
   gm (test-free 0)
   ms (show gm)
   base ("gemini://127.0.0.1:" + ms)
   (cert nm) (hark ["sh" "-c" ("openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout " + dir + "/"
                               + nm + ".key -out " + dir + "/" + nm + ".pem -days 2 -subj /CN=127.0.0.1 2>/dev/null")])
   _ (put (dir + "/gem.py") ("import socket, ssl, sys
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ssl.TLSVersion.TLSv1_3
ctx.load_cert_chain(sys.argv[2] + '.pem', sys.argv[2] + '.key')
ctx.load_verify_locations(sys.argv[2] + '.pem')
ctx.verify_mode = ssl.CERT_OPTIONAL
page = '# Title\\n## Sub\\n* one\\n* two\\n> quoted\\n```alt\\n  pre  formatted\\n```\\n=> /doc A doc\\n=> gemini://elsewhere.example/ Far\\nplain line\\n'
routes = {'/': '20 text/gemini\\r\\n' + page, '/doc': '20 text/plain\\r\\nplain doc\\n',
          '/in': '10 Your name?\\r\\n', '/in?x%20y': '20 text/gemini\\r\\nhello x y\\n',
          '/go': '31 /doc\\r\\n', '/gone': '51 Not found\\r\\n'}
srv = socket.create_server(('127.0.0.1', int(sys.argv[1])))
open(sys.argv[2] + '.up', 'w').close()
for _ in range(int(sys.argv[3])):
    c, _a = srv.accept()
    try:
        s = ctx.wrap_socket(c, server_side=True)
        req = b''
        while not req.endswith(b'\\r\\n'):
            b = s.recv(1)
            if not b: break
            req += b
        path = req.decode().strip().split('" + ms + "', 1)[-1] or '/'
        s.sendall(routes.get(path, '51 no route ' + path + '\\r\\n').encode())
        s.close()
    except Exception as e:
        print('server:', e, flush=True)
"))
   (serve nm n) (tether ["python3" (dir + "/gem.py") ms (dir + "/" + nm) (show n)])
   _ (? (py? && ssl?)
        (: _ (cert "one") _ (cert "two")
           s1 (serve "one" 8)
           _ (test-until (\ s !(two? s)) (\ _ (stat (dir + "/one.up"))))
           g (www (base + "/"))
           d (www (base + "/doc"))
           i (www (base + "/in"))
           x (www (base + "/in?input=x+y"))
           r (www (base + "/go"))
           e (www (base + "/gone"))
           _ (still <s1 15) _ (waitfor <s1)
           pins (: q (open (dir + "/.love/gemini_hosts") "r") (? (hot? q) (: s (slurp q) _ (close q) s) ""))
           ; the same host with another certificate: refused, and taken once its line is gone
           s2 (serve "two" 2)
           _ (test-until (\ s !(two? s)) (\ _ (stat (dir + "/two.up"))))
           c (www (base + "/doc"))
           _ (hark ["rm" "-f" (dir + "/.love/gemini_hosts")])
           c2 (www (base + "/doc"))
           _ (still <s2 15) _ (waitfor <s2)
           (test (has? <g "Title") (has? <g "Sub") (has? <g "one") (has? <g "two") (has? <g "quoted")
                 (has? <g "  pre  formatted") (has? <g "[1]A doc") (has? <g (base + "/doc"))
                 (has? <g "gemini://elsewhere.example/") (has? <g "plain line") (g 1 = 0)
                 (has? <d "plain doc") (has? <i "Your name?") (has? <i ("form:" + base + "/in?input="))
                 (has? <x "hello x y") (has? <r "plain doc") (has? <e "51 Not found") !(e 1 = 0)
                 (has? pins ("127.0.0.1:" + ms + " "))
                 (has? <c "has changed") !(c 1 = 0) (has? <c2 "plain doc")))
        0)
   _ (setenv "HOME" home0)
   _ (hark ["rm" "-rf" dir])
   0)

(test_fin (), puts "smallweb: ok", putc 10, 0)
