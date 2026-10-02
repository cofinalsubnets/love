; src/apps/cpio.l -- cpio in love: the SVR4 "newc" archive, read and written. `(borrow 'cpio)`:
;
;   (cpio-pack entries)      -> the archive bytes
;   (cpio-unpack s)          -> (1 entries) | ()
;   (cpio-scatter root es u) -> (1 count) | ()   write entries back out under root
;   (cpio-scatter? warn root es u) -> (1 count refused)   the same, a refused member warned
;   (cpio-walk s f)          -> (1 count) | () | 'stop   the members off a stream, (tar-src rd)
;   (cpio-put warn root e u fill) -> 'laid | 'skip | 'refused | 'fail   one member laid
;
; an entry is tar.l's entry tablet ('nom 'kind 'body 'to 'mode 'mtime 'uid 'gid), so
; tar-gather and tar-level feed both wires. reads answer (1 _): an empty archive nets nothing.
;
; newc: a 110-byte ascii header ("070701" and thirteen 8-digit hex fields), the name (its
; NUL counted in namesize), the body, each padded to 4 from the archive start; "TRAILER!!!"
; ends it, padded to 512. the mode field is the whole st_mode, type bits included: a
; header with permission bits alone reads as a mode-0 file. a symlink's target is its body.
; hard links are not encoded: every entry gets a fresh ino and nlink 1.
(module 'cpio
(borrow 'tar)

(borrow 'path)
(borrow 'posix)
(borrow 'bytes)
(:
   cpio-mag "070701"
   cpio-trail "TRAILER!!!"

   ; --- the field pokes ------------------------------------------------------
   ; eight uppercase hex digits, zero-padded. every number in the header is this.
   (cpio-hex! b o v)
    (: (go i x) (i < 0 ? 0
                 (x & 15 @ d
                    (pin b (o + i) (d < 10 ? (48 + d) (55 + d)),
                     go (i - 1) (x >> 4))))
       (go 7 v))
   (cpio-hex s o)                           ; eight hex digits -> the number
    (: (go i acc) (8 <= i ? acc
                     (: c (s (o + i))
                        d (? (48 <= c <= 57)   (c - 48)
                             (65 <= c <= 70)   (c - 65 + 10)
                             (97 <= c <= 102)  (c - 97 + 10))
                        ; the refusal is asked by identity: `nil?` is a truth test, and
                        ; the digit 0 answers it as readily as a miss does
                        (d != () ? (go (i + 1) (acc << 4 | d)))))
       (go 0 0))

   ; --- the kind, which lives in the mode here --------------------------------
   (cpio-kmode k) (k @ 'dir 16384 'link 40960 32768)
   (cpio-kind m) (m & 61440 @ 16384 'dir 40960 'link 'file)

   ; --- writing ---------------------------------------------------------------
   (cpio-body e)                            ; what the member carries: a link says its target
    (peep e 'kind 'file @ 'link (peep e 'to "") 'dir "" (peep e 'body ""))
   (cpio-head ino nom mode mtime uid gid nb)
    (: nz (#nom + 1)
       h (cask 110)
       (txt! o s) (each ^#s (i \ pin h (o + i) (s i)), 0)
       (txt! 0 cpio-mag,
        cpio-hex! h 6 ino, cpio-hex! h 14 mode,
        cpio-hex! h 22 uid, cpio-hex! h 30 gid,
        cpio-hex! h 38 1,                  ; nlink -- see the header note
        cpio-hex! h 46 mtime, cpio-hex! h 54 nb,
        cpio-hex! h 62 0, cpio-hex! h 70 0,     ; dev major/minor
        cpio-hex! h 78 0, cpio-hex! h 86 0,     ; rdev major/minor
        cpio-hex! h 94 nz, cpio-hex! h 102 0,    ; namesize, and newc's dead check
        string h))
   (cpio-pack es)
    (: o (jug 0)
       (one i e)
        (: nom (peep e 'nom "")
           b (cpio-body e)
           nb #b
           mode (cpio-kmode (peep e 'kind 'file)
                 | peep e 'mode (peep e 'kind 'file = 'dir ? 493 420))
           (say o (cpio-head i nom mode (peep e 'mtime 0)
                             (peep e 'uid 0) (peep e 'gid 0) nb),
            say o (nom + string 0),
            say o (zbytes (padk (110 + #nom + 1) 4)),
            say o b,
            say o (zbytes (padk nb 4)),
            i + 1))
       _ (foldl one 1 es)
       ; the trailer is a member like any other, and its own name is the end mark
       _ (say o (cpio-head 0 cpio-trail 0 0 0 0 0))
       _ (say o (cpio-trail + string 0))
       _ (say o (zbytes (padk (110 + #cpio-trail + 1) 4)))
       s (slurp o)
       ; the archive ends on a 512 boundary. the kernel does not care and GNU cpio does
       ; not either, but `cmp` against a GNU archive does, and that is the oracle
       (s + zbytes (padk #s 512)))

   ; --- reading ---------------------------------------------------------------
   ; one header's fields off h, its 110 bytes -> (mode mtime nb uid gid nz) | ()
   (cpio-fields h)
    (#h < 110 || !(snip h 0 6 = cpio-mag) ? ()
       (: mode (cpio-hex h 14)   nb (cpio-hex h 54)   nz (cpio-hex h 94)
          (mode = () || nb = () || nz = () ? ()
             [mode (cpio-hex h 46) nb (cpio-hex h 22) (cpio-hex h 30) nz])))
   (cpio-read1 s n o)                       ; -> (1 entry next) | 'end | ()
    (: f (n < o + 110 ? () (cpio-fields (snip s o (o + 110))))
       (!f ? ()
          (: mode (f 0)   mtime (f 1)   nb (f 2)   uid (f 3)   gid (f 4)   nz (f 5)
             (n < o + 110 + nz ? ()
                (: nom (snip s (o + 110) (o + 110 + nz - 1))
                   b0 (o + 110 + nz + padk (110 + nz) 4)
                   (? (nom = cpio-trail) 'end
                      (n < b0 + nb) ()
                      (: kind (cpio-kind mode)
                         body (snip s b0 (b0 + nb))
                         e (tar-entry nom kind (kind = 'link ? "" body))
                         (pins e 'mode (mode & 4095) 'mtime mtime 'uid uid 'gid gid,
                          kind = 'link && pin e 'to body,
                          [1 e (b0 + nb + padk nb 4)]))))))))
   (cpio-unpack s)
    (:- (go 0 ()) n #s
     (go o acc) (cpio-read1 s n o @ r
                   (? (r = 'end) [1 (rev acc)]
                      !r ()
                      (go <>>r (<>r . acc)))))
   ; the members as they come off a stream, (tar-src rd): (f e b) for each, e with its 'size
   ; and no 'body, b the body for (tar-body s b wr) -- a link's target is read into 'to.
   ; f answers 1 to go on. -> (1 count) | () torn or not newc | 'stop f stopped it
   (cpio-walk s f)
    (: (go k)
        (cpio-fields (tar-take s 110) @ fs
           (!fs ? ()
              (: mode (fs 0)   nb (fs 2)   nz (fs 5)   hn (nz + padk (110 + nz) 4)
                 nm (tar-take s hn)
                 nom (snip nm 0 (nz < 1 ? 0 (nz - 1)))
                 kind (cpio-kind mode)
                 to (kind = 'link ? (tar-take s nb) "")
                 (? (#nm < hn || #to < (kind = 'link ? nb 0)) ()
                    (nom = cpio-trail) [1 k]
                    (: e (tar-entry nom kind "")
                       _ (pins e 'mode (mode & 4095) 'mtime (fs 1) 'uid (fs 3) 'gid (fs 4) 'size nb)
                       _ (kind = 'link && pin e 'to to)
                       b {'left (kind = 'link ? 0 nb)}
                       (f e b != 1 ? 'stop
                          (peep b 'left 0 + padk nb 4 @ n
                             (tar-pour s n (x \ 0) < n ? () (go (k + 1))))))))))
       (go 0))

   ; --- writing the tree back out ---------------------------------------------
   ; the leading directories are always made. GNU wants -d before it will and refuses
   ; the member otherwise; refusing to write a file we can write is not a service, so
   ; -d is a flag we accept and were already honouring.
   ; the parents are laid by tar-lay: made where missing, never through a symlink
   (cpio-there? p) (two? (lstat p))
   (cpio-newer? p ms)                       ; is what is already there at least as new
    (lstat p @ st (two? st ? !(<>st // 1000 < ms) 0))
   ; a name that climbs out of root, or a path through a symlink, is warned and skipped;
   ; a link at the member's own name is unlinked before the member is laid. the body goes
   ; through fill into the file opened for it. -> 'laid | 'skip | 'refused | 'fail
   (cpio-put warn root e u fill)
    (: nom (peep e 'nom "")
       sg (tar-segs nom)
       lp (sg && tar-lay root <>sg)
       p (lp && <>lp)
       kind (peep e 'kind 'file)
       _ (? !sg (warn (nom + ": member name contains '..'"))
            !lp (warn (nom + ": will not extract through a symbolic link or a file")))
       skip (!lp || atom? <>sg
             || !u && kind != 'dir && cpio-newer? p (peep e 'mtime 0))
       _ (skip || tar-link-at? p && unlink p)
       ok (? skip 1
             (kind = 'dir) (mkdir p 493,
                            tar-dir-at? p && chmod p (tar-perm (peep e 'mode 493)),
                            tar-dir-at? p)
             (kind = 'link) (symlink (peep e 'to "") p,
                             string? (readlink p))
             (open p "w" @ q
              (hot? q && (fill q, close q),
               tar-at? p 32768 && chmod p (tar-perm (peep e 'mode 420)),
               cpio-there? p)))
       (? !ok 'fail !lp 'refused skip 'skip 'laid))
   (cpio-scatter? warn root es u)           ; -> (1 count refused)
    (: (go xs k r)
        (!(two? xs) ? [1 k r]
           (: e <xs   w (cpio-put warn root e u (q \ say q (peep e 'body "")))
              (w = 'fail ? ()
                 (go >xs (w = 'laid ? (k + 1) k) (w = 'refused ? (r + 1) r)))))
       (go es 0 0))
   (cpio-scatter root es u)                 ; -> (1 count) | (), () on any refusal
    (cpio-scatter? (m \ 0) root es u @ w (w && w 2 = 0 ? [1 (w 1)] ())))

) ; module 'cpio

; --- the face -----------------------------------------------------------------------
; `love cpio`: the three copy modes over the newc wire above.
;
;   find . | love cpio -o [-H newc] [-O F] [-v] [--quiet] > A.cpio   copy-out
;   love cpio -i [-d] [-u] [-v] [-I F] [--quiet] < A.cpio            copy-in
;   love cpio -t [-I F] < A.cpio                                     the names
;   -F F names the archive for either direction (-I and -O say one side each)
;
; the names come in on stdin, one a line, in find's order (a directory before its contents).
; absent on purpose: -H other than newc (refused by name), absolute names (a leading / is
; always stripped), -tv's ls listing, and -p (`find | cpio -o | (cd dst && cpio -i)`).
; the leading directories are always made; -d is accepted.
(module 'cpiocmd
(borrow 'tar)
(borrow 'cpio)

(borrow 'posix)
(: cpioc-usage "usage: cpio {-o|-i|-t} [-H newc] [-dutv] [-F|-I|-O FILE] [--quiet]"
   (cpioc-moan m) (say err ("cpio: " + m), put err 10, flush err)
   (cpioc-blocks t n)                       ; GNU's parting word, on err, in 512s
    (peep t 'quiet 0 ? 0
       ((n + 512 - 1) // 512 @ k
          (say err (show k + " block" + (k = 1 ? "" "s")),
           put err 10, flush err)))
   (cpioc-tell t nom) (peep t 'v 0 && (say err nom, put err 10))
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
          (tar-entry nom 'link "" @ e (pins e 'to lnk 'mode 511, [1 (own e)]))
          (atom? st) (cpioc-moan (p + ": No such file or directory"), ())
          (<>>st & 61440 = 16384)
           (tar-entry nom 'dir "" @ e (pin e 'mode (<>>st & 4095), [1 (own e)]))
          (uread p @ b
           (!b ? (cpioc-moan (p + ": cannot read"), ())
            (tar-entry nom 'file <>b @ e
               (pin e 'mode (<>>st & 4095),
                [1 (own e)]))))))

   ; --- the three modes -------------------------------------------------------
   (cpioc-o t)
    (: ns (cpioc-lines (slurp in + ""))
       (go l acc ok)
        (atom? l ? [(rev acc) ok]
         (<l @ p
          (#p @ 0 (go >l acc ok)            ; find's trailing empty line
           (cpioc-one p @ r
            (!r ? (go >l acc 0)
             (cpioc-tell t p, go >l (<>r . acc) ok))))))
       g (go ns () 1)
       s (cpio-pack <g)
       dst (t 'out)
       ((string? dst ?
         (uwrite dst s ? 0 (cpioc-moan ("cannot write " + dst)))
         (say out s, flush out)),
        cpioc-blocks t #s,
        (<>g ? 0 1)))
   ; the archive a piece at a time off -I FILE or stdin, the bytes counted for the blocks
   ; line -> (src count) | ()
   (cpioc-src t)
    (: src (t 'in)   q (string? src ? (open src "r") in)
       (!(hot? q) ? (cpioc-moan ("cannot read " + src), ())
          ({0 0} @ c
             [(tar-src (_ \ (see q @ ch
                               (ch < 0 ? ""
                                  (: _ (unsee q ch)   p (chug q)   (pin c 0 (peep c 0 0 + #p), p))))))
              c])))
   (cpioc-drain src) (: (dr r) (#(r 0) = 0 ? 0 (dr r)) (dr (tar-rd src)))
   (cpioc-strip nom)                        ; no leading /, ever
    (: n #nom
       (go k) (k < n && nom k = 47 ? (go (k + 1)) k)
     (go 0 @ 0 nom k (snip nom k n)))
   ; -i and -t walk the members as they come, a body poured to its file and never held;
   ; a member laid before a later one turns out torn stays laid, as GNU's does
   (cpioc-i t)
    (cpioc-src t @ sc
     (!sc ? 1
      (: src <sc   bad {0 0}
         w (cpio-walk src (e \ b \ (: _ (pin e 'nom (cpioc-strip (peep e 'nom "")))
                                     _ (cpioc-tell t (peep e 'nom ""))
                                     r (cpio-put cpioc-moan "" e (peep t 'u 0) (q \ tar-body src b (x \ say q x)))
                                     (r = 'refused && pin bad 0 1,
                                      (r = 'fail ? 'stop 1)))))
         (!(two? w || w = 'stop) ? (cpioc-moan "premature end of archive", 1)
            (cpioc-drain src,
             cpioc-blocks t (peep (sc 1) 0 0),
             (? (w = 'stop) (cpioc-moan "cannot write the tree", 1)
                (peep bad 0 0) 1
                0))))))
   (cpioc-t t)
    (cpioc-src t @ sc
     (!sc ? 1
      (: src <sc
         w (cpio-walk src (e \ b \ (say out (peep e 'nom ""), put out 10, 1)))
         (flush out,
          (!(two? w) ? (cpioc-moan "premature end of archive", 1)
             (cpioc-drain src, cpioc-blocks t (peep (sc 1) 0 0), 0))))))

   ; --- the options -----------------------------------------------------------
   ; the cli walker in posix order: the flags lead, the first operand ends them. a long flag
   ; with no short twin pins under a key past the byte range, so no letter reaches it
   cpioc-longs {"create" 111 "extract" 105 "list" 116 "make-directories" 100 "unconditional" 117
                "verbose" 118 "quiet" 1001 "no-absolute-filenames" 1002 "help" 104 "version" 1003
                "format" 72 "file" 70}
   (cpioc-opts as t)                        ; -> (1 rest) | ()
    (: u {}
       r (cite 'cli 'uopt as u [72 70 73 79] () cpioc-longs)
       rest (two? r ? (r 2))
       k (#as - #rest)
       w (two? rest ? <rest "")
       bad (two? r ? (cite 'cli 'uoptun u [111 105 116 100 117 118 104 72 70 73 79 1001 1002 1003]))
       (val c) (peep u c () @ v (two? v && <>v))
       (? !(two? r) (cpioc-moan (<(rev as) + " wants a value"), ())
          (2 < #w && w 0 = 45 && w 1 = 45 && !(0 < k && as (k - 1) = "--"))
           (cpioc-moan ("unknown option " + w), ())
          bad (cpioc-moan ("unknown option -" + string bad), ())
          (val 72 @ fmt
             (fmt && fmt != "newc" ? (cpioc-moan ("format " + fmt + " is not here (newc only)"), ())
                (cite 'cli 'uoptlast as [111 105 116] [72 70 73 79] cpioc-longs @ m
                   ((m ? (pin t 'mode (m @ 111 'o 105 'i 't))),
                    each [100 117 118 104] (c \ peep u c 0 && pin t (intern (string c)) 1),
                    (peep u 1001 0 ? (pin t 'quiet 1)),
                    (peep u 1003 0 ? (pin t 'vers 1)),
                    (val 70 @ f (f ? (pins t 'in f 'out f))),
                    (val 73 @ v (v ? (pin t 'in v))),
                    (val 79 @ v (v ? (pin t 'out v))),
                    [1 rest]))))))
   (cpio-main as)
    (: t {}
       o (cpioc-opts as t)
       (? !o 2
          (peep t 'h 0) (say out (cpioc-usage + "\n"), flush out, 0)
          (peep t 'vers 0)
           (say out (uvers "cpio" + "\n"), flush out, 0)
          (t 'mode @ m
             (two? <>o && cpioc-moan "the names come in on stdin, not on the line",
              (m @ 'o (cpioc-o t) 'i (cpioc-i t) 't (cpioc-t t) (cpioc-moan cpioc-usage, 2))))))

   ; bound, not the body: a bodyless letrec leaks cpio-main onto the module, which is
   ; how kore's registry cites it (gzcmd and tarcmd are spelled the same way)
   _ (pins (cite 'verbs 'tab) 'cpio cpio-main))

) ; module 'cpiocmd
