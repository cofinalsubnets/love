; src/apps/tar.l -- ustar, read and written. `(borrow 'tar)`, then:
;   (tar-pack entries)     -> the archive bytes
;   (tar-unpack s)         -> (1 entries) | ()
;   (tar-gather root path) -> (1 entries) | ()
;   (tar-scatter root es)  -> (1 count) | ()
;   (tar-scatter? warn root es) -> (1 count refused)
;   (tar-walk s f)         -> (1 count) | () | 'stop  members off a stream, (tar-src rd)
;   (tar-put warn root e fill) -> 1 | 0 | 'fail
; an entry is a tablet: 'nom (relative) 'kind 'file|'dir|'link 'body 'to 'mode 'mtime 'uid
; 'gid 'uname 'gname. reads answer (1 _): an empty archive nets nothing, test with two?.
; numeric fields are octal ascii; the checksum sums the header with its own field as spaces.
(module 'tar
(borrow 'posix)
(borrow 'bytes)
(borrow 'hashes)
(:
   tar-blk 512

   (tar-oct! b o n v)
    (: (go i x) (i >= 0 ? (pin b (o + i) (48 + (x & 7)), go (i - 1) (x >> 3)))
     (pin b (o + n - 1) 0, go (n - 2) v))
   (tar-txt! b o n s)                       ; a text field, NUL-filled, never overrun
    (: k #s (go i) (n > i ? (pin b (o + i) (i < k ? (s i) 0), go (i + 1))) (go 0))
   (tar-sum b)                              ; the header checksum, own field as spaces
    (foldl (\ a i (a + (148 <= i < 156 ? 32 (peep b i 0)))) 0 ^tar-blk)

   ; --- the field peeks ---
   (tar-oct s o n) (rdoct s o n)            ; octal digits until a non-digit
   (tar-txt s o n)                          ; a NUL-ended text field
    (: (go i) (? (n <= i) i (s (o + i) = 0) i (go (i + 1))) k (go 0)
     (!k ? "" (cask k @ c (pour c 0 s o k, string c))))

   ; --- entries ---
   (tar-entry nom kind body)
    {'nom nom 'kind kind 'body (body + "") 'to "" 'mode (kind @ 'dir 493 420)
     'mtime 0 'uid 0 'gid 0 'uname "root" 'gname "root"}
   ; peep's default answers only for an absent key, so a 'body of "" stays ""
   tar-get peep

   ; --- the name split ---
   ; the "/" between prefix and name is not stored, so the split falls on a separator;
   ; the longest prefix, because the name field is the tight one
   (tar-split m)                          ; -> (prefix name) | ()
    (#m @ n
     (n < 101 ? ["" m]
      (: k (foldl (\ best i (m i = 47 && i < 156 && n - i - 1 < 101 ? i best)) -1 ^n)
       (k >= 0 ? (: p (cask k)
                    q (pour p 0 m 0 k, cask (n - k - 1))
        (pour q 0 m (k + 1) (n - k - 1),
         [(string p) (string q)]))))))

   ; hash.c's streaming state, in a cask the caller owns (nifs do not allocate)
   tar-shast 105

   ; --- writing ---
   (tar-kindc k) (k @ 'dir 53 'link 50 48)   ; '5' '2' '0'
   (tar-head e)                             ; -> the 512-byte header | ()
    (: n (tar-get e 'nom "")
       kind (tar-get e 'kind 'file)
       n2 (kind @- n 'dir (n || "/"))
       sp (tar-split n2)
       (!sp ? ()
          (: b (cask tar-blk)
             body (tar-get e 'body "")
           (tar-txt! b 0 100 (<(>sp)),
            tar-oct! b 100 8 (tar-get e 'mode 420),
            tar-oct! b 108 8 (tar-get e 'uid 0),
            tar-oct! b 116 8 (tar-get e 'gid 0),
             ; a thin entry carries 'size without its bytes
            tar-oct! b 124 12 (kind @- 0 'file (tar-get e 'size #body)),
            tar-oct! b 136 12 (tar-get e 'mtime 0),
            pin b 156 (tar-kindc kind),
            tar-txt! b 157 100 (tar-get e 'to ""),
            tar-txt! b 257 6 "ustar",
            pins b 263 48 264 48,                ; version "00", not NUL-ended
            tar-txt! b 265 32 (tar-get e 'uname "root"),
            tar-txt! b 297 32 (tar-get e 'gname "root"),
            tar-oct! b 329 8 0, tar-oct! b 337 8 0,
            tar-txt! b 345 155 <sp,
             ; the checksum last: it sums the block it sits in
            tar-oct! b 148 7 (tar-sum b),
            pin b 154 32,
            string b))))
   ; --- the archive as a stream ---
   ; tar-emit is tar-pack through put a bufferful at a time, so the peak is one cask, not one
   ; archive; tar-hash answers what (sha256 (tar-pack es)) answers. a short read means the
   ; file changed since its stat, a torn archive: ().
   ; snip the cask, not (string buf): that copies all 64K per read.
   (tar-feed put buf e)                     ; one file's body + pad through put; 1 | ()
    (!(string? (tar-get e 'path ())) ?
       (: b (tar-get e 'body "")
          _ (put b)
          r (#b % tar-blk)
          ((r ? (put * string * cask $ tar-blk - r) 0),
           1))
    (: n (tar-get e 'size 0)
       q (0 < n ? (open (tar-get e 'path "") "r") 0)
       (? (0 = n) 1
          !(hot? q) ()
          (: (go left) (left @ 0 1
                        (swig q buf @ k
                         (!(charm? k && 0 < k) ? ()
                          (: k2 (left < k ? left k)
                             (put (snip buf 0 k2),
                              go (left - k2))))))
             ok (go n)
             (close q,
              ok && (n % tar-blk @ r (r && put * string * cask $ tar-blk - r, 1)))))))
   (tar-emit es put)                        ; -> 1 | () a path too long, or a file torn
    (: buf (cask 65536)
       (go xs) (atom? xs ? 1
                  (: e <xs
                     hd (tar-head e)
                     (!hd ? ()
                        (: _ (put hd)
                           ok (tar-get e 'kind 'file = 'file ? (tar-feed put buf e) 1)
                           (ok && go >xs)))))
       (go es ? (put (string (cask (tar-blk * 2))), 1)))
   (tar-hash es)                            ; -> the 64-char digest | ()
    (: h (cask tar-shast)
       _ (sha256-init h)
       (tar-emit es (sha256-feed h) ? (sha256-done h) ()))

   (tar-pad s) (s + zbytes (padk #s tar-blk))  ; up to the next 512
   (tar-pack es)
    (:- (go es ? (say j (string (cask (tar-blk * 2))), (slurp j) + ""))
     j (jug 0)
     (go xs)
      (xs @- 1 (e . u)
       (tar-head e @ h (h ?
      (say j h,
       tar-get e 'kind 'file @ 'file
        (tar-get e 'body "" @ body (#body && say j (tar-pad body))),
       go u)))))

   ; --- reading ---
   (tar-zero? s o)
    (: (go i) (? (tar-blk <= i) 1 (s (o + i) = 0) (go (i + 1)) 0) (go 0))
   ; one header block, its body not read: -> (1 entry size) | () where the sum disagrees
   (tar-hdr h)
    (cask tar-blk @ b (pour b 0 h 0 tar-blk,
                       (tar-sum b != tar-oct h 148 8 ? ()
                          (: name (tar-txt h 0 100)
                             pre (tar-txt h 345 155)
                             nom (#pre ? (pre + "/" + name) name)
                             tc (h 156)
                             ; '5' '2'/'1', and 'g' a pax global header: what packed it, read past
                             kind (tc @ 53 'dir (50 || 49) 'link 103 'global 'file)
                             sz ((kind == 'file || kind == 'global) && tar-oct h 124 12)
                             [1 {'nom nom 'kind kind
                                 'mode (tar-oct h 100 8)
                                 'uid (tar-oct h 108 8)
                                 'gid (tar-oct h 116 8)
                                 'mtime (tar-oct h 136 12)
                                 'to (tar-txt h 157 100)
                                 'uname (tar-txt h 265 32)
                                 'gname (tar-txt h 297 32)}
                              sz]))))
   (tar-read1 s n o)                        ; -> (1 entry next) | () | 'end
    (tar-zero? s o ? 'end
       (: r (tar-hdr (snip s o (o + tar-blk)))   e (r && r 1)   sz (r && r 2)
          ; a body running past the bytes handed in is a truncated archive
          (!r || n < o + tar-blk + sz ? ()
             (: _ (pin e 'body (!sz ? "" (cask sz @ c (pour c 0 s (o + tar-blk) sz, string c))))
                blocks (sz && tar-blk * ((sz + tar-blk - 1) // tar-blk))
                [1 e (o + tar-blk + blocks)]))))
   ; an archive ends at its zero block: running out of input first is torn, not a finish,
   ; so a truncated download extracts nothing rather than half a tree
   (tar-unpack s)
    (:- (go 0 ())
     n #s
     (go o acc) (n - o >= tar-blk ?
                 (tar-read1 s n o @ r
                  (? (r == 'end) [1 (rev acc)]
                      r (go <>>r (tar-get <(>r) 'kind 'file @ 'global acc (<>r . acc)))))))

   ; --- reading off a stream ---
   ; a source is a reader rd (rd _ the next piece, "" at the end) behind a buffer
   ;   (tar-take s n)    n bytes, fewer only where the input ends
   ;   (tar-peek s n)    the same, left where it was
   ;   (tar-pour s n wr) n bytes through wr -> how many went
   ;   (tar-rd s)        the source a reader again
   (tar-src rd) {'rd rd 'b "" 'o 0}
   (tar-take s n)
    (: b (peep s 'b "")   o (peep s 'o 0)
       (n <= #b - o ? (pin s 'o (o + n), snip b o (o + n))
          (: (fill acc have) (n <= have ? acc
                                (peep s 'rd () 0 @ p (#p = 0 ? acc (fill (p . acc) (have + #p)))))
             all (cats (snip b o #b . rev (fill () (#b - o))))
             (#all <= n ? (pins s 'b "" 'o 0, all)
                (pins s 'b all 'o n, snip all 0 n)))))
   (tar-peek s n)
    (: h (tar-take s n)   b (peep s 'b "")
       (pins s 'b (h + snip b (peep s 'o 0) #b) 'o 0,
        h))
   (tar-pour s n wr)
    (: b (peep s 'b "")   o (peep s 'o 0)   have (#b - o)
       (? (n <= have) (wr (snip b o (o + n)), pin s 'o (o + n), n)
          (: _ (0 < have ? (wr (snip b o #b)) 0) _ (pins s 'b "" 'o 0) (tar-pour1 s wr n (n - have)))))
   ; k of n still to pour, the buffer empty. its own function so tar-pour's turn stays a
   ; tail call and no piece is held
   (tar-pour1 s wr n k)
    (: p (peep s 'rd () 0)
       (? (#p = 0) (n - k)
          (#p < k) (: _ (wr p) (tar-pour1 s wr n (k - #p)))
          (tar-pour-end s wr p k n)))
   (tar-pour-end s wr p k n) (: _ (wr (snip p 0 k)) _ (pins s 'b p 'o k) n)
   (tar-rd s) (_ \ (: b (peep s 'b "")   o (peep s 'o 0)
                     (o < #b ? (pins s 'b "" 'o 0, snip b o #b) (peep s 'rd () 0))))
   ; (f e b) per member, e with 'size and no 'body; (tar-body s b wr) pours b, the rest
   ; is read past. f answers 1 to go on. -> (1 count) | () torn or bad sum | 'stop
   (tar-walk s f) (:- (go 0) (go k)
    (tar-take s tar-blk @ h
     (? (#h < tar-blk) ()
        (tar-zero? h 0) [1 k]
        (tar-hdr h @ r
         (r ? (: sz (r 2)  b {'left sz}   meta (tar-get (r 1) 'kind 'file = 'global)
          (pin (r 1) 'size sz,
           (!meta && f (r 1) b != 1 ? 'stop
              (peep b 'left 0 + padk sz tar-blk @ n
                 (tar-pour s n (x \ 0) < n ? () (go (meta ? k (k + 1)))))))))))) )
   (tar-body s b wr) (: n (peep b 'left 0) got (tar-pour s n wr) (pin b 'left (n - got), got = n))

   ; --- the filesystem, in and out ---
   ; paths are stored relative to root: an absolute one unpacks over the system
   (tar-join a b) (#a ? "\(a)/\(b)" b)
   ; stat answers (size mtime-ms mode mtime-ns) and follows a symlink, so links are found
   ; by readlink; without it a tree of symlinks archives as copies
   (tar-mode st) (4095 & <>>st)
   (tar-dir? st) (61440 & <>>st = 16384)
   (tar-secs st) (<>st // 1000)
   ; `keep` sees each child's rel nom before the walk reads or descends into it
   (tar-gather? keep root rel) (tar-walk? keep root rel 1)
   ; the thin walk reads no file: a file entry carries 'size and 'path (local, never in a
   ; header) instead of its body, so the archive can stream; it heads as its fat twin does
   (tar-thin? keep root rel) (tar-walk? keep root rel 0)
   (tar-walk? keep root rel fat)            ; -> (1 entries) | ()
    (: full (#rel ? "\(root)/\(rel)" root)
       lnk (readlink full)
       st (stat full)
       (? (string? lnk)
          (tar-entry rel 'link "" @ e
             (pins e 'to lnk 'mode 511,
              (two? st ? (pin e 'mtime (tar-secs st)) 0),
              [1 [e]]))
          (atom? st) ()
          (tar-dir? st)
          (: e (tar-entry (#rel ? rel ".") 'dir "")
             _ (pins e 'mode (tar-mode st) 'mtime (tar-secs st))
             ; sorted: readdir's order varies between boxes, and the archive must not
             kids (sort (readdir full))
             (go ks acc) (atom? ks ? [1 (rev acc)]
                          (tar-join rel <ks @ k2
                           (!(keep k2) ? (go >ks acc)
                            (tar-walk? keep root k2 fat @ r
                             (r && go >ks (foldl (flip (.)) acc <>r))))))
             r (go kids ())
             (r ? [1 (e . <>r)]))
          !fat
          (tar-entry rel 'file "" @ e
             (pins e 'mode (tar-mode st) 'mtime (tar-secs st)
                     'size <st           'path full,
              [1 [e]]))
          (uread full @ b
             (b ?
                (tar-entry rel 'file (<(>b)) @ e
                   (pins e 'mode (tar-mode st) 'mtime (tar-secs st),
                    [1 [e]]))))))
   (tar-gather root rel) (tar-gather? 0 root rel)
   ; neither mkdir nor symlink answers its own success, so each write is checked by looking
   tar-there? (two? * stat)
   (tar-strip nom)                          ; the "./" GNU tar stores on a `-C dir .`
    (#nom > 1 && nom 0 = 46 && nom 1 = 47 ? (snip nom 2 #nom) nom)
   ; a release tarball carries no clock, uid or umask, so two cuts of one tree hash alike.
   ; only the x bit of the mode is content
   (tar-canon e) (tar-get e 'kind 'file @ 'link 511 'dir 493
                  (tar-get e 'mode 420 & 73 > 0 ? 493 420))
   (tar-level es stamp)
    (map (e \ pins (foldl (t \ k \ pin t k (e k)) {} (keys e))
              'mtime stamp 'uid 0 'gid 0
              'uname "root" 'gname "root" 'mode (tar-canon e))
         es)
   ; a name as its segments: a leading /, "." and empty segments dropped, () for any ".."
   (tar-segs nom)                           ; -> (1 segs) | ()
    (:- (go 0 0 ()) n #nom
     (cut st k acc) (snip nom st k @ s (#s = 0 || s = "." ? acc (s . acc)))
     (go k st acc) (? (n <= k) (rev (cut st k acc) @ l (any (= "..") l ? () [1 l]))
                      (nom k = 47) (go (k + 1) (k + 1) (cut st k acc))
                      (go (k + 1) st acc)))
   ; asked of the path itself, never what a link there names
   (tar-at? p m) (lstat p @ st (two? st && <>>st & 61440 = m))
   (tar-link-at? p) (tar-at? p 40960)
   (tar-dir-at? p) (tar-at? p 16384)
   ; root/segs with every parent made, never through a symlink or a non-directory: a link
   ; laid a member ago would carry the next write out of root
   (tar-lay root segs)                      ; -> (1 path) | ()
    (: (at q) (#root ? "\(root)/\(q)" q)
       (go ss q)
        (at q @ p
           (? (atom? >ss) [1 p]
              (tar-link-at? p) ()
              (tar-dir-at? p) (go >ss "\(q)/\(<>ss)")
              (two? (lstat p)) ()
              (mkdir p 493, (tar-dir-at? p ? (go >ss "\(q)/\(<>ss)")))))
       (atom? segs ? [1 root] (go segs <segs)))
   ; set-id and sticky bits off an archive are not ours to lay
   (tar-perm m) (m & 511)
   ; one member laid under root, its body written by fill. a name that climbs out or runs
   ; through a link is warned and skipped; a link at the name itself is unlinked first.
   ; -> 1 laid | 0 refused | 'fail
   (tar-put warn root e fill)
    (: nom (tar-get e 'nom "")
       sg (tar-segs nom)
       lp (sg && tar-lay root <>sg)
       p (lp && <>lp)
       kind (tar-get e 'kind 'file)
       _ (? !sg (warn "\(nom): Member name contains '..'")
            !lp (warn "\(nom): Cannot extract through a symbolic link or a file")
            (atom? <>sg) 0
            (tar-link-at? p && unlink p))
       ; the mode is laid back with chmod: open and mkdir create at the umask's pleasure
       ok (? !lp 1
             (kind == 'dir)  (mkdir p 493,
                              tar-dir-at? p && chmod p (tar-perm (tar-get e 'mode 493)),
                              tar-dir-at? p)
             (kind == 'link) (symlink (tar-get e 'to "") p,
                              string? (readlink p))
             (open p "w" @ q
                (hot? q && (fill q, close q,
                            tar-at? p 32768 && chmod p (tar-perm (tar-get e 'mode 420)),
                            tar-there? p))))
       (? !lp 0 ok 1 'fail))
   (tar-scatter? warn root es)              ; -> (1 count refused)
    (:- (go es 0 0) (go xs k r)
     (atom? xs ? [1 k r]
      (: e <xs   w (tar-put warn root e (q \ say q (tar-get e 'body "")))
         (w @ 'fail () (go >xs (k + w) (r + 1 - w))))))
   (tar-scatter root es)                    ; -> (1 count) | (), () on any refusal
    (tar-scatter? (m \ 0) root es @ w (w && w 2 = 0 ? [1 (w 1)] ())))) ; module 'tar

; --- the face ---
; `love tar`, GNU tar's spelling: the bundled key (czf), dashed letters and long names.
;   tar {c|x|t}[v][z|j|J|a] [--zstd] [-f ARCHIVE] [-C DIR] [-O] [--strip-components=N] [MEMBER..]
; a read sniffs the codec; -a picks it by suffix. bz2, xz and zstd are reached at the call,
; so path-loaded tools take tar with gz alone. statuses: 0, 2 a failure.
; wrapped so borrow's names stay off the dist cat's shared layer
(module 'tarcmd
(borrow 'gz)
(borrow 'tar)

(borrow 'posix)
(: (tarc-die m) (udie 2 "tar: \(m)")
   (tarc-warn m) (say err "tar: \(m)\n", flush err)
   (tarc-lazy m f what) (cite m f @ b (lit? b ? b (tarc-die "no \(what) aboard")))

   ; --- the codecs: 'z 'j 'J 'zst, and () for a bare tar ---
   (tarc-zip z a) (z @ 'z (gz-zip a "" 0)
                       'j (tarc-lazy 'bz2 'bz2-pack "bzip2" a 9)
                       'J (tarc-lazy 'xz 'xz-pack "xz" a 8388608 'crc64)
                       'zst (tarc-lazy 'zstd 'zstd-pack "zstd" a 3)
                       a)
   (tarc-unzip z b)                    ; -> (1 bytes) | ()
    (z @ 'z (gz-unzip b)
         'j (tarc-lazy 'bz2 'bz2-unpack "bzip2" b @ v (two? v && v))
         'J (tarc-lazy 'xz 'xz-unpack "xz" b @ v (two? v && v))
         'zst (tarc-lazy 'zstd 'zstd-unpack "zstd" b @ v (two? v && v))
         [1 b])
   (tarc-sniff b) (?
    (2 <= #b && b 0 = 31 && b 1 = 139) 'z
    (4 <= #b && snip b 0 3 = "BZh") 'j
    (6 <= #b && b 0 = 253 && snip b 1 5 = "7zXZ" && b 5 = 0) 'J
    (4 <= #b && snip b 0 4 = "\x28\xb5\x2f\xfd") 'zst)
   (tarc-bysuf p) (?
    (ends? p ".gz" || ends? p ".tgz" || ends? p ".taz") 'z
    (ends? p ".bz2" || ends? p ".tbz" || ends? p ".tbz2" || ends? p ".tb2") 'j
    (ends? p ".xz" || ends? p ".txz") 'J
    (ends? p ".zst" || ends? p ".tzst") 'zst)
   (tarc-zname z) (z @ 'z "gzip" 'j "bzip2" 'zst "zstd" "xz")
   ; the archive goes out coded in runs of tarc-run: gzip members, xz and bzip2 streams and
   ; zstd frames each read on into the next, so no member is held
   tarc-run 4194304

   ; --- the flags ---
   ; each letter's rows: what it pins, and 'arg for the two that take a word
   tarc-letters [[99 'mode 'c] [120 'mode 'x] [116 'mode 't] [122 'z 'z] [106 'z 'j]
                 [74 'z 'J] [97 'auto 1] [118 'v 1] [79 'O 1] [102 'f 'arg] [67 'C 'arg]]
   tarc-longs [["create" 'mode 'c] ["extract" 'mode 'x] ["get" 'mode 'x] ["list" 'mode 't]
               ["gzip" 'z 'z] ["gunzip" 'z 'z] ["ungzip" 'z 'z] ["bzip2" 'z 'j] ["xz" 'z 'J] ["zstd" 'z 'zst]
               ["auto-compress" 'auto 1] ["verbose" 'v 1] ["to-stdout" 'O 1]
               ["file" 'f 'arg] ["directory" 'C 'arg] ["strip-components" 'strip 'arg]]
   (tarc-row k rows) (: (go l) (? (atom? l) () (<<l = k) <l (go >l)) (go rows))
   (tarc-set t row v) (pin t (row 1) (row 2 = 'arg ? v (row 2)))
   ; one letter cluster -> the words left. czf A takes A for f after the cluster; -fA and
   ; -f A the dashed way
   (tarc-cluster t w k dash rest)
    (#w <= k ? rest
       (tarc-row (w k) tarc-letters @ row
          (? !row (tarc-die "invalid option -- '\(string (w k))'")
             !(row 2 = 'arg) (tarc-set t row 0, tarc-cluster t w (k + 1) dash rest)
             (dash && k + 1 < #w) (tarc-set t row (snip w (k + 1) #w), rest)
             !(two? rest) (tarc-die "option requires an argument -- '\(string (w k))'")
             (tarc-set t row <rest, tarc-cluster t w (k + 1) dash >rest))))
   (tarc-long t w rest)                ; --name, --name=V, --name V -> the words left
    (: nv (w @ ((n && 0 < #n) + "=" + v) [n v] [w ()])
       nm <nv
       row (tarc-row nm tarc-longs)
       (? !row (tarc-die "unrecognized option '--\(w)'")
          (row 2 != 'arg) (tarc-set t row 0, rest)
          (string? <>nv) (tarc-set t row <>nv, rest)
          !(two? rest) (tarc-die "option '--\(nm)' requires an argument")
          (tarc-set t row <rest, >rest)))
   (tarc-opts t as)
    (: (go l mem)
        (!(two? l) ? (pin t 'mem (rev mem))
           (<l @ w
              (? (w = "--") (pin t 'mem (rev mem + >l))
                 (2 < #w && w 0 = 45 && w 1 = 45) (go (tarc-long t (snip w 2 #w) >l) mem)
                 (1 < #w && w 0 = 45) (go (tarc-cluster t w 1 1 >l) mem)
                 (go >l (w . mem)))))
       (two? as && 0 < #<as && !(<as 0 = 45) ?
          (go (tarc-cluster t <as 0 0 >as) ())
          (go as ())))

   ; --- the members ---
   (tarc-trim p) (1 < #p && p (#p - 1) = 47 ? (tarc-trim (snip p 0 (#p - 1))) p)
   (tarc-nom e) (tarc-trim (tar-strip (tar-get e 'nom "")))
   (tarc-has? nom m) (tarc-trim (tar-strip m) @ m2
                        (nom = m2 || #m2 < #nom && snip nom 0 (#m2 + 1) = m2 + "/"))
   ; --strip-components: the first n segments off, a member with no more dropped
   (tarc-cut nom n) (n < 1 ? nom
                       (nom @ (_ + "/" + r) (tarc-cut r (n - 1)) ()))
   ; (1 e) with its name cut, or () to pass it by; unmatched words are said by tarc-unseen
   (tarc-want t)
    (: ms (peep t 'mem ())   n (tarc-num (peep t 'strip ""))   seen {}
       (pin t 'seen seen,
        (e \ (: nm (tarc-nom e)
                hit (!(two? ms) ? 1 (: m (filter (m \ tarc-has? nm m) ms) (each m (m \ pin seen m 1), two? m)))
                c (hit && tarc-cut nm n)
                (c && 0 < #c ? [1 (pin (tarc-copy e) 'nom c)])))))
   (tarc-unseen t)
    (each (peep t 'mem ()) (m \ (peep (peep t 'seen {}) m 0 ? 0
                                   (tarc-warn (m + ": Not found in archive"), pin t 'bad 1))))
   (tarc-num s) (: (go k v) (? (#s <= k) v (s k < 48 || 57 < s k) (tarc-die ("invalid number: " + s))
                                (go (k + 1) (v * 10 + s k - 48)))
                   (go 0 0))
   (tarc-copy e) (foldl (c \ k \ pin c k (e k)) {} (keys e))

   ; --- the long listing: GNU's columns, UTC ---
   (tarc-p2 v) (v < 10 ? ("0" + show v) (show v))
   (tarc-civil z)                      ; days since 1970 -> (y m d)
    (: z2 (z + 719468)
       era (0 <= z2 ? (z2 // 146097) ((z2 - 146096) // 146097))
       doe (z2 - era * 146097)
       yoe ((doe - doe // 1460 + doe // 36524 - doe // 146096) // 365)
       doy (doe - (365 * yoe + yoe // 4 - yoe // 100))
       mp ((5 * doy + 2) // 153)
       d (doy - (153 * mp + 2) // 5 + 1)
       m (mp < 10 ? (mp + 3) (mp - 9))
       [(yoe + era * 400 + (m <= 2 ? 1 0)) m d])
   (tarc-date s) (: c (tarc-civil (s // 86400)) r (s % 86400)
                    (show <c + "-" + tarc-p2 <>c + "-" + tarc-p2 <>>c + " "
                     + tarc-p2 (r // 3600) + ":" + tarc-p2 (r % 3600 // 60)))
   (tarc-perm e)
    (: md (tar-get e 'mode 420)
       (bit b c) (0 < md & b ? c "-")
       ((tar-get e 'kind 'file @ 'dir "d" 'link "l" "-")
        + bit 256 "r" + bit 128 "w" + bit 64 "x" + bit 32 "r" + bit 16 "w" + bit 8 "x"
        + bit 4 "r" + bit 2 "w" + bit 1 "x"))
   (tarc-lpad w s) (w <= #s ? s (tarc-lpad w (" " + s)))
   (tarc-longline e)
    (: un (tar-get e 'uname "") gn (tar-get e 'gname "")
       og ((#un ? un (show (tar-get e 'uid 0))) + "/" + (#gn ? gn (show (tar-get e 'gid 0))))
       sz (show (tar-get e 'kind 'file = 'file ? (tar-get e 'size #(tar-get e 'body "")) 0))
       nom (tar-get e 'nom "")
       (tarc-perm e + " " + og + " " + tarc-lpad (18 - #og) sz + " "
        + tarc-date (tar-get e 'mtime 0) + " " + nom
        + (tar-get e 'kind 'file = 'link ? (" -> " + tar-get e 'to "") "")))

   ; --- the three modes ---
   (tarc-arch t) (peep t 'f "-")
   ; where the names -v says go: stdout, unless the archive is going there
   (tarc-tell t s) (: o (peep t 'mode 'c = 'c && tarc-arch t = "-" ? err out)
                      (say o (s + "\n")))
   (tarc-c t)
    (: ops (peep t 'mem ())
       _ (!(two? ops) && tarc-die "Cowardly refusing to create an empty archive")
       a (tarc-arch t)
       _ (a = "-" && two? (tty out) && tarc-die "Refusing to write archive contents to terminal (missing -f option?)")
       root (peep t 'C "")
       ; opened before the walk, so an archive inside the tree is seen as itself and left out
       q (a = "-" ? out (open a "w"))
       _ (!(hot? q) && tarc-die "\(a): Cannot open")
       (self? e) (a != "-" && tar-strip (tar-get e 'path "") = tar-strip a
                  && (tarc-warn "\(tar-get e 'nom ""): file is the archive; not dumped", 1))
       ; a leading / comes off, said once, as GNU does
       (one p)
        (: p2 (tarc-trim p)
           abs (0 < #p2 && p2 0 = 47)
           rel (: (go k) (k < #p2 && p2 k = 47 ? (go (k + 1)) (snip p2 k #p2)) (go 0))
           _ (abs && !(peep t 'slash 0) && (pin t 'slash 1, tarc-warn "Removing leading `/' from member names"))
           g (tar-thin? 0 (abs ? "/" (#root ? root ".")) (abs && !#rel ? "." rel))
           (g ? <>g (tarc-warn "\(p): Cannot stat: No such file or directory", pin t 'bad 1, ())))
       es (filter (e \ !(self? e)) (foldl (acc \ p \ acc + one p) () ops))
       _ (any (e \ !(tar-head e)) es && tarc-die "cannot pack (a path too long for ustar?)")
       _ (peep t 'v 0 && each es (e \ tarc-tell t (tar-get e 'nom "")))
       z (? (peep t 'z ()) (peep t 'z ()) (peep t 'auto 0) (tarc-bysuf a) ())
       run {'l () 'n 0}
       (spill _) (: b (cats (rev (run 'l))) (pins run 'l () 'n 0, #b && say q (tarc-zip z b)))
       (put x) (pins run 'l (x . run 'l) 'n (run 'n + #x), (tarc-run <= run 'n && spill 0))
       ok (tar-emit es put)
       (spill 0,
        flush q,
        (a = "-" || close q),
        !ok && tarc-die "a file changed as we read it",
        (peep t 'bad 0 ? 2 0)))

   ; the archive as a source, its codec sniffed. -> (src fin z), fin _ reads what the walk
   ; left and answers whether the codec's check held
   (tarc-src t)
    (: a (tarc-arch t)
       _ (a = "-" && two? (tty in) && tarc-die "Refusing to read archive contents from terminal (missing -f option?)")
       q (a = "-" ? in (open a "r"))
       _ (!(hot? q) && tarc-die "\(a): Cannot open: No such file or directory")
       raw (tar-src (_ \ (see q @ c (c < 0 ? "" (unsee q c, chug q)))))
       z (peep t 'z () @ w (w ? w (tarc-sniff (tar-peek raw 6))))
       (all r a) (r 0 @ p (#p @ 0 (cats (rev a)) (all r (p . a))))
       (drain src) (: (dr r) (#(r 0) @ 0 0 (dr r)) (dr (tar-rd src)))
       (z @ 'z
          (: g (gz-pull (tar-rd raw))   src (tar-src (_ \ gz-next g))
             [src (_ \ (drain src, two? (peep g 'ans ()))) z])
          ('J || 'j || 'zst)
          (: m (z @ 'J 'xz 'j 'bz2 'zstd)
             g (tarc-lazy m (nom "\(m)-pull") (tarc-zname z) (tar-rd raw))
             next (cite m (nom "\(m)-next"))
             src (tar-src (_ \ next g))
             [src (_ \ (drain src, two? (peep g 'ans ()))) z])
          (: u (z ? (tarc-unzip z (all (tar-rd raw) ())) [1 raw])
             (!u && tarc-die "\(a): not a \(tarc-zname z) stream, or its check disagrees",
              [(z ? (tar-src ({0 <>u} @ t1 (_ \ (peep t1 0 "" @ v (pin t1 0 "", v))))) raw) 0 z]))))
   ; the codec's check first: a torn stream underneath reads as a torn archive above
   (tarc-end t sf w)
    (tarc-arch t @ a
       (w = 'stop && tarc-die "cannot write under \(peep t 'C ".")",
        !(sf 1 0) && tarc-die "\(a): not a \(tarc-zname (sf 2)) stream, or its check disagrees",
        !(two? w) && tarc-die "\(a): not a tar archive, or it is truncated",
        tarc-unseen t))
   ; bodies are poured, never held. a member laid before a later one turns out torn stays
   ; laid, as GNU's does
   (tarc-x t)
    (: sf (tarc-src t)   src <sf   root (peep t 'C ".")   want (tarc-want t)
       warn (m \ (tarc-warn m, pin t 'bad 1))
       w (tar-walk src (e \ b \ (want e @ r
                                   (!(two? r) ? 1
                                      (<>r @ e2
                                         (peep t 'v 0 && tarc-tell t (tar-get e2 'nom ""),
                                          (peep t 'O 0 ?
                                             ((tar-get e2 'kind 'file @ 'file (tar-body src b (say out)) 0), 1)
                                             (tar-put warn root e2 (tar-body src b * say) @ 'fail 'stop 1))))))))
       (flush out,
        tarc-end t sf w,
        (peep t 'bad 0 ? 2 0)))
   (tarc-t t)
    (: sf (tarc-src t)   src <sf   want (tarc-want t)
       w (tar-walk src (e \ b \ (want e @ r
                                   (two? r && say out ((peep t 'v 0 ? (tarc-longline <>r) (tar-get <>r 'nom "")) + "\n"),
                                    1))))
       (flush out,
        tarc-end t sf w,
        (peep t 'bad 0 ? 2 0)))

   usage "usage: tar {c|x|t}[vzjJaO] [--zstd] [-f ARCHIVE] [-C DIR] [--strip-components=N] [MEMBER..]"
   (tar-main av)
    ({} @ t
       (tarc-opts t av,
        (peep t 'mode () @ 'c (tarc-c t) 'x (tarc-x t) 't (tarc-t t)
          (tarc-die "You must specify one of the '-ctx' options"))))

   T (cite 'verbs 'tab)
   _ (pins T 'tar (udoor 'tar (urun tar-main) usage 1 1)))

) ; module 'tarcmd
