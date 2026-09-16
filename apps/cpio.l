; apps/cpio.l -- cpio in love: the SVR4 "newc" archive, read and written. `(borrow 'cpio)`:
;
;   (cpio-pack entries)      -> the archive bytes
;   (cpio-unpack s)          -> (1 entries) | ()
;   (cpio-scatter root es u) -> (1 count) | ()   write entries back out under root
;
; an entry is apps/tar.l's entry -- the same tablet, the same keys ('nom 'kind 'body 'to
; 'mode 'mtime 'uid 'gid) -- because the walk that fills them (`tar-gather`) and the
; leveller that makes them reproducible (`tar-level`) are about a file and not about a
; wire. this file is a second wire for them, which is the whole reason it is short.
; presence rides the (1 _) wrapper on the read: an archive of no entries is legitimate
; and nets nothing, so the value alone cannot say torn from empty.
;
; the format, in one breath: a 110-byte all-ASCII header per member -- "070701" then
; thirteen eight-digit hex fields -- then the name (its NUL counted in namesize), then
; the body, each padded up to a 4-byte boundary measured from the start of the archive.
; a member named "trailer!!!" ends it, and the whole is padded to 512 with NULs.
;
; the mode field is the whole st_mode, type bits and all -- 0100000 for a file, 0040000
; for a directory, 0120000 for a symlink -- where tar keeps the kind in a separate
; typeflag byte. a newc header carrying permission bits alone extracts as a file of
; mode 0 and no kind, which the kernel's own initramfs reader takes silently. a
; symlink's target is the body, counted in filesize and not NUL-terminated.
;
; hard links are not encoded. newc says them with a shared ino and nlink > 1, the body
; hung on the last member; we write a fresh ino and nlink 1 for every entry, so a tree
; of hard links comes back as copies. a half-done job here would be worse than none: a
; reader that believes nlink waits for a body that never comes.
;
; cpio rides module 'cpio and reads tar's names, the entry shape being tar's on purpose
; so one walk feeds both wires. a consumer says (borrow 'cpio).
(module 'cpio
(borrow 'tar)

(borrow 'path)
(borrow 'posix)
(:
   cpio-mag "070701"
   cpio-trail "TRAILER!!!"

   ; --- the field pokes ------------------------------------------------------
   ; eight uppercase hex digits, zero-padded. every number in the header is this.
   (cpio-hex! b o v)
    (: (go i x) (i < 0 ? 0
                 (: d (x & 15)
                    _ (pin b (o + i) (d < 10 ? (48 + d) (55 + d)))
                  (go (i - 1) (x >> 4))))
       (go 7 v))
   (cpio-hex s o)                           ; eight hex digits -> the number
    (: (go i acc) (? (8 <= i) acc
                     (: c (s (o + i))
                        d (? (48 <= c <= 57)   (c - 48)
                             (65 <= c <= 70)   (c - 65 + 10)
                             (97 <= c <= 102)  (c - 97 + 10))
                        ; the refusal is asked by identity: `nil?` is a truth test, and
                        ; the digit 0 answers it as readily as a miss does
                        (d != () ? (go (i + 1) (acc << 4 | d)))))
       (go 0 0))
   (cpio-pad n) ((4 - n % 4) % 4)           ; the NULs after a name or a body
   (cpio-nuls k) (: (go i acc) (k <= i ? acc (go (i + 1) (acc + string 0))) (go 0 ""))

   ; --- the kind, which lives in the mode here --------------------------------
   (cpio-kmode k) (k @ 'dir 16384 'link 40960 32768)
   (cpio-kind m) (m & 61440 @ 16384 'dir 40960 'link 'file)

   ; --- writing ---------------------------------------------------------------
   (cpio-body e)                            ; what the member carries: a link says its target
    (peep e 'kind 'file @ 'link (peep e 'to "") 'dir "" (peep e 'body ""))
   (cpio-head ino nom mode mtime uid gid nb)
    (: nz (#nom + 1)
       h (cask 110)
       (txt! o s) (: n #s
                     (go i) (n <= i ? 0 (pin h (o + i) (s i), go (i + 1)))
                     (go 0))
       _ (txt! 0 cpio-mag)
       _ (cpio-hex! h 6 ino)   _ (cpio-hex! h 14 mode)
       _ (cpio-hex! h 22 uid)  _ (cpio-hex! h 30 gid)
       _ (cpio-hex! h 38 1)                  ; nlink -- see the header note
       _ (cpio-hex! h 46 mtime) _ (cpio-hex! h 54 nb)
       _ (cpio-hex! h 62 0)  _ (cpio-hex! h 70 0)     ; dev major/minor
       _ (cpio-hex! h 78 0)  _ (cpio-hex! h 86 0)     ; rdev major/minor
       _ (cpio-hex! h 94 nz) _ (cpio-hex! h 102 0)    ; namesize, and newc's dead check
       (string h))
   (cpio-pack es)
    (: o (jug 0)
       (one i e)
        (: nom (peep e 'nom "")
           b (cpio-body e)
           nb #b
           mode (cpio-kmode (peep e 'kind 'file)
                 | peep e 'mode (peep e 'kind 'file = 'dir ? 493 420))
           _ (say o (cpio-head i nom mode (peep e 'mtime 0)
                               (peep e 'uid 0) (peep e 'gid 0) nb))
           _ (say o (nom + string 0))
           _ (say o (cpio-nuls (cpio-pad (110 + #nom + 1))))
           _ (say o b)
           _ (say o (cpio-nuls (cpio-pad nb)))
           (i + 1))
       _ (foldl one 1 es)
       ; the trailer is a member like any other, and its own name is the end mark
       _ (say o (cpio-head 0 cpio-trail 0 0 0 0 0))
       _ (say o (cpio-trail + string 0))
       _ (say o (cpio-nuls (cpio-pad (110 + #cpio-trail + 1))))
       s (slurp o)
       ; the archive ends on a 512 boundary. the kernel does not care and GNU cpio does
       ; not either, but `cmp` against a GNU archive does, and that is the oracle
       (s + cpio-nuls ((512 - #s % 512) % 512)))

   ; --- reading ---------------------------------------------------------------
   (cpio-read1 s n o)                       ; -> (1 entry next) | 'end | ()
    (? (n < o + 110) ()
       !(snip s o (o + 6) = cpio-mag) ()
       (: mode (cpio-hex s (o + 14))
          mtime (cpio-hex s (o + 46))
          nb (cpio-hex s (o + 54))
          uid (cpio-hex s (o + 22)) gid (cpio-hex s (o + 30))
          nz (cpio-hex s (o + 94))
          (? (mode = () || nb = () || nz = ()) ()
             (n < o + 110 + nz) ()
             (: nom (snip s (o + 110) (o + 110 + nz - 1))
                b0 (o + 110 + nz + cpio-pad (110 + nz))
                (? (nom = cpio-trail) 'end
                   (n < b0 + nb) ()
                   (: kind (cpio-kind mode)
                      body (snip s b0 (b0 + nb))
                      e (tar-entry nom kind (= kind 'link ? "" body))
                      _ (pins e 'mode (mode & 4095) 'mtime mtime 'uid uid 'gid gid)
                      _ (kind = 'link && pin e 'to body)
                      [1 e (b0 + nb + cpio-pad nb)]))))))
   (cpio-unpack s)
    (:- (go 0 ()) n #s
     (go o acc) (: r (cpio-read1 s n o)
                   (? (r = 'end) [1 (rev acc)]
                      !r ()
                      (go <>>r (<>r . acc)))))

   ; --- writing the tree back out ---------------------------------------------
   ; the leading directories are always made. GNU wants -d before it will and refuses
   ; the member otherwise; refusing to write a file we can write is not a service, so
   ; -d is a flag we accept and were already honouring.
   ; every parent of p and not p itself: the caller is about to make that
   (cpio-mkp p) (each (pprefixes p) (\ d (mkdir d 493)))
   (cpio-there? p) (two? (stat p))
   (cpio-newer? p ms)                       ; is what is already there at least as new
    (: st (stat p) (two? st ? !(<>st // 1000 < ms) 0))
   (cpio-scatter root es u)                 ; -> (1 count) | ()
    (: (go xs k)
        (? !(two? xs) [1 k]
           (: e <xs
              nom (tar-strip (peep e 'nom ""))
              p (#nom ? (#root ? (root + "/" + nom) nom) root)
              kind (peep e 'kind 'file)
              _ (cpio-mkp p)
              skip (!u && !(= kind 'dir) && cpio-newer? p (peep e 'mtime 0))
              ok (? skip 1
                    (kind = 'dir) (mkdir p (peep e 'mode 493), cpio-there? p)
                    (kind = 'link) (cpio-there? p && unlink p,
                                    symlink (peep e 'to "") p,
                                    string? (readlink p))
                    (: q (open p "w")
                     (hot? q && (: _ (say q (peep e 'body "")) (close q)),
                      cpio-there? p && chmod p (peep e 'mode 420),
                      cpio-there? p)))
              (ok && go >xs (skip ? k (k + 1)))))
       (go es 0)))

) ; module 'cpio

; --- the face -----------------------------------------------------------------------
; `love cpio`: the three copy modes over the newc wire above.
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
   (cpioc-moan m) (say err ("cpio: " + m), put err 10, flush err)
   (cpioc-slurp p) (: q (open p "r") (hot? q && (: s (slurp q) (close q, [1 (s + "")]))))
   (cpioc-blurt p s) (: q (open p "w") (hot? q && (say q s, close q, 1)))
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
       (own e) (5 < #st && pins e 'uid (st 4) 'gid (st 5),
                two? st && pin e 'mtime (<>st // 1000),
                e)
       (? (string? lnk)
          (: e (tar-entry nom 'link "") _ (pins e 'to lnk 'mode 511) [1 (own e)])
          (one? st) (cpioc-moan (p + ": No such file or directory"), ())
          (<>>st & 61440 = 16384)
           (: e (tar-entry nom 'dir "") (pin e 'mode (<>>st & 4095), [1 (own e)]))
          (: b (cpioc-slurp p)
           (? !b (cpioc-moan (p + ": cannot read"), ())
            (: e (tar-entry nom 'file <>b)
               _ (pin e 'mode (<>>st & 4095))
               [1 (own e)])))))

   ; --- the three modes -------------------------------------------------------
   (cpioc-o t)
    (: ns (cpioc-lines (slurp in + ""))
       (go l acc ok)
        (one? l ? [(rev acc) ok]
         (: p <l
          (#p @ 0 (go >l acc ok)            ; find's trailing empty line
           (: r (cpioc-one p)
            (? !r (go >l acc 0)
             (cpioc-tell t p, go >l (<>r . acc) ok))))))
       g (go ns () 1)
       s (cpio-pack <g)
       dst (t 'out)
       _ (string? dst ?
          (cpioc-blurt dst s ? 0 (cpioc-moan ("cannot write " + dst)))
          (say out s, flush out))
       _ (cpioc-blocks t #s)
       (<>g ? 0 1))
   (cpioc-in t)                             ; -> (1 bytes) | ()
    (: src (t 'in)
       (string? src ? (cpioc-slurp src || (cpioc-moan ("cannot read " + src), ()))
                      [1 (slurp in + "")]))
   (cpioc-strip nom)                        ; no leading /, ever
    (: n #nom
       (go k) (k < n && nom k = 47 ? (go (k + 1)) k)
     (go 0 @ 0 nom k (snip nom k n)))
   (cpioc-i t)
    (: b (cpioc-in t)
     (? !b 1
      (: es (cpio-unpack <>b)
         (? !es (cpioc-moan "premature end of archive", 1)
            (: fs (map (e \ (: t2 {}
                               _ (map (k \ pin t2 k (e k)) (keys e))
                               _ (pin t2 'nom (cpioc-strip (peep e 'nom "")))
                               _ (cpioc-tell t (peep t2 'nom ""))
                               t2))
                       <>es)
               w (cpio-scatter "" fs (peep t 'u 0))
               _ (cpioc-blocks t #<>b)
               (w ? 0 (cpioc-moan "cannot write the tree", 1)))))))
   (cpioc-t t)
    (cpioc-in t @- 1 [1 b] (cpio-unpack b @-
     (cpioc-moan "premature end of archive", 1)
     [1 es] (foldl (\ _ e (say out (peep e 'nom ""), put out 10)) 0 es,
             flush out,
             cpioc-blocks t #b,
             0)))

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
    (:- (go as)
     (want k v)                           ; a value word landing in its place
      (k @- (pins t 'in v 'out v, 1) "format"
       (v @ "newc" 1 (cpioc-moan ("format " + v + " is not here (newc only)"), ())))
     (go a)
      (one? a ? '(1 ())
         (: w <a n #w
            (? (w = "--") [1 >a]
               (n < 2 || w 0 != 45) [1 a]
               (w 1 = 45)
                (: k (snip w 2 n)
                 (cpioc-long t k @- (go >a)
                  () (cpioc-moan ("unknown option " + w), ())
                  'val (two? >a ? (want k <>a ? (go >>a))
                        (cpioc-moan (w + " wants a value"), ()))))
               (:- (cl 1 >a) (cl i rest)
                (n <= i ? (go rest)
                  (: c (w i)
                     (c @ (111 || 105 || 116)            ; -o -i -t
                         (pin t 'mode (c @ 111 'o 105 'i 't),
                          cl (i + 1) rest)
                        (100 || 117 || 118)            ; -d -u -v
                         (pin t (c @ 100 'd 117 'u 'v) 1,
                          cl (i + 1) rest)
                        104 (pin t 'h 1, cl (i + 1) rest)   ; -h, the help
                        (72 || 70 || 73 || 79)            ; -H -F -I -O
                         (: glue (snip w (i + 1) n)
                            v (0 < #glue ? glue (two? rest && <rest))
                            rest2 (0 < #glue ? rest (two? rest ? >rest rest))
                            (? !(string? v)
                                (cpioc-moan ("-" + string c + " wants a value"), ())
                               ; -H answers the recursion itself: a format we refuse
                               ; must stop the parse, not fall through it
                               (c = 72) (want "format" v ? (go rest2))
                               (c @ 73 (pin t 'in v) 79 (pin t 'out v)
                                       (pins t 'in v 'out v),
                                go rest2)))
                        (cpioc-moan ("unknown option -" + string c), ())))))))))
   (cpio-main as)
    (: t {}
       o (cpioc-opts as t)
       (? !o 2
          (peep t 'h 0) (say out (cpioc-usage + "\n"), flush out, 0)
          (peep t 'vers 0)
           (say out ("cpio (love " + love-version + ")\n"), flush out, 0)
          (: m (t 'mode)
             _ (two? <>o && cpioc-moan "the names come in on stdin, not on the line")
           (m @ 'o (cpioc-o t) 'i (cpioc-i t) 't (cpioc-t t) (cpioc-moan cpioc-usage, 2)))))

   ; bound, not the body: a bodyless letrec leaks cpio-main onto the module, which is
   ; how kore's registry cites it (gzcmd and tarcmd are spelled the same way)
   _ (pins (cite 'verbs 'tab) 'cpio cpio-main))

) ; module 'cpiocmd
