; crew/reef/reef.l -- the reef: the patch-set vcs (doc/reef.md the interface,
; doc/hatch.md the model, test/patch.l + proof/rocq/patch.v the laws). this cut
; is the MVP's local half: `record` (working changes -> a patch in the store),
; `log`, `diff`; `sync` rides the same store next (patches + blobs are immutable
; content-addressed files, so union = copy what's missing + re-derive tips).
;
; the store (.reef/ at the working root):
;   blob/<sha256>    file content, immutable
;   patch/<sha256>   one patch, immutable -- (patch (note S) (time MS)
;                    (deps ID..) (hunks (PATH OLD NEW)..)), id = sha256 of the
;                    file's bytes; hunks path-sorted, deps sorted, so the text
;                    is deterministic and the address honest
;   tips             the maximal patches (the growth ends) -- (ID ..)
;   snap             the recorded state -- ((PATH CHASH PATCHID) ..) path-sorted
;   ignore           optional: one path prefix per line, atop (".reef" ".git" "out")
;
; a hunk is the PROVEN named-slot patch (test/patch.l's chg): slot = the path,
; context = the old content hash, value = the new -- () for absent (a birth or a
; death). patches touching disjoint paths commute (L3a), so sync's union needs
; no order; removal is a new patch whose hunk goes to () (the inverse-patch law:
; the set only grows). deps = for each touched path, the patch that wrote its
; context. finer-than-file hunks slot in later (the sequence slices are proven
; too); the store format doesn't care what a hunk's old/new mean.
;
; loads after crew/kore/text.l (lines) + crew/kore/diff.l (udiff) in the reef
; cat. body-less top-level `:` (the tool shape): the engine leaks into the cat's
; scope; the SEAT form at the tail is the only thing that fires as a program.
(:
   ; --- files ---
   (rf-look p) (: q (open p "r") (? q (: s (slurp q) _ (close q) `(1 s)) ()))   ; (1 text) | ()
   (rf-lay p s) (: q (open p "w") (? q (: _ (say q s) _ (close q) 1) 0))
   (rf-form p) (: q (open p "r")                                 ; the file's one form | ()
                  (? q (: r (sound q ()) _ (close q) (? (two? r) r ())) ()))

   ; --- the store ---
   (rf-mk _) (: _ (mkdir ".reef" 493) _ (mkdir ".reef/blob" 493) _ (mkdir ".reef/patch" 493) ())
   (rf-snap _) (rf-form ".reef/snap")                            ; ((path chash pid) ..) sorted
   (rf-tips _) (rf-form ".reef/tips")                            ; (id ..)
   (rf-blob h) (: t (rf-look (".reef/blob/" + h)) (? (two? t) <>t ()))
   (rf-keep s) (: h (sha256 s) _ (rf-lay (".reef/blob/" + h) s) h)
   (rf-patch id) (rf-form (".reef/patch/" + id))
   (rf-fld f k) (: (go m) (? (! (two? m)) ()                     ; a patch field's tail
                             (&& (two? <m) (id? <<m k)) ><m
                             (go >m))
                   (go >f))

   ; --- ignores: path prefixes; a line in .reef/ignore adds to the built-ins ---
   rf-igs0 '(".reef" ".git" "out")
   (rf-igs _) (: t (rf-look ".reef/ignore")
                 (? (two? t) (rf-igs0 + (filter (\ l (0 < (tally l))) (lines <>t)))
                    rf-igs0))
   (rf-ign? p igs) (? (! (two? igs)) 0
                      (: g <igs n (tally g)
                         (? (|| (p = g) (&& ((n + 1) < (tally p)) ((snip p 0 (n + 1)) = (g + "/"))))
                            1 (rf-ign? p >igs))))

   ; --- the walk: every regular file under the root, paths relative ---
   (rf-walk dir igs acc)
    (: es (readdir (? (! dir) "." dir))
       (go m acc)
        (? (! (two? m)) acc
           (: p (? (! dir) <m (dir + "/" + <m))
              (? (rf-ign? p igs) (go >m acc)
                 (: st (stat p)
                    md (? (two? st) (& 61440 <>>st) 0)
                    (? (md = 16384) (go >m (rf-walk p igs acc))
                       (md = 32768) (go >m (link p acc))
                       (go >m acc))))))
       (go es acc))

   ; --- the scan: working tree vs snap -> the hunks, path-sorted. PURE (no
   ;     blob writes); a hunk is (path old new), old/new content hashes | () ---
   (rf-h1 p e)                                                   ; one path vs its snap entry|()
    (: t (rf-look p)
       (? (! (two? t)) (? (two? e) `(p (<>e) ()) ())             ; unreadable: dead if known
          (: h (sha256 <>t)
             (? (! (two? e)) `(p () h)                           ; born
                ((<>e) = h) ()                                   ; unchanged
                `(p (<>e) h)))))                                 ; changed
   (rf-scan ps sn acc)                                           ; ps sorted paths, sn the snap
    (? (! (two? ps))
       (? (! (two? sn)) (rev acc)
          (rf-scan ps >sn (link `((<<sn) (<><sn) ()) acc)))      ; the tail of snap: dead
       (! (two? sn))
       (: h (rf-h1 <ps ()) (rf-scan >ps sn (? (two? h) (link h acc) acc)))
       (: p <ps e <sn
          (? (p = <e) (: h (rf-h1 p e) (rf-scan >ps >sn (? (two? h) (link h acc) acc)))
             (p < <e) (: h (rf-h1 p ()) (rf-scan >ps sn (? (two? h) (link h acc) acc)))
             (rf-scan ps >sn (link `((<e) (<>e) ()) acc)))))     ; snap-only: dead

   ; --- record ---
   (reef-record note)
    (: _ (rf-mk ())
       snap (rf-snap ())
       st (tablet 0)                                             ; path -> (chash pid)
       _ (: (go m) (? (two? m) (: _ (pin st <<m ><m) (go >m)) ()) (go snap))
       hunks (rf-scan (sort (rf-walk () (rf-igs ()) ())) snap ())
       (? (! (two? hunks)) (: _ (puts "reef: nothing to record\n") ())
          (: ; the blobs: keep every hunk's new content
             _ (: (go m) (? (two? m)
                            (: h <m _ (? (! <>>h) () (rf-keep <>(rf-look <h))) (go >m))
                            ())
                  (go hunks))
             ; the deps: the patches whose writes this one's contexts read
             deps (: (go m acc)
                      (? (! (two? m)) (sort acc)
                         (: old <><m
                            (? (! old) (go >m acc)
                               (: e (peep st <<m ())
                                  pid (? (two? e) <>e ())
                                  (? (|| (! pid) (member? pid acc)) (go >m acc)
                                     (go >m (link pid acc)))))))
                      (go hunks ()))
             ptext (show (list 'patch (list 'note note) (list 'time (clock 0))
                               (link 'deps deps) (link 'hunks hunks)))
             pid (sha256 ptext)
             _ (rf-lay (".reef/patch/" + pid) ptext)
             _ (rf-lay ".reef/snap" (show (rf-snap+ snap hunks pid ())))
             tips (filter (\ t (! (member? t deps))) (rf-tips ()))
             _ (rf-lay ".reef/tips" (show (sort (link pid tips))))
             _ (puts ("reef: recorded " + (snip pid 0 12) + " (" + (show (tally hunks)) + " paths)\n"))
             pid)))

   ; --- snap under a patch's hunks (both path-sorted) ---
   (rf-snap+ sn hs pid acc)
    (? (! (two? hs)) ((rev acc) + sn)
       (! (two? sn)) (: h <hs nw <>>h
                        (rf-snap+ () >hs pid (? (! nw) acc (link `((<h) nw pid) acc))))
       (: h <hs e <sn
          (? ((<h) = <e) (: nw <>>h
                            (rf-snap+ >sn >hs pid (? (! nw) acc (link `((<h) nw pid) acc))))
             ((<h) < <e) (: nw <>>h
                            (rf-snap+ sn >hs pid (? (! nw) acc (link `((<h) nw pid) acc))))
             (rf-snap+ >sn hs pid (link <sn acc)))))

   ; --- log: the patches newest first; * marks a tip ---
   (rf-ins e l) (? (! (two? l)) `(e)                             ; insert desc by time (seat 0)
                   ((<<l) <= <e) (link e l)
                   (link <l (rf-ins e >l)))
   (reef-log _)
    (: tips (rf-tips ())
       (go m acc)
        (? (! (two? m)) acc
           (: id <m f (rf-patch id)
              (? (! (two? f)) (go >m acc)
                 (go >m (rf-ins (list (cap (rf-fld f 'time)) id
                                      (cap (rf-fld f 'note))
                                      (tally (rf-fld f 'hunks)))
                                acc)))))
       es (go (readdir ".reef/patch") ())
       (pr m)
        (? (! (two? m)) ()
           (: e <m id <>e
              _ (puts (? (member? id tips) "* " "  "))
              _ (puts ((snip id 0 12) + "  " + (show <>>>e) + " paths"))
              nt <>>e
              _ (? (! nt) () (puts ("  " + nt)))
              _ (puts "\n")
              (pr >m)))
       _ (pr es)
       (tally es))

   ; --- diff: working tree vs the recorded state, unified; answers how many differ ---
   (reef-diff _)
    (: snap (rf-snap ())
       hunks (rf-scan (sort (rf-walk () (rf-igs ()) ())) snap ())
       (pr m n)
        (? (! (two? m)) n
           (: h <m p <h
              ot (? (! <>h) "" (rf-blob <>h))
              nt (? (! <>>h) "" (: t (rf-look p) (? (two? t) <>t "")))
              d (udiff (? (! <>h) "(none)" (p + " (recorded)"))
                       (? (! <>>h) "(gone)" p)
                       ot nt)
              _ (? (! d) () (puts d))
              (pr >m (n + 1))))
       (pr hunks 0)))

; the SEAT: fire reef-main iff reef sits in the program seat of the real command
; line -- the positional program or a -l preload -- taking the args after the
; seat. the cc.l shape; catted after the engine, quiet under any other name.
(: (bn p) (: n (tally p)
             (go k r) (? (k < n) (go (k + 1) (? ((p k) = 47) (k + 1) r)) (snip p r n))
             (go 0 0))
   (me? w) (: b (bn w) (|| (b = "reef") (b = "reef.l")))
   (seat a) (? (! (two? a)) ()
               (<a = "-l") (? (two? >a)
                              (? (me? <>a) (link 1 >>a) (seat >>a))
                              ())
               (me? <a) (link 1 >a)
               ())
   (usage _) (: _ (say err "reef -- the patch-set vcs (doc/reef.md; sync next)
usage: reef VERB ..
  record [NOTE]   working changes -> a patch in the store (.reef/)
  log             the patches, newest first (* marks a tip)
  diff            working tree vs the recorded state (unified; exit 1 on change)
")
                (quit 2))
   (reef-main as)
    (? (! (two? as)) (usage ())
       (: v <as
          (? (v = "record") (: _ (reef-record (? (two? >as) <>as "")) (quit 0))
             (v = "log") (: _ (reef-log ()) (quit 0))
             (v = "diff") (: n (reef-diff ()) (quit (? (0 < n) 1 0)))
             (usage ()))))
   s (seat >cmdline)
   (? (two? s) (reef-main >s) ()))
