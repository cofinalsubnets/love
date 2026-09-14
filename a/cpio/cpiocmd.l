; a/cpio/cpiocmd.l -- `love cpio`: the three copy modes over a/cpio/cpio.l's newc wire.
;
;   find . | love cpio -o [-H newc] [-O F] [-v] [--quiet] > A.cpio   copy-out
;   love cpio -i [-d] [-u] [-v] [-I F] [--quiet] < A.cpio            copy-in
;   love cpio -t [-I F] < A.cpio                                     the names
;   -F F names the archive for either direction (-I and -O say one side each)
;
; the names come in on stdin, one a line, exactly as `find` prints them and in the
; order it printed them -- so a directory arrives before what is under it, which is
; the only ordering an extractor can rely on.
;
; what is deliberately absent, since an absence is not visible in the code:
;  -H takes newc and nothing else -- bin, odc, crc and the tapes are refused by name,
;    because a `-H odc` that quietly wrote newc is an archive whose header lies
;  a leading / is always stripped and there is no --absolute-filenames to put it back;
;    --no-absolute-filenames is taken and names what we do
;  -t has no -v: GNU's `-tv` is an ls -l listing, a layout with a user table and a date
;    format in it. -v with -o or -i names each member on err, which is what a script reads
;  -p (pass-through) is a third mode with its own semantics, and
;    `find | cpio -o | (cd dst && cpio -i)` says the same thing with the two we have
;
; the leading directories are always made on the way in; -d is taken and was already
; the behaviour. tar rides module 'tar and this file reads its entry shapes, so the ask
; lands in a layer of our own rather than on the dist cat's shared one.
(module 'cpiocmd
(borrow 'tar)
(borrow 'cpio)

(borrow 'posix)
(: cpioc-usage "usage: cpio {-o|-i|-t} [-H newc] [-dutv] [-F|-I|-O FILE] [--quiet]"
   (cpioc-moan m) (: _ (say err ("cpio: " + m)) _ (put err 10) (flush err))
   (cpioc-slurp p) (: q (open p "r") (hot? q && (: s (slurp q) _ (close q) [1 (s + "")])))
   (cpioc-blurt p s) (: q (open p "w") (hot? q && (: _ (say q s) _ (close q) 1)))
   (cpioc-blocks t n)                       ; GNU's parting word, on err, in 512s
    (? (peep t 'quiet 0) 0
       (: k ((n + 512 - 1) // 512)
          _ (say err (show k + " block" + (k = 1 ? "" "s")))
          _ (put err 10) (flush err)))
   (cpioc-tell t nom) (peep t 'v 0 && (: _ (say err nom) (put err 10)))
   ; the name list, split here rather than by kore's `lines`: that one is module 'kore's
   ; and this file is a lib, outside it
   (cpioc-lines s)
    (:- (go 0 0 ()) n #s (go k st acc)
     (? (n <= k) (rev (st < k ? (snip s st k . acc) acc))
        (s k = 10) (go (k + 1) (k + 1) (snip s st k . acc))
        (go (k + 1) st acc)))

   ; one named path -> its entry. no descent: `find` already walked, and walking again
   ; here would carry what the caller's own find deliberately pruned. the stored name
   ; loses a leading "./" the way GNU cpio drops it, so a reader diffing two listings
   ; does not call ours a different archive.
   (cpioc-one p)                            ; -> (1 entry) | ()
    (: lnk (readlink p)
       st (stat p)
       nom (tar-strip p)
       (own e) (: _ (5 < #st && pins e 'uid (st 4) 'gid (st 5))
                  _ (two? st && pin e 'mtime (<>st // 1000))
                  e)
       (? (string? lnk)
          (: e (tar-entry nom 'link "") _ (pins e 'to lnk 'mode 511) [1 (own e)])
          (one? st) (cpioc-moan (p + ": No such file or directory"), ())
          (<>>st & 61440 = 16384)
           (: e (tar-entry nom 'dir "") _ (pin e 'mode (<>>st & 4095)) [1 (own e)])
          (: b (cpioc-slurp p)
             (? !b (: _ (cpioc-moan (p + ": cannot read")) ())
                (: e (tar-entry nom 'file <>b)
                   _ (pin e 'mode (<>>st & 4095))
                   [1 (own e)])))))

   ; --- the three modes -------------------------------------------------------
   (cpioc-o t)
    (: ns (cpioc-lines (slurp in + ""))
       (go l acc ok)
        (? (one? l) [(rev acc) ok]
           (: p <l
              (#p @ 0 (go >l acc ok)            ; find's trailing empty line
               (: r (cpioc-one p)
                (? !r (go >l acc 0)
                 (cpioc-tell t p, go >l (<>r . acc) ok))))))
       g (go ns () 1)
       s (cpio-pack <g)
       dst (t 'out)
       _ (? (string? dst)
            (cpioc-blurt dst s ? 0 (cpioc-moan ("cannot write " + dst)))
            (say out s, flush out))
       _ (cpioc-blocks t #s)
       (<>g ? 0 1))
   (cpioc-in t)                             ; -> (1 bytes) | ()
    (: src (t 'in)
       (? (string? src) (: r (cpioc-slurp src)
                           (r || (: _ (cpioc-moan ("cannot read " + src)) ())))
          [1 (slurp in + "")]))
   (cpioc-strip nom)                        ; no leading /, ever
    (: n #nom
       (go k) (? (k < n && nom k = 47) (go (k + 1)) k)
       k (go 0)
       (k = 0 ? nom (snip nom k n)))
   (cpioc-i t)
    (: b (cpioc-in t)
       (? !b 1
          (: es (cpio-unpack <>b)
             (? !es (: _ (cpioc-moan "premature end of archive") 1)
                (: fs (map (e \ (: t2 {}
                                   _ (map (k \ pin t2 k (e k)) (keys e))
                                   _ (pin t2 'nom (cpioc-strip (peep e 'nom "")))
                                   _ (cpioc-tell t (peep t2 'nom ""))
                                   t2))
                           <>es)
                   w (cpio-scatter "" fs (peep t 'u 0))
                   _ (cpioc-blocks t #<>b)
                   (w ? 0 (: _ (cpioc-moan "cannot write the tree") 1)))))))
   (cpioc-t t)
    (: b (cpioc-in t)
       (? !b 1
          (: es (cpio-unpack <>b)
             (? !es (: _ (cpioc-moan "premature end of archive") 1)
                (: _ (foldl (\ _ e (: _ (say out (peep e 'nom "")) (put out 10))) 0 <>es)
                   _ (flush out)
                   _ (cpioc-blocks t #<>b)
                   0)))))

   ; --- the options -----------------------------------------------------------
   (cpioc-long t w)                         ; -> 1 taken | 'val a word is wanted | ()
    (w @ ("create" || "extract") (pin t 'mode (w = "create" ? 'o 'i))
         "list" (pin t 'mode 't)
         "make-directories" (pin t 'd 1)
         "unconditional" (pin t 'u 1)
         "verbose" (pin t 'v 1)
         "quiet" (pin t 'quiet 1)
         "no-absolute-filenames" 1      ; what we do anyway, said out loud
         "help" (pin t 'h 1)
         "version" (pin t 'vers 1)
         ("format" || "file") 'val)
   (cpioc-opts as t)                        ; -> (1 rest) | ()
    (: (want k v)                           ; a value word landing in its place
        (? (k = "format") (? (v = "newc") 1
                             (: _ (cpioc-moan ("format " + v + " is not here (newc only)")) ()))
           (: _ (pin t 'in v) (pin t 'out v) 1))
       (go a)
        (one? a ? '(1 ())
           (: w <a n #w
              (? (w = "--") [1 >a]
                 (n < 2 || !(w 0 = 45)) [1 a]
                 (w 1 = 45)
                  (: k (snip w 2 n)
                     r (cpioc-long t k)
                     (? !r (: _ (cpioc-moan ("unknown option " + w)) ())
                        (= r 'val)
                         (? (two? >a) (want k <>a ? (go >>a) ())
                            (: _ (cpioc-moan (w + " wants a value")) ()))
                        (go >a)))
                 (: (cl i rest)
                     (n <= i ? (go rest)
                      (: c (w i)
                         (? (elem c '(111 105 116))            ; -o -i -t
                            (pin t 'mode (? (c = 111) 'o (c = 105) 'i 't),
                             cl (i + 1) rest)
                            (elem c '(100 117 118))            ; -d -u -v
                             (pin t (? (c = 100) 'd (c = 117) 'u 'v) 1,
                              cl (i + 1) rest)
                            (c = 104) (pin t 'h 1, cl (i + 1) rest)   ; -h, the help
                            (elem c '(72 70 73 79))            ; -H -F -I -O
                             (: glue (snip w (i + 1) n)
                                v (0 < #glue ? glue (two? rest && <rest))
                                rest2 (0 < #glue ? rest (two? rest ? >rest rest))
                                (? !(string? v)
                                   (cpioc-moan ("-" + string c + " wants a value"), ())
                                   (c = 72) (want "format" v ? (go rest2) ())
                                   (: _ (c @ 73 (pin t 'in v)
                                             79 (pin t 'out v)
                                                (pin t 'in v, pin t 'out v))
                                      (go rest2))))
                            (: _ (cpioc-moan ("unknown option -" + string c)) ()))))
                    (cl 1 >a)))))
       (go as))
   (cpio-main as)
    (: t {}
       o (cpioc-opts as t)
       (? !o 2
          (peep t 'h 0) (: _ (say out (cpioc-usage + "\n")) _ (flush out) 0)
          (peep t 'vers 0)
           (: _ (say out ("cpio (love " + love-version + ")\n")) _ (flush out) 0)
          (: m (t 'mode)
             _ (two? <>o && cpioc-moan "the names come in on stdin, not on the line")
           (m @ 'o (cpioc-o t) 'i (cpioc-i t) 't (cpioc-t t) (cpioc-moan cpioc-usage, 2)))))

   ; bound, not the body: a bodyless letrec leaks cpio-main onto the module, which is
   ; how kore's registry cites it (gzcmd and tarcmd are spelled the same way)
   _ (pins (cite 'verbs 'tab) 'cpio cpio-main))

) ; module 'cpiocmd
