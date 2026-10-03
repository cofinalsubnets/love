; src/tools/selfpack.l -- cut the source container from the tree itself.
;
;   love src/tools/selfpack.l [-c codecs] src.tree top stamp build roster [drop..]
;
; codecs names a section's codec, `lisp=bzip2,c=bzip2,rest=lzma2`: stored deflate bzip2 lzma2,
; deflate where none is named. every seat carries every decoder, so the table is free to move.
;
; the tree on disk is the source, checkout and seed-laid tree alike. it leaves out sb's law
; (.sbignore plus sb's built-ins, so the vcs walk and this cut agree), sp-own's structural skips
; and each drop. the walk is sorted and every mtime pinned to stamp, so the same files answer
; the same bytes (test_distboot holds a re-cut to the byte). `build` rides in as top/STAMP, and
; roster names the files a carried-source bake reads (the Makefile's distfiles).
; the container is the one src/love/lib/srctree.h reads: a header, an index, and the tar in
; sections, each packed alone: deflate where a run reads, bzip2 or lzma2 where none does. the
; id is the sha of the joined tar, kept in src.tree.sha; the quiet pass (tar-thin? + tar-hash)
; answers "has the tree moved" off stat alone.
; the borrows name paths, in dependency order: a module name has nothing to find under love0,
; and `-l FILE` whose basename names a verb seats it (`-l src/apps/sb/sb.l` would run sb).
(borrow "src/apps/gz.l")
(borrow "src/apps/tar.l")
(borrow "src/apps/kore/text.l")
(borrow "src/apps/kore/diff.l")
(borrow "src/apps/sb/merge.l")
(borrow "src/apps/dns.l")
(borrow "src/apps/sb/http.l")
(borrow "src/apps/sb/sb.l")   ; for the ignore law only -- .sbignore is sb's file

(borrow 'posix)
(: (sp-die m) (say err ("selfpack: " + m + "\n"), quit 1)
   (sp-read p) (uread p @ [1 s] [1 (s + "")] ())
   (sp-write p s) (: q (open p "w")
                     (!(hot? q) ? (sp-die ("cannot write " + p)), say q s, close q))
   ; the structural skips, which no ignore file may take away. doc/ itself stays:
   ; `make install` generates the three man pages from doc/{love,cook,lush}.md.
   sp-own '("bin" "dl" "doc/misc" ".*")
   sp-ign? (cite 'sb 'ign?)
   ; sb's directory-only built-ins ride as plain rules here: this walk has no stat to
   ; ask, and the cut knows its own tree holds no file by those names
   (sp-rules drops) ((cite 'sb 'igs 0) + (cite 'sb 'igsdir) + sp-own + drops)
   ; handed to the walk, not run after it, so a rejected directory is never descended
   ; into. .sbignore itself has to ride: a seeded tree cuts itself with the same law.
   (sp-keep? rules nom) (nom = ".sbignore" || !(sp-ign? nom rules))
   ; re-home the kept entries under top; the walk is sorted, so order holds.
   (sp-take es top acc)
    (atom? es ? (rev acc)
       (<es @ e (pin e 'nom (top + "/" + tar-get e 'nom ""), sp-take >es top (e . acc))))

   ; the sections, in the order they join: the frame (the root, top, STAMP and every
   ; directory) with moon's toolchain slice behind it, what a nestless compile reads (moon.l's
   ; mblob); the bake roster; what a seat reads at run time; the other .l; C and asm; the
   ; rest. each keeps the walk's order.
   sp-secs ["moon" "bake" "seat" "lisp" "c" "rest"]
   sp-seat ["src/apps/tls/roots.pem"]                  ; tls/verify.l's roots, off /love
   ; -c's table -> {section codec}, in srctree.h's numbers
   sp-cnums {"stored" 0 "deflate" 1 "bzip2" 2 "lzma2" 3}
   (sp-codecs spec)
    (: (go s t) (s @ "" t
                      (a + "," + b) (go b (go a t))
                      (k + "=" + v) (? (!(any (= k) ("index" . sp-secs))) (sp-die ("no section " + k))
                                       (nil? (peep sp-cnums v ())) (sp-die ("no codec " + v))
                                       (pin t k (sp-cnums v)))
                      (sp-die ("codecs are SECTION=CODEC,..: " + s)))
       (go spec {}))
   (sp-pack c s) (? (c = 0) s (c = 2) (bz2e s 9) (c = 3) (lzma2e s 8388608) (gz-deflate-best s))
   (sp-slice? e) (: n (tar-get e 'nom "")
                    (starts? n "src/apps/moon/include/" || starts? n "src/apps/moon/lib/"
                     || n = "src/apps/moon/include" || n = "src/apps/moon/lib"))
   (sp-sec ros e) (: n (tar-get e 'nom "")
                     (? (tar-get e 'kind 'file = 'dir || sp-slice? e) "moon"
                        (ros n) "bake"
                        (any (= n) sp-seat) "seat"
                        (ends? n ".l") "lisp"
                        (any (x \ ends? n x) [".c" ".h" ".S" ".s"]) "c"
                        "rest"))
   ; -> each section's entries, leveled and re-homed under top. shared by both passes, so
   ; their digests compare.
   (sp-lev es top stamp build ros)
    (: root <es
       te (tar-entry top 'dir "")
       _ (pin te 'mode (tar-get root 'mode 493))
       se (tar-entry "STAMP" 'file (build + "\n"))
       ; tagged before any is re-homed: sp-take pins the new nom into the entry itself
       tag (map (e \ [(sp-sec ros e) e]) >es)
       parts (map (nm \ sp-take (map (p \ p 1) (filter (p \ <p = nm) tag)) top ()) sp-secs)
       (map (l \ tar-level l stamp) (([root te] + sp-take [se] top () + <parts) . >parts)))

   ; --- the container ---
   sp-nul (string (cask 1))
   (sp-le v k) (: c (cask k)
                  (go i x) (i < k ? (pin c i (x & 255), go (i + 1) (x >> 8)))
                  (go 0 v, string c))
   (sp-name nm) (nm + string (cask (8 - #nm)))         ; NUL-filled to the header's 8
   (sp-rel nom) (: (go i) (? (#nom <= i) "" (nom i = 47) (snip nom (i + 1) #nom) (go (i + 1)))
                   (go 0))
   (sp-pad n) (512 * ((n + 511) // 512))
   ; section k's index records, each entry's bytes at their offset in its tar. a directory,
   ; the root and top have no record: a path's directories are what lies under them.
   (sp-recs k es)
    (: (go l at acc)
        (atom? l ? (cats (rev acc))
           (: e <l   kind (tar-get e 'kind 'file)   n (sp-rel (tar-get e 'nom ""))
              len (kind = 'file ? #(tar-get e 'body "") 0)
              r (kind = 'dir || !#n ? ""
                   (cats [(sp-le k 1) (kind = 'link ? "2" "0") (sp-le (tar-get e 'mode 420) 2)
                          (sp-le (at + 512) 4) (sp-le len 4) (sp-le (tar-get e 'mtime 0) 4)
                          n sp-nul (kind = 'link ? (tar-get e 'to "") "") sp-nul]))
              (go >l (at + 512 + sp-pad len) (r . acc))))
       (go es 0 ()))
   ; each section's tar is tar-pack's less the end blocks, which only the last keeps: joined,
   ; they are the one archive the tree cut to
   (sp-frags secs)
    (: n #secs
       (map (i \ tar-pack (secs i) @ a
                 (!a ? (sp-die "cannot pack (a path too long for ustar?)")
                    (i + 1 = n ? a (snip a 0 (#a - 1024)))))
            ^n))
   ; -> the container: the header row of each section, then them, packed, the index first
   (sp-tree cs secs frags)
    (: idx (cats (map (i \ sp-recs (i + 1) (secs i)) ^#secs))
       raws (idx . frags)
       names ("index" . sp-secs)
       codec (map (nm \ peep cs nm 1) names)
       packs (map (i \ sp-pack (codec i) (raws i)) ^#raws)
       (row i) (cats [(sp-name (names i)) (sp-le (codec i) 4) (sp-le #(raws i) 4) (sp-le #(packs i) 4)
                      (sp-le (gz-crc32 (raws i)) 4)])
       (cats (["lovetree" (sp-le #raws 4)] + map row ^#raws + packs)))
   ; the sidecar names the format and the codecs with the digest, so a cut under another
   ; layout or table is not fresh
   (sp-fmt spec) ("tree2 " + spec + " ")

   ; the cut that reads: pack, hash, and write when the content actually moved.
   (sp-cut spec out side top stamp build rules ros)
    (: g (tar-gather? (sp-keep? rules) "." "")
       _ (!g ? (sp-die "cannot read the tree"))
       secs (sp-lev <>g top stamp build ros)
       frags (sp-frags secs)
       h (sp-fmt spec + sha256 (cats frags))
       old (sp-read side)
       have (sp-read out)
       (? (two? old && two? have && <>old = h) 0
          (puts ("LOVE\t" + out), putc 10, sp-write out (sp-tree (sp-codecs spec) secs frags), sp-write side h, 0)))

   (sp-main a0)
    (: spec (two? a0 && <a0 = "-c" ? <>a0 "")
       av (two? a0 && <a0 = "-c" ? >>a0 a0)
       _ (sp-codecs spec)                              ; a bad table dies before the walk
       n #av
       _ (n < 5 ? (sp-die "usage: selfpack [-c CODECS] SRC.TREE TOP STAMP BUILD ROSTER [DROP..]"))
       out <av
       top <>av
       stamp <(sound <>>av)
       build (av 3)
       ros (sp-read (av 4) @ [1 s] (foldl (t \ w \ pin t w 1) {} (words s))
              (sp-die ("cannot read the roster " + av 4)))
       ; top joins the drops: a release untarred at the root would otherwise ride the
       ; next blob, and the artifact would swallow a whole second love.
       drops (top . >>>>>av)
       side (out + ".sha")
       ; `stat`, not a read: the question is only whether the container is there. a ()
       ; from the thin pass (a torn read, a nom too long for ustar) is not an answer
       ; and falls through to the cut, which reads each file once.
       rules (sp-rules drops)
       t (tar-thin? (sp-keep? rules) "." "")
       _ (!t ? (sp-die "cannot read the tree"))
       hq (tar-hash (foldl (+) () (sp-lev <>t top stamp build ros)))
       old (sp-read side)
       quiet (string? hq && two? old && <>old = sp-fmt spec + hq && two? (stat out))
       (quiet ? 0 (sp-cut spec out side top stamp build rules ros)))

   (sp-main >argv))
