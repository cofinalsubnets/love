; src/tools/selfpack.l -- cut the source container from the tree itself.
;   love src/tools/selfpack.l [-c codecs] src.tree top stamp roster [drop..]
;   love src/tools/selfpack.l -l          the walk's files, one path a line
; codecs: `lisp=bzip2,c=bzip2,rest=lzma2`, of stored deflate bzip2 lzma2, deflate unnamed
; the walk leaves out sb's ignore law, sp-own and each drop; sorted, every mtime pinned to
; stamp, so the same files answer the same bytes (test_distboot). roster names the files a
; carried-source bake reads
; the container is srctree.h's: a header, an index, and the tar in sections each packed
; alone; its id is the joined tar's sha in src.tree.sha, and the quiet pass answers "has
; the tree moved" off stat alone
; the borrows are paths in dependency order: a module name finds nothing under love0, and
; -l of a verb's basename would seat it
(borrow "src/apps/gz.l")
(borrow "src/apps/tar.l")
(borrow "src/apps/kore/text.l")
(borrow "src/apps/kore/diff.l")
(borrow "src/apps/sb/merge.l")
(borrow "src/apps/dns.l")
(borrow "src/apps/sb/http.l")
(borrow "src/apps/sb/sb.l")   ; for the ignore law only

(borrow 'posix)
(borrow 'bz2)
(borrow 'hashes)
(borrow 'xz)
(: (sp-die m) (say err ("selfpack: " + m + "\n"), quit 1)
   (sp-read p) (uread p @ [1 s] [1 (s + "")] ())
   (sp-write p s) (: q (open p "w")
                     (!(hot? q) ? (sp-die ("cannot write " + p)), say q s, close q))
   ; what is never the checkout's own source: the hidden dirs (.git, the sessions' .claude
   ; worktrees) and a release laid at the root, love-VERSION/ of any version
   sp-laid '(".*" "love-*")
   ; the structural skips no ignore file may take away; doc/ stays for the man pages
   sp-own (["bin" "dl" "doc/misc"] + sp-laid)
   sp-ign? (cite 'sb 'ign?)
   ; sb's directory-only built-ins ride as plain rules: the walk has no stat to ask
   (sp-rules drops) ((cite 'sb 'igs 0) + (cite 'sb 'igsdir) + sp-own + drops)
   ; handed to the walk, so a rejected directory is never descended; .sbignore rides, so a
   ; seeded tree cuts itself by the same law
   (sp-keep? rules nom) (nom = ".sbignore" || !(sp-ign? nom rules))
   ; re-home the kept entries under top
   (sp-take es top acc)
    (atom? es ? (rev acc)
       (<es @ e (pin e 'nom (top + "/" + tar-get e 'nom ""), sp-take >es top (e . acc))))

   ; the sections in join order: the frame (root, top, every directory) with moon's
   ; toolchain slice (moon.l's mblob), the bake roster, the seat's run-time reads, .l, C and
   ; asm, the rest; each keeps the walk's order
   sp-secs ["moon" "bake" "seat" "lisp" "c" "rest"]
   sp-seat ["src/apps/tls/roots.pem" "VERSION"]        ; tls/verify.l's roots, and the version line
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
   ; -> each section's entries, leveled and re-homed; shared by both passes so digests compare
   (sp-lev es top stamp ros)
    (: root <es
       te (tar-entry top 'dir "")
       _ (pin te 'mode (tar-get root 'mode 493))
       ; tagged before re-homing: sp-take pins the new nom into the entry itself
       tag (map (e \ [(sp-sec ros e) e]) >es)
       parts (map (nm \ sp-take (map (p \ p 1) (filter (p \ <p = nm) tag)) top ()) sp-secs)
       (map (l \ tar-level l stamp) (([root te] + <parts) . >parts)))

   ; --- the container ---
   sp-nul (string (cask 1))
   (sp-le v k) (: c (cask k)
                  (go i x) (i < k ? (pin c i (x & 255), go (i + 1) (x >> 8)))
                  (go 0 v, string c))
   (sp-name nm) (nm + string (cask (8 - #nm)))         ; NUL-filled to the header's 8
   (sp-rel nom) (: (go i) (? (#nom <= i) "" (nom i = 47) (snip nom (i + 1) #nom) (go (i + 1)))
                   (go 0))
   (sp-pad n) (512 * ((n + 511) // 512))
   ; section k's index records; directories, the root and top have none
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
   ; each section's tar less the end blocks, which only the last keeps: joined, one archive
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
   ; the sidecar names the format and codecs too, so another layout or table is not fresh
   (sp-fmt spec) ("tree2 " + spec + " ")

   ; pack, hash, and write when the content moved
   (sp-cut spec out side top stamp rules ros)
    (: g (tar-gather? (sp-keep? rules) "." "")
       _ (!g ? (sp-die "cannot read the tree"))
       secs (sp-lev <>g top stamp ros)
       frags (sp-frags secs)
       h (sp-fmt spec + sha256 (cats frags))
       old (sp-read side)
       have (sp-read out)
       (? (two? old && two? have && <>old = h) 0
          (puts ("LOVE\t" + out), putc 10, sp-write out (sp-tree (sp-codecs spec) secs frags), sp-write side h, 0)))

   ; the listing: the tree's files under sb's law, less what is not the checkout's own
   (sp-ls _)
    (: rules ((cite 'sb 'igs 0) + (cite 'sb 'igsdir) + sp-laid)
       t (tar-thin? (sp-keep? rules) "." "")
       _ (!t ? (sp-die "cannot read the tree"))
       (each >(<>t) (e \ tar-get e 'kind 'file = 'file ? (puts (tar-get e 'nom "" + "\n")) 0), 0))

   (sp-main a0)
    (: _ (two? a0 && <a0 = "-l" ? (sp-ls 0, quit 0) 0)
       spec (two? a0 && <a0 = "-c" ? <>a0 "")
       av (two? a0 && <a0 = "-c" ? >>a0 a0)
       _ (sp-codecs spec)                              ; a bad table dies before the walk
       n #av
       _ (n < 4 ? (sp-die "usage: selfpack [-c CODECS] SRC.TREE TOP STAMP ROSTER [DROP..]"))
       out <av
       top <>av
       stamp <(sound <>>av)
       ros (sp-read (av 3) @ [1 s] (foldl (t \ w \ pin t w 1) {} (words s))
              (sp-die ("cannot read the roster " + av 3)))
       ; top joins the drops, or a release untarred at the root would ride the next blob
       drops (top . >>>>av)
       side (out + ".sha")
       ; `stat`, not a read: only whether the container is there. a () from the thin pass falls
       ; through to the cut
       rules (sp-rules drops)
       t (tar-thin? (sp-keep? rules) "." "")
       _ (!t ? (sp-die "cannot read the tree"))
       hq (tar-hash (foldl (+) () (sp-lev <>t top stamp ros)))
       old (sp-read side)
       quiet (string? hq && two? old && <>old = sp-fmt spec + hq && two? (stat out))
       (quiet ? 0 (sp-cut spec out side top stamp rules ros)))

   (sp-main >argv))
