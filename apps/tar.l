; apps/tar.l -- tar in love: the ustar archive, read and written. `(borrow 'tar)`, then:
;
;   (tar-pack entries)     -> the archive bytes
;   (tar-unpack s)         -> (1 entries) | ()
;   (tar-gather root path) -> (1 entries) | ()    walk the filesystem into entries
;   (tar-scatter root es)  -> (1 count) | ()      write entries back out under root
;
; an entry is a tablet, because the header has fourteen fields and a positional list
; of them would be unreadable at every call site. the keys, and the only ones that
; matter: 'nom the path as stored (relative, no leading /), 'kind one of 'file 'dir
; 'link, 'body the bytes (a file), 'to the target (a link), 'mode the permission bits,
; 'mtime, 'uid, 'gid, 'uname, 'gname. (tar-entry nom kind body) fills the rest with the
; ordinary defaults, which is what nearly every caller wants.
;
; presence rides the (1 _) wrapper on both reads, and it must: an empty archive is a
; legitimate archive and answers no entries, which nets nothing -- indistinguishable
; from a torn one by the value alone. test with two?.
;
; the format, in one breath: a 512-byte header per member, then the body padded up to
; the next 512, then two zero blocks to end. Every numeric field is octal in ASCII with
; a NUL or a space where the digits stop, which is why they are written by hand here
; rather than by any number printer -- the widths are the format's, not ours.
;
; the checksum is computed over the header with its own field read as eight spaces.
; That is not a convention we could choose differently: it is how the field can live
; inside the block it sums. It is written back as six octal digits, a NUL, then a
; space -- an order two of the three historical tars disagree about, and the one every
; reader accepts.
;
; ustar splits a long name across `prefix` (155) and `name` (100), joined with a "/"
; that is not stored. a path that fits neither -- no "/" leaving a <=100 tail -- is
; refused rather than truncated: a silently shortened path is a wrong archive that
; looks right until something extracts it.
; the wrap: tar rides module 'tar. a consumer says (borrow 'tar); riding a cat -- the
; dist artifact's, where this file is evaluated into the image -- the wrap registers
; the same module, so the compile is paid once at bake time and (borrow 'tar) is a splice
; afterwards rather than a reload. unwrapped it leaked its names into the cat's layer
; and `borrow` found no module, so every caller recompiled this file from lib/.
(module 'tar
(borrow 'posix)
(borrow 'bytes)
(:
   tar-blk 512

   ; --- the field pokes ------------------------------------------------------
   ; octal, right-aligned in n-1 columns, zero-padded, then a NUL. this is the
   ; `%0*lo` of every tar ever written, spelled out because the widths are the wire.
   (tar-oct! b o n v)
    (: (go i x) (i >= 0 ? (pin b (o + i) (48 + (x & 7)), go (i - 1) (x >> 3)))
     (pin b (o + n - 1) 0, go (n - 2) v))
   (tar-txt! b o n s)                       ; a text field, NUL-filled, never overrun
    (: k #s (go i) (n > i ? (pin b (o + i) (i < k ? (s i) 0), go (i + 1))) (go 0))
   (tar-sum b)                              ; the header checksum, own field as spaces
    (: (go i a) (tar-blk <= i ? a (go (i + 1) (a + (148 <= i < 156 ? 32 (peep b i 0))))) (go 0 0))

   ; --- the field peeks ------------------------------------------------------
   (tar-oct s o n)                          ; octal digits until a non-digit
    (: (go i a) (n <= i ? a (s (o + i) @ c (48 <= c < 56 ? (go (i + 1) (a * 8 + c - 48)) a))) (go 0 0))
   (tar-txt s o n)                          ; a NUL-ended text field
    (: (go i) (? (n <= i) i (s (o + i) = 0) i (go (i + 1))) k (go 0)
     (!k ? "" (cask k @ c (pour c 0 s o k, string c))))

   ; --- entries --------------------------------------------------------------
   (tar-entry nom kind body)
    {'nom nom 'kind kind 'body (body + "") 'to "" 'mode (kind @ 'dir 493 420)
     'mtime 0 'uid 0 'gid 0 'uname "root" 'gname "root"}
   ; peep's own default is the presence test here -- it answers d only when the key is
   ; absent, so an entry whose 'body is legitimately "" keeps its "". not `lit?`,
   ; which asks whether a name is bound and reads it.
   tar-get peep

   ; --- the name split -------------------------------------------------------
   ; ustar joins prefix and name with a "/" it does not store, so the split must fall
   ; on a separator. we take the longest prefix under 156 that leaves a name under 101
   ; -- longest, because it is the tail that is tight.
   (tar-split m)                          ; -> (prefix name) | ()
    (: n #m
     (n < 101 ? ["" m]
      (: (go i best) (n <= i ? best (go (i + 1) (m i = 47 && i < 156 && n - i - 1 < 101 ? i best)))
         k (go 0 -1)
       (k >= 0 ? (: p (cask k)
                    q (pour p 0 m 0 k, cask (n - k - 1))
        (pour q 0 m (k + 1) (n - k - 1),
         [(string p) (string q)]))))))

   ; inle/hash.c's streaming state: 105 bytes, opaque, allocated here because the
   ; nifs do not allocate -- they fold into a cask the caller owns.
   tar-shast 105

   ; --- writing --------------------------------------------------------------
   (tar-kindc k) (k @ 'dir 53 'link 50 48)   ; '5' '2' '0'
   (tar-head e)                             ; -> the 512-byte header | ()
    (: n (tar-get e 'nom "")
       kind (tar-get e 'kind 'file)
       n2 (kind @- n 'dir (n || "/"))
       sp (tar-split n2)
       (? !sp ()
          (: b (cask tar-blk)
             body (tar-get e 'body "")
           (tar-txt! b 0 100 (<(>sp)),                    ; name
            tar-oct! b 100 8 (tar-get e 'mode 420),
            tar-oct! b 108 8 (tar-get e 'uid 0),
            tar-oct! b 116 8 (tar-get e 'gid 0),
             ; the size comes off 'size when the entry carries one -- a thin entry
             ; (tar-thin?) knows its length without holding its bytes. no 'size and
             ; it is the body's tally, which is every fat entry, unchanged.
            tar-oct! b 124 12 (kind @- 0 'file (tar-get e 'size #body)),
            tar-oct! b 136 12 (tar-get e 'mtime 0),
            pin b 156 (tar-kindc kind),
            tar-txt! b 157 100 (tar-get e 'to ""),
            tar-txt! b 257 6 "ustar",                     ; magic, NUL-ended
            pins b 263 48 264 48,                ; version "00", not NUL-ended
            tar-txt! b 265 32 (tar-get e 'uname "root"),
            tar-txt! b 297 32 (tar-get e 'gname "root"),
            tar-oct! b 329 8 0, tar-oct! b 337 8 0,    ; devmajor/minor
            tar-txt! b 345 155 <sp,                     ; prefix
             ; the checksum last -- it sums the block it sits in, so every other
             ; field must already be written. six digits, NUL, space.
            tar-oct! b 148 7 (tar-sum b),
            pin b 154 32,
            string b))))
   ; --- the archive as a stream ----------------------------------------------
   ; tar-pack's answer exists to be looked at once and dropped, and for a source tree
   ; that is megabytes held to be hashed. tar-hash is the same archive fed through a
   ; resumable sha-256 (inle/hash.c) a bufferful at a time: the header, then the file's
   ; bytes read straight off 'path, then the pad -- so the peak is one cask and not one
   ; archive. It answers what (sha256 (tar-pack es)) answers, and test/gate/targz.sh
   ; holds the two together over a tree with the awkward shapes in it.
   ; it reads what the header says. a file that moved between the walk's stat and
   ; this read would put a body of one length under a header of another, so a short
   ; read is a torn archive and answers () -- the caller cuts the fat way, which reads
   ; each file once and cannot disagree with itself.
   ; `snip` reads the cask, and it must: (snip (string buf) 0 k) copies the whole
   ; buffer to take the corner a read filled -- 64K for a 12-byte file, and over a
   ; source tree more copying than the archive it is hashing.
   (tar-feed h buf e)                       ; feed one file's body + pad; 1 | ()
    (? !(string? (tar-get e 'path ()))      ; a fat entry, no file behind it
       (: b (tar-get e 'body "")
          _ (sha256-feed h b)
          r (#b % tar-blk)
          (? r (sha256-feed h * string * cask $ tar-blk - r) 0)
          1)
    (: n (tar-get e 'size 0)
       q (? (0 < n) (open (tar-get e 'path "") "r") 0)
       (? (0 = n) 1
          !(hot? q) ()
          (: (go left) (left @ 0 1
                        (: k (swig q buf)
                         (? !(charm? k && 0 < k) ()
                          (: k2 (? (left < k) left k)
                             _ (sha256-feed h (snip buf 0 k2))
                           (go (left - k2))))))
             ok (go n)
             _ (close q)
             (ok && (: r (n % tar-blk) (r && sha256-feed h * string * cask $ tar-blk - r, 1)))))))
   (tar-hash es)                            ; -> the 64-char digest | ()
    (: h (cask tar-shast)
       _ (sha256-init h)
       buf (cask 65536)
       (go xs) (? (atom? xs) 1
                  (: e <xs
                     hd (tar-head e)
                     (? !hd ()
                        (: _ (sha256-feed h hd)
                           ok (? (= (tar-get e 'kind 'file) 'file) (tar-feed h buf e) 1)
                           (ok && go >xs)))))
       (go es ? (sha256-feed h (string (cask (tar-blk * 2))),
                 sha256-done h)))

   (tar-pad s) (s + zbytes (padk #s tar-blk))  ; up to the next 512
   (tar-pack es)
    (:- (go es ? (say j (string (cask (tar-blk * 2))), (slurp j) + ""))
     j (jug 0)
     (go xs)
      (xs @- 1 (e . u)
       (: h (tar-head e) (? h
        (say j h,
         tar-get e 'kind 'file = 'file ?
          (tar-get e 'body "" @ body (#body && say j (tar-pad body))),
         go u)))))

   ; --- reading --------------------------------------------------------------
   (tar-zero? s o)                          ; is the block at o all zeros?
    (: (go i) (? (tar-blk <= i) 1 (s (o + i) = 0) (go (i + 1)) 0) (go 0))
   (tar-read1 s n o)                        ; -> (1 entry next) | () | 'end
    (? (tar-zero? s o) 'end
       (: b (cask tar-blk) _ (pour b 0 s o tar-blk)
          got (tar-sum b)
          want (tar-oct s (o + 148) 8)
          (? (got != want) ()
             (: name (tar-txt s o 100)
                pre (tar-txt s (o + 345) 155)
                nom (#pre ? (pre + "/" + name) name)
                tc (s (o + 156))
                kind (tc @ 53 'dir (50 || 49) 'link 'file)   ; '5' '2'/'1'
                sz (kind == 'file && tar-oct s (o + 124) 12)
                ; a member whose body runs past the end of the bytes we were handed
                ; is a truncated archive, and the size field is where that shows.
                (n < o + tar-blk + sz ? ()
                   (: e {
                      'nom nom 'kind kind
                      'mode (tar-oct s (o + 100) 8)
                      'uid (tar-oct s (o + 108) 8)
                      'gid (tar-oct s (o + 116) 8)
                      'mtime (tar-oct s (o + 136) 12)
                      'to (tar-txt s (o + 157) 100)
                      'uname (tar-txt s (o + 265) 32)
                      'gname (tar-txt s (o + 297) 32)
                      'body (!sz ? "" (cask sz @ c (pour c 0 s (o + tar-blk) sz, string c)))}
                      blocks (sz && tar-blk * ((sz + tar-blk - 1) // tar-blk))
                      [1 e (o + tar-blk + blocks)]))))))
   ; an archive ends at its zero block, never at the end of the bytes. Running
   ; out of input mid-walk is torn, not a clean finish -- a truncated download that
   ; answered the members it happened to contain would extract half a tree in
   ; silence, which is worse than extracting none. (Trailing padding past the zero
   ; block is fine: the walk has already stopped by then.)
   (tar-unpack s)
    (:- (go 0 ())
     n #s
     (go o acc) (n - o >= tar-blk ?
                 (: r (tar-read1 s n o)
                  (? (r == 'end) [1 (rev acc)]
                      r (go <>>r (<(>r) . acc))))))

   ; --- the filesystem, in and out -------------------------------------------
   ; a walk answers paths relative to root and stores them that way: an archive
   ; carrying "/home/gwen/..." is one that unpacks over somebody's system. tar's own
   ; "removing leading /" warning exists because the naive spelling does that.
   (tar-join a b) (? #a (a + "/" + b) b)
   ; stat answers (size mtime-ms mode mtime-ns), and its mtime is milliseconds where
   ; tar's field is seconds. it follows a symlink -- there is no lstat here -- so the
   ; link test is readlink, which answers the target for one and nothing for anything
   ; else. Without that test a tree of symlinks archives as copies of its own files.
   (tar-mode st) (4095 & <>>st)
   (tar-dir? st) (61440 & <>>st = 16384)
   (tar-secs st) (<>st // 1000)
   ; the pruned walk: `keep` is asked with each child's rel nom before the walk
   ; descends or slurps, so what the caller will not carry is never read -- a
   ; build tree's out/ is gigabytes the archive was never going to hold.
   (tar-gather? keep root rel) (tar-walk? keep root rel 1)
   ; the thin walk: the same walk that reads no file. each file entry carries its
   ; 'size (off stat) and its 'path (where the bytes are) instead of its body, which
   ; is what lets a caller hash or write the archive as a stream -- the fat walk holds
   ; every byte of the tree at once, and a tree is megabytes that exist to be read
   ; through once. 'path is this machine's and rides no header; tar-head reads
   ; neither key but 'size, so a thin entry heads exactly as its fat twin does.
   (tar-thin? keep root rel) (tar-walk? keep root rel 0)
   (tar-walk? keep root rel fat)            ; -> (1 entries) | ()
    (: full (? #rel (root + "/" + rel) root)
       lnk (readlink full)
       st (stat full)
       (? (string? lnk)
          (: e (tar-entry rel 'link "")
             _ (pins e 'to lnk 'mode 511)
             _ (? (two? st) (pin e 'mtime (tar-secs st)) 0)
             ; the inner ` is load-bearing: `(1 (e)) would apply e to nothing, and
             ; (f) == f, so the caller would take a bare entry for a list of them.
             [1 [e]])
          (one? st) ()
          (tar-dir? st)
          (: e (tar-entry (? (tally rel) rel ".") 'dir "")
             _ (pins e 'mode (tar-mode st) 'mtime (tar-secs st))
             ; sorted, so an archive of the same tree is the same bytes -- readdir's
             ; order is the filesystem's and varies between two boxes holding one tree.
             kids (sort (readdir full))
             (go ks acc) (one? ks ? [1 (rev acc)]
                          (: k2 (tar-join rel <ks)
                           (!(keep k2) ? (go >ks acc)
                            (: r (tar-walk? keep root k2 fat)
                             (r && go >ks (foldl (flip cons) acc <>r))))))
             r (go kids ())
             (r ? [1 (e . <>r)]))
          !fat
          (: e (tar-entry rel 'file "")
             _ (pins e 'mode (tar-mode st) 'mtime (tar-secs st)
                       'size <st           'path full)
             [1 [e]])
          (: b (uread full)
             (b ?
                (: e (tar-entry rel 'file (<(>b)))
                   _ (pins e 'mode (tar-mode st) 'mtime (tar-secs st))
                   ; the inner ` is load-bearing: `(1 (e)) would apply e to nothing, and
             ; (f) == f, so the caller would take a bare entry for a list of them.
             [1 [e]])))))
   (tar-gather root rel) (tar-gather? 0 root rel)
   ; `mkdir` is dyadic (path, mode). At one operand it hands back a closure and makes
   ; no directory -- (f x) curries, it does not default -- and the closure is truthy, so
   ; the miss is silent at every call site that tests it.
   ; and neither primitive answers its own success: mkdir and symlink both return the
   ; zero point when they worked. So each write is checked by looking -- stat for a dir
   ; or a file, readlink for a link. The presence law from the other side: the value
   ; cannot say, so ask out of band.
   tar-there? (two? * stat)
   (tar-strip nom)                          ; the "./" GNU tar stores on a `-C dir .`
    (#nom > 1 && nom 0 = 46 && nom 1 = 47 ? (snip nom 2 #nom) nom)
   ; a release tarball must not carry the clock or the packer's uid. Two cuts of
   ; one tree would hash differently, and "this is that release" stops being a thing
   ; anyone can check. mtime, uid and gid drift with who ran the pack and when -- and
   ; so does the mode, for the same reason: `mkdir` and `open` wear the packer's
   ; umask, so one tree cut under 022 and under 077 disagrees in every directory.
   ; Only the x bit of it is content (a binary that unpacks unrunnable is a broken
   ; artifact), so that is the half kept and the rest is spelled canonically.
   (tar-canon e) (tar-get e 'kind 'file @ 'link 511 'dir 493
                  (tar-get e 'mode 420 & 73 > 0 ? 493 420))
   (tar-level es stamp)
    (map (e \ pins (foldl (t \ k \ pin t k (e k)) {} (keys e))
              'mtime stamp 'uid 0 'gid 0
              'uname "root" 'gname "root" 'mode (tar-canon e))
         es)
   (tar-scatter root es)                    ; -> (1 count) | ()
    (:- (go es 0) (go xs k)
     (one? xs ? [1 k]
      (: e <xs
         nom (tar-strip (tar-get e 'nom ""))
         p (? #nom (? #root (root + "/" + nom) nom) root)
         kind (tar-get e 'kind 'file)
         ; the mode is content, and it must be laid back explicitly: `open`
         ; and `mkdir` both create at the umask's pleasure, so a file written
         ; here comes out 0644 whatever the header said, an extracted binary is
         ; not executable, and under 077 every directory lands 0700. The archive
         ; carried the mode and we dropped it -- which `diff -r` cannot see,
         ; because it compares bytes and not modes. chmod is the only door: it
         ; is the one call the umask does not touch.
         ok (? (kind == 'dir)  (mkdir p (tar-get e 'mode 493),
                                tar-there? p && chmod p (tar-get e 'mode 493),
                                tar-there? p)
               (kind == 'link) (symlink (tar-get e 'to "") p,
                                string? (readlink p))
               (uwrite p (tar-get e 'body ""),
                tar-there? p && chmod p (tar-get e 'mode 420),
                tar-there? p))
       (ok && go >xs (k + 1))))))) ; module 'tar

; --- the face -----------------------------------------------------------------------
; `love tar`, GNU tar's spelling over the module above: the bundled key (czf), dashed
; letters (-c -z -f A, -czfA) and the long names, in any mix.
;
;   tar {c|x|t}[v][z|j|J|a] [-f ARCHIVE] [-C DIR] [-O] [--strip-components=N] [MEMBER..]
;
; c packs each MEMBER as named, relative to -C; x and t take the members to pick, a
; directory naming all it holds. ARCHIVE `-` or none is stdin/stdout. z gzip, j bzip2
; (apps/bz2.l), J xz (apps/xz.l); a read that names none sniffs the magic, and a
; create under -a picks by the archive's suffix. bz2 and xz are reached at the call:
; the path-loaded tools (selfpack, mkrootfs) take tar with gz alone. statuses as
; GNU's: 0, 2 a failure.
;
; the module wrap is not decoration: `borrow` splices a module's names into the current
; layer, so unwrapped these two asks would put tar's and gz's names on the dist cat's
; shared layer.
(module 'tarcmd
(borrow 'gz)
(borrow 'tar)

(borrow 'posix)
(: (tarc-die m) (udie 2 ("tar: " + m))
   (tarc-warn m) (say err ("tar: " + m + "\n"), flush err)
   (tarc-ends? s x) (: n #s m #x (m <= n && snip s (n - m) n = x))
   (tarc-lazy m f what) (: b (cite m f) (lit? b ? b (tarc-die ("no " + what + " aboard"))))

   ; --- the codecs: 'z 'j 'J, and () for a bare tar ---------------------------------
   (tarc-zip z a) (z @ 'z (gz-zip a "" 0)
                       'j ((tarc-lazy 'bz2 'bz2-pack "bzip2") a 9)
                       'J ((tarc-lazy 'xz 'xz-pack "xz") a 8388608 'crc64)
                       a)
   (tarc-unzip z b)                    ; -> (1 bytes) | ()
    (z @ 'z (gz-unzip b)
         'j (: v ((tarc-lazy 'bz2 'bz2-unpack "bzip2") b) (two? v && v))
         'J (: v ((tarc-lazy 'xz 'xz-unpack "xz") b) (two? v && v))
         [1 b])
   (tarc-sniff b)
    (? (2 <= #b && b 0 = 31 && b 1 = 139) 'z
       (4 <= #b && snip b 0 3 = "BZh") 'j
       (6 <= #b && b 0 = 253 && snip b 1 5 = "7zXZ" && b 5 = 0) 'J
       ())
   (tarc-bysuf p)
    (? (tarc-ends? p ".gz" || tarc-ends? p ".tgz" || tarc-ends? p ".taz") 'z
       (tarc-ends? p ".bz2" || tarc-ends? p ".tbz" || tarc-ends? p ".tbz2" || tarc-ends? p ".tb2") 'j
       (tarc-ends? p ".xz" || tarc-ends? p ".txz") 'J
       ())
   (tarc-zname z) (z @ 'z "gzip" 'j "bzip2" "xz")

   ; --- the flags ----------------------------------------------------------------
   ; each letter's rows: what it pins, and 'arg for the two that take a word
   tarc-letters [[99 'mode 'c] [120 'mode 'x] [116 'mode 't] [122 'z 'z] [106 'z 'j]
                 [74 'z 'J] [97 'auto 1] [118 'v 1] [79 'O 1] [102 'f 'arg] [67 'C 'arg]]
   tarc-longs [["create" 'mode 'c] ["extract" 'mode 'x] ["get" 'mode 'x] ["list" 'mode 't]
               ["gzip" 'z 'z] ["gunzip" 'z 'z] ["ungzip" 'z 'z] ["bzip2" 'z 'j] ["xz" 'z 'J]
               ["auto-compress" 'auto 1] ["verbose" 'v 1] ["to-stdout" 'O 1]
               ["file" 'f 'arg] ["directory" 'C 'arg] ["strip-components" 'strip 'arg]]
   (tarc-row k rows) (: (go l) (? !(two? l) () (<<l = k) <l (go >l)) (go rows))
   (tarc-set t row v) (pin t (row 1) (? (row 2 = 'arg) v (row 2)))
   ; one letter cluster -> the words left; `wait` the arg-takers' words still owed, the
   ; bundled key's way: czf A takes A for f after the cluster, -fA and -f A the dashed way
   (tarc-cluster t w k dash rest)
    (? (#w <= k) rest
       (: row (tarc-row (w k) tarc-letters)
          (? !row (tarc-die ("invalid option -- '" + string (w k) + "'"))
             !(row 2 = 'arg) (: _ (tarc-set t row 0) (tarc-cluster t w (k + 1) dash rest))
             (dash && k + 1 < #w) (: _ (tarc-set t row (snip w (k + 1) #w)) rest)
             !(two? rest) (tarc-die ("option requires an argument -- '" + string (w k) + "'"))
             (: _ (tarc-set t row <rest) (tarc-cluster t w (k + 1) dash >rest)))))
   (tarc-long t w rest)                ; --name, --name=V, --name V -> the words left
    (: eq (: (go k) (? (#w <= k) () (w k = 61) k (go (k + 1))) (go 0))
       nm (? eq (snip w 0 eq) w)
       row (tarc-row nm tarc-longs)
       (? !row (tarc-die ("unrecognized option '--" + w + "'"))
          !(row 2 = 'arg) (: _ (tarc-set t row 0) rest)
          eq (: _ (tarc-set t row (snip w (eq + 1) #w)) rest)
          !(two? rest) (tarc-die ("option '--" + nm + "' requires an argument"))
          (: _ (tarc-set t row <rest) >rest)))
   (tarc-opts t as)                    ; the bundled key first, then anything in any order
    (: (go l mem)
        (? !(two? l) (pin t 'mem (rev mem))
           (: w <l
              (? (w = "--") (pin t 'mem (rev mem + >l))
                 (2 < #w && w 0 = 45 && w 1 = 45) (go (tarc-long t (snip w 2 #w) >l) mem)
                 (1 < #w && w 0 = 45) (go (tarc-cluster t w 1 1 >l) mem)
                 (go >l (w . mem)))))
       (? (two? as && 0 < #<as && !(<as 0 = 45))
          (go (tarc-cluster t <as 0 0 >as) ())
          (go as ())))

   ; --- the members --------------------------------------------------------------
   (tarc-trim p) (? (1 < #p && p (#p - 1) = 47) (tarc-trim (snip p 0 (#p - 1))) p)
   (tarc-nom e) (tarc-trim (tar-strip (tar-get e 'nom "")))
   (tarc-has? nom m) (: m2 (tarc-trim (tar-strip m))
                        (nom = m2 || (#m2 < #nom && snip nom 0 (#m2 + 1) = m2 + "/")))
   ; --strip-components: the first n segments off, a member with no more dropped
   (tarc-cut nom n) (? (n < 1) nom
                       (: (go k) (? (#nom <= k) () (nom k = 47) (tarc-cut (snip nom (k + 1) #nom) (n - 1)) (go (k + 1)))
                          (go 0)))
   (tarc-pick t es)
    (: ms (peep t 'mem ())
       n (tarc-num (peep t 'strip ""))
       picked (? !(two? ms) es (filter (e \ any (m \ tarc-has? (tarc-nom e) m) ms) es))
       _ (each ms (m \ (? (any (e \ tarc-has? (tarc-nom e) m) es) 0
                          (: _ (tarc-warn (m + ": Not found in archive")) (pin t 'bad 1)))))
       cut (map (e \ (: c (tarc-cut (tarc-nom e) n) (? (c && 0 < #c) (pin (tarc-copy e) 'nom c) ()))) picked)
       (filter (e \ !(nil? e)) cut))
   (tarc-num s) (: (go k v) (? (#s <= k) v (s k < 48 || 57 < s k) (tarc-die ("invalid number: " + s))
                                (go (k + 1) (v * 10 + s k - 48)))
                   (go 0 0))
   (tarc-copy e) (foldl (\ c k (pin c k (e k))) {} (keys e))

   ; --- the long listing: GNU's columns, the clock in UTC ------------------------------
   (tarc-p2 v) (? (v < 10) ("0" + show v) (show v))
   (tarc-civil z)                      ; days since 1970 -> (y m d)
    (: z2 (z + 719468)
       era (? (0 <= z2) (z2 // 146097) ((z2 - 146096) // 146097))
       doe (z2 - era * 146097)
       yoe ((doe - doe // 1460 + doe // 36524 - doe // 146096) // 365)
       doy (doe - (365 * yoe + yoe // 4 - yoe // 100))
       mp ((5 * doy + 2) // 153)
       d (doy - (153 * mp + 2) // 5 + 1)
       m (? (mp < 10) (mp + 3) (mp - 9))
       [(yoe + era * 400 + (? (m <= 2) 1 0)) m d])
   (tarc-date s) (: c (tarc-civil (s // 86400)) r (s % 86400)
                    (show <c + "-" + tarc-p2 <>c + "-" + tarc-p2 <>>c + " "
                     + tarc-p2 (r // 3600) + ":" + tarc-p2 (r % 3600 // 60)))
   (tarc-perm e)
    (: md (tar-get e 'mode 420)
       (bit b c) (? (0 < (md & b)) c "-")
       ((tar-get e 'kind 'file @ 'dir "d" 'link "l" "-")
        + bit 256 "r" + bit 128 "w" + bit 64 "x" + bit 32 "r" + bit 16 "w" + bit 8 "x"
        + bit 4 "r" + bit 2 "w" + bit 1 "x"))
   (tarc-lpad w s) (? (w <= #s) s (tarc-lpad w (" " + s)))
   (tarc-longline e)
    (: un (tar-get e 'uname "") gn (tar-get e 'gname "")
       og ((? #un un (show (tar-get e 'uid 0))) + "/" + (? #gn gn (show (tar-get e 'gid 0))))
       sz (show (? (tar-get e 'kind 'file = 'file) #(tar-get e 'body "") 0))
       nom (tar-get e 'nom "")
       (tarc-perm e + " " + og + " " + tarc-lpad (18 - #og) sz + " "
        + tarc-date (tar-get e 'mtime 0) + " " + nom
        + (? (tar-get e 'kind 'file = 'link) (" -> " + tar-get e 'to "") "")))

   ; --- the three modes ------------------------------------------------------------
   (tarc-arch t) (peep t 'f "-")
   ; where the names -v says go: stdout, unless the archive is going there
   (tarc-tell t s) (: o (? (peep t 'mode 'c = 'c && tarc-arch t = "-") err out)
                      (say o (s + "\n")))
   (tarc-c t)
    (: ops (peep t 'mem ())
       _ (!(two? ops) && tarc-die "Cowardly refusing to create an empty archive")
       a (tarc-arch t)
       _ (a = "-" && two? (tty out) && tarc-die "Refusing to write archive contents to terminal (missing -f option?)")
       root (peep t 'C "")
       ; each member as named: a leading / comes off, as GNU takes it off, and says so
       (one p)
        (: p2 (tarc-trim p)
           abs (0 < #p2 && p2 0 = 47)
           rel (: (go k) (? (k < #p2 && p2 k = 47) (go (k + 1)) (snip p2 k #p2)) (go 0))
           _ (abs && !(peep t 'slash 0) && (: _ (pin t 'slash 1) (tarc-warn "Removing leading `/' from member names")))
           g (tar-gather (? abs "/" (? #root root ".")) (? (abs && !#rel) "." rel))
           (? g <>g (: _ (tarc-warn (p + ": Cannot stat: No such file or directory")) _ (pin t 'bad 1) ())))
       es (foldl (\ acc p (acc + one p)) () ops)
       _ (peep t 'v 0 && each es (e \ tarc-tell t (tar-get e 'nom "")))
       ar (tar-pack es)
       _ (!ar && tarc-die "cannot pack (a path too long for ustar?)")
       z (? (peep t 'z ()) (peep t 'z ()) (peep t 'auto 0) (tarc-bysuf a) ())
       b (tarc-zip z ar)
       _ (? (a = "-") (: _ (say out b) (flush out))
            (uwrite a b) 0
            (tarc-die (a + ": Cannot open")))
       (peep t 'bad 0 ? 2 0))

   ; each read is guarded on its own so the message names the step: "not a gzip" and
   ; "not a tar" are different repairs, and one "cannot read" sends you to the wrong one.
   (tarc-open t)
    (: a (tarc-arch t)
       _ (a = "-" && two? (tty in) && tarc-die "Refusing to read archive contents from terminal (missing -f option?)")
       b (? (a = "-") [1 (slurp in + "")] (uread a))
       _ (!b && tarc-die (a + ": Cannot open: No such file or directory"))
       z (: w (peep t 'z ()) (? w w (tarc-sniff <>b)))
       u (tarc-unzip z <>b)
       _ (!u && tarc-die (a + ": not a " + tarc-zname z + " stream, or its check disagrees"))
       r (tar-unpack <>u)
       _ (!r && tarc-die (a + ": not a tar archive, or it is truncated"))
       <>r)
   ; the directories a member lies under, laid first: an archive need not carry them
   (tarc-parents root es)
    (each es (e \ (: nom (tarc-nom e)
                     (go k) (? (#nom <= k) 0
                               (nom k = 47) (: d (root + "/" + snip nom 0 k)
                                               _ (? (two? (stat d)) 0 (mkdir d 493))
                                               (go (k + 1)))
                               (go (k + 1)))
                     (go 1))))
   (tarc-x t)
    (: es (tarc-pick t (tarc-open t))
       root (peep t 'C ".")
       _ (peep t 'v 0 && each es (e \ tarc-tell t (tar-get e 'nom "")))
       (? (peep t 'O 0)
          (: _ (each es (e \ (? (tar-get e 'kind 'file = 'file) (say out (tar-get e 'body "")) 0)))
             _ (flush out)
             (peep t 'bad 0 ? 2 0))
          (: _ (tarc-parents root es)
             w (tar-scatter root es)
             _ (!w && tarc-die ("cannot write under " + root))
             (peep t 'bad 0 ? 2 0))))
   (tarc-t t)
    (: es (tarc-pick t (tarc-open t))
       _ (each es (e \ say out ((? (peep t 'v 0) (tarc-longline e) (tar-get e 'nom "")) + "\n")))
       _ (flush out)
       (peep t 'bad 0 ? 2 0))

   usage "usage: tar {c|x|t}[vzjJaO] [-f ARCHIVE] [-C DIR] [--strip-components=N] [MEMBER..]"
   (tar-main av)
    (: t (tablet 0)
       _ (tarc-opts t av)
       (peep t 'mode () @ 'c (tarc-c t) 'x (tarc-x t) 't (tarc-t t)
         (tarc-die "You must specify one of the '-ctx' options")))

   T (cite 'verbs 'tab)
   _ (pins T 'tar (udoor 'tar (urun tar-main) usage 1 1)))

) ; module 'tarcmd
