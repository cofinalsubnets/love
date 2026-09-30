; src/tools/selfpack.l -- cut the source archive from the tree itself.
;
;   love src/tools/selfpack.l archive.tar.gz top [stamp [build [drop..]]]
;
; the one cutter, every world: the tree on disk is the source, checkout and seed-laid
; tree alike. what it leaves out is sb's law -- .sbignore plus sb's built-ins, so the vcs
; walk and this cut cannot disagree about what the tree is -- plus sp-own's structural
; skips and each drop nom. the walk is sorted and every mtime pinned to stamp, so the same
; files answer the same bytes wherever they sit; test_distboot holds a re-cut to the byte.
; `build` rides in as top/STAMP, a file no tree holds: the stamp that orders two builds of
; one VERSION, which an unpacked release reads back where there is no git to ask.
;
; the id is the sha of the LEVELED tar, kept in archive.sha, so a touch settles and a
; delete or rename is seen. the quiet pass (tar-thin? + tar-hash) answers "has the tree
; moved" off stat alone, holding neither the bodies nor the tar; only the cut writes the
; sidecar, so what .sha names is always the archive that was written.
;
; the coder is src/love/lib/gz.c through gz.l's door -- love0 carries no nifs, which is why the
; recipe prefers the tree's own love.
;
; the borrows below name PATHS, in dependency order. a module name has nothing to find
; under love0 (gcc-built from the src/love/boot/*.l headers, no image), and `-l FILE` whose
; basename names a verb SEATS it (post.l's seatof), so `-l src/apps/sb/sb.l` would run sb.
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
   (sp-keep? rules nom) ((nom = ".sbignore") || !(sp-ign? nom rules))
   ; re-home the kept entries under top; the walk is sorted, so order holds.
   (sp-take es top acc)
    (? (atom? es) (rev acc)
       (: e <es
          _ (pin e 'nom (top + "/" + tar-get e 'nom ""))
          (sp-take >es top (e . acc))))

   ; the root leads, top follows wearing its mode, then STAMP, then moon's toolchain slice
   ; (include/ and lib/, what src/apps/moon/moon.l's mblob reads when there is no nest), then
   ; the rest, each re-homed under top: a nestless compile stops reading past the slice
   ; instead of inflating the tree for it. shared by both passes, so their digests compare.
   (sp-slice? e) (: n (tar-get e 'nom "")
                    (starts? n "src/apps/moon/include/" || starts? n "src/apps/moon/lib/"
                     || n = "src/apps/moon/include" || n = "src/apps/moon/lib"))
   (sp-lev es top stamp build)
    (: root <es
       te (tar-entry top 'dir "")
       _ (pin te 'mode (tar-get root 'mode 493))
       se (tar-entry "STAMP" 'file (build + "\n"))
       rest (filter sp-slice? >es + filter (e \ !(sp-slice? e)) >es)
       (tar-level (root . te . sp-take (se . rest) top ()) stamp))

   ; the cut that reads: pack, hash, and write when the content actually moved.
   (sp-cut arch side top stamp build rules)
    (: g (tar-gather? (sp-keep? rules) "." "")
       _ (!g ? (sp-die "cannot read the tree"))
       lev (sp-lev <>g top stamp build)
       a (tar-pack lev)
       _ (!a ? (sp-die "cannot pack (a path too long for ustar?)"))
       h (sha256 a)
       old (sp-read side)
       have (sp-read arch)
       fresh (two? old && two? have && <>old = h)
       ; an archive with no sidecar (a seed-laid tree) is adopted when its content is
       ; this content -- no rewrite, so its mtime holds and nothing downstream re-links.
       adopt (? (fresh || atom? have) 0
                (: u (gz-unzip <>have) (two? u && <>u = a)))
       (? fresh 0
          adopt (sp-write side h)
          (: z (gz-zip9 a "" 0)                ; written once, carried in every artifact: the harder coder
             (puts ("LOVE\t" + arch), putc 10, sp-write arch z, sp-write side h, 0))))

   (sp-main av)
    (: n #av
       _ (n < 2 ? (sp-die "usage: selfpack ARCHIVE.tar.gz TOP [STAMP [BUILD [DROP..]]]"))
       arch <av
       top <>av
       stamp (3 <= n ? <(sound <>>av) 0)
       build (4 <= n ? (av 3) "0")
       ; top joins the drops: a release untarred at the root would otherwise ride the
       ; next blob, and the artifact would swallow a whole second love.
       drops (top . (4 <= n ? >>>>av ()))
       side (arch + ".sha")
       ; `stat`, not a read: the question is only whether the archive is there. a ()
       ; from the thin pass (a torn read, a nom too long for ustar) is not an answer
       ; and falls through to the cut, which reads each file once.
       rules (sp-rules drops)
       t (tar-thin? (sp-keep? rules) "." "")
       _ (!t ? (sp-die "cannot read the tree"))
       hq (tar-hash (sp-lev <>t top stamp build))
       old (sp-read side)
       quiet (string? hq && two? old && <>old = hq && two? (stat arch))
       (quiet ? 0 (sp-cut arch side top stamp build rules)))

   (sp-main >argv))
