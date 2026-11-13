; test/host/pack.l -- directory packs, keyed by folder name: a pack's verb runs, its files read
; in name order, a library pack's module borrowed from a script and from another pack, the
; table winning over a pack, and the nest's rule: LOVE_NEST, else XDG_DATA_HOME/love, else
; HOME/.love, /.love with no HOME, an empty one as unset, and the nest exported to a child.
;   cat test/00-init.l test/host/pack.l | out/love
(borrow 'posix)
(: love (cwd 0 + "/out/love")
   home (cwd 0 + "/out/.packtest-" + show (getpid 0))
   dir (home + "/.love/pack")
   _ (hark ["rm" "-rf" home], hark ["mkdir" "-p" dir])
   (put p s) (open p "w" @ q (say q s, close q))
   (mkpack n fs) (mkdir (dir + "/" + n) 448,
                  each fs (f \ put (dir + "/" + n + "/" + <f) <>f))
   ; one line, stderr folded in, with home's nest as the nest
   (in-env e as) (hark ["sh" "-c" (e + " " + love + " " + as + " 2>&1")])
   (run as) (in-env ("LOVE_NEST=" + home + "/.love") as)

   ; b.l borrows a.l's module and calls it as it loads, read after it by name; a.l borrows
   ; a library from another pack
   _ (mkpack "hello"
       [["b.l" "(module '(hello hello-main)\n(borrow 'hellolib)\n(: msg (greeting \"there\")\n   (hello-main as) (puts (two? as ? (greeting <as) msg), putc 10, flush out, 0))\n(cite 'verbs 'enlist 'hello (as \\ (hello-main as)) ())\n) ; module hello\n"]
        ["a.l" "(module '(hellolib greeting)\n(borrow 'words)\n(: (greeting w) (hi + w))\n) ; module hellolib\n"]
        ["notes.txt" "not read\n"]])
   ; a library: no verb, one module
   _ (mkpack "words" [["words.l" "(module '(words hi)\n(: hi \"hi \")\n) ; module words\n"]])
   ; a verb of its own, and one the table already has: the table's stays
   _ (mkpack "wave"
       [["wave.l" "(cite 'verbs 'enlist 'wave (as \\ (puts \"wave\\n\", flush out, 0)) ())\n(cite 'verbs 'enlist 'verbs (as \\ (puts \"pack's verbs\\n\", flush out, 0)) ())\n"]])
   ; a pack under a name the table answers is never read
   _ (mkpack "verbs" [["verbs.l" "(cite 'verbs 'enlist 'verbs (as \\ (puts \"pack's verbs\\n\", flush out, 0)) ())\n"]])
   _ (put (dir + "/stray.l") "a file is no pack\n")

   r1 (run "hello")
   r2 (run "hello you")
   r3 (run "wave")
   r4 (run "verbs")
   r5 (run "-e \"(: f (cite 'verbs 'get 'verbs) _ (cite 'verbs 'call 'wave ()) (putx (f == cite 'verbs 'get 'verbs)))\"")
   r6 (run "-e \"(borrow 'words) (putx hi)\"")
   r7 (run "pack --list")
   ; HOME/.love with neither set; LOVE_NEST names the nest, HOME aside; XDG_DATA_HOME/love
   ; before HOME; /.love with no HOME; the child of a love reads the nest it resolved
   none "LOVE_NEST= XDG_DATA_HOME= "
   r8 (in-env (none + "HOME=" + home + "/none") "pack")
   r9 (in-env ("HOME=/nonexistent LOVE_NEST=" + home + "/.love") "hello nest")
   r10 (in-env ("LOVE_NEST= XDG_DATA_HOME=" + home + "/xdg HOME=/nonexistent") "pack")
   r11 (in-env ("env -u HOME " + none) "-e \"(puts (cite 'path 'nest 0), quit 0)\"")
   r12 (in-env ("LOVE_NEST= XDG_DATA_HOME=" + home + "/xdg") "-e \"(puts (getenv \\\"LOVE_NEST\\\"), quit 0)\"")
   _ (test (<r1 = 0) (>r1 = "hi there\n")
           (<r2 = 0) (>r2 = "hi you\n")
           (<r3 = 0) (>r3 = "wave\n")
           (<r4 = 0) !(has? >r4 "pack's verbs") (has? >r4 "verbs")
           (has? >r5 "1")
           (<r6 = 0) (has? >r6 "\"hi \"")
           (<r7 = 0)
           (>r7 = "hello\nverbs (the table wins)\nwave\nwords\n")
           (<r8 = 0) (>r8 = ("pack: none under " + home + "/none/.love/pack\n"))
           (<r9 = 0) (>r9 = "hi nest\n")
           (<r10 = 0) (>r10 = ("pack: none under " + home + "/xdg/love/pack\n"))
           (<r11 = 0) (>r11 = "/.love")
           (<r12 = 0) (>r12 = (home + "/xdg/love")))
   (hark ["rm" "-rf" home]))
(test_fin (), puts "pack: ok", putc 10, 0)
