; test/host/pack.l -- directory packs: a pack's verbs run, its files read in the order their
; modules need, a library pack's module borrowed from a script and from another pack, the
; table winning over a pack, and LOVE_NEST naming the nest.
;   cat test/00-init.l test/host/pack.l | out/love
(borrow 'posix)
(: love (cwd 0 + "/out/love")
   home (cwd 0 + "/out/.packtest-" + show (getpid 0))
   dir (home + "/.love/pack")
   _ (hark ["rm" "-rf" home], hark ["mkdir" "-p" dir])
   (put p s) (open p "w" @ q (say q s, close q))
   (mkpack n fs) (mkdir (dir + "/" + n) 448,
                  each fs (f \ put (dir + "/" + n + "/" + <f) <>f))
   ; one line, stderr folded in, with home as HOME
   (run as) (hark ["sh" "-c" ("HOME=" + home + " " + love + " " + as + " 2>&1")])

   ; a.l borrows z.l's module and calls it as it loads, so z.l must be read first; z.l
   ; borrows a library from another pack
   _ (mkpack "hello"
       [["a.l" "(module '(hello hello-main)\n(borrow 'hellolib)\n(: msg (greeting \"there\")\n   (hello-main as) (puts (two? as ? (greeting <as) msg), putc 10, flush out, 0))\n(cite 'verbs 'enlist 'hello (as \\ (hello-main as)) ())\n) ; module hello\n"]
        ["z.l" "(module '(hellolib greeting)\n(borrow 'words)\n(: (greeting w) (hi + w))\n) ; module hellolib\n"]
        ["notes.txt" "not read\n"]])
   ; a library: no verb, one module
   _ (mkpack "words" [["words.l" "(module '(words hi)\n(: hi \"hi \")\n) ; module words\n"]])
   ; a verb of its own, and one the table already has: the table's stays
   _ (mkpack "greet"
       [["greet.l" "(cite 'verbs 'enlist 'greet (as \\ (puts \"greet\\n\", flush out, 0)) ())\n(cite 'verbs 'enlist 'verbs (as \\ (puts \"pack's verbs\\n\", flush out, 0)) ())\n"]])
   _ (put (dir + "/stray.l") "a file is no pack\n")

   r1 (run "hello")
   r2 (run "hello you")
   r3 (run "greet")
   r4 (run "verbs")
   r5 (run "-e \"(: f (cite 'verbs 'get 'verbs) _ (cite 'verbs 'call 'greet ()) (putx (f == cite 'verbs 'get 'verbs)))\"")
   r6 (run "-e \"(borrow 'words) (putx hi)\"")
   r7 (run "pack --list")
   r8 (hark ["sh" "-c" ("HOME=" + home + "/none " + love + " pack 2>&1")])
   ; LOVE_NEST names the nest, HOME aside
   r9 (hark ["sh" "-c" ("HOME=/nonexistent LOVE_NEST=" + home + "/.love " + love + " hello nest 2>&1")])
   _ (test (<r1 = 0) (>r1 = "hi there\n")
           (<r2 = 0) (>r2 = "hi you\n")
           (<r3 = 0) (>r3 = "greet\n")
           (<r4 = 0) !(has? >r4 "pack's verbs") (has? >r4 "verbs")
           (has? >r5 "1")
           (<r6 = 0) (has? >r6 "\"hi \"")
           (<r7 = 0)
           (>r7 = "greet greet verbs (the table wins)\nhello hello (modules hello hellolib)\nwords (modules words)\n")
           (<r8 = 0) (>r8 = ("pack: none under " + home + "/none/.love/pack\n"))
           (<r9 = 0) (>r9 = "hi nest\n"))
   (hark ["rm" "-rf" home]))
(test_fin (), puts "pack: ok", putc 10, 0)
