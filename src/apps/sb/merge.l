; src/apps/sb/merge.l -- diff3: the three-way line merge for two patches writing one path
; from a shared base.
;
; myers each side against the base, read as slots alternating gap/line/../gap: a substitution
; moves a line slot, an insertion a gap slot. a maximal run where either side differs from
; the base resolves by comparison:
;   ours = theirs   -> both made the same edit, take it (convergent)
;   ours = base     -> only theirs moved, take theirs
;   theirs = base   -> only ours moved, take ours
;   otherwise       -> a true overlap: markers, and the caller counts it
; adjacent edits with no stable line between them conflict. a final unterminated line gains
; its newline.

(module 'sb
(borrow 'kore) ; myers, lines
(:
   ; the 'adds sitting at the front of a script (a del's replacement)
   (m3grab m a) (two? m && <<m = 'add ? (m3grab >m (<><m . a)) [m (rev a)])

   ; a myers script -> the 2n+1 slots, gap line .. gap. an 'add after a keep lands in the
   ; open gap; the 'adds after a del are that line's replacement, in its line slot
   (m3parts sc)
    (:- (go sc () ())
     (go m gp acc)
      (atom? m ? (rev (rev gp . acc))
       (: o <m op <o x <>o acc2 (rev gp . acc)                   ; the gap closes on a line op
        (op @ 'keep (go >m () ([x] . acc2))
              'del (m3grab >m () @ r (go <r () (<>r . acc2)))
              (go >m (x . gp) acc)))))                            ; 'add: into the open gap

   ; the base's own slots: every gap empty, every line its one line
   (m3base b) (:- (go b ()) (go m a) (two? m ? (go >m ([<m] . (() . a))) (rev (() . a))))

   ; the chunks (a list of line-lists) -> one flat line list
   (m3cat cs) (:- (go cs ()) (go m a) (two? m ? (go >m (a + <m)) a))

   ; the marker block for a true overlap
   (m3marks ob tb ol tl)
    ((("<<<<<<< " + ol) . ob) + ("=======" . (tb + [(">>>>>>> " + tl)])))

   ; walk the three part-lists in step -> (chunks nconflicts), chunks newest-first
   (m3go bs os ts ol tl acc nc)
    (? (atom? bs) [acc nc]
       (<os = <bs && <ts = <bs) (m3go >bs >os >ts ol tl (<bs . acc) nc)
       (: (run b o t bb ob tb)                                        ; extend while either side moved
           (two? b && (<o != <b || <t != <b) ?
              (run >b >o >t (<b . bb) (<o . ob) (<t . tb))
              [b o t (m3cat (rev bb)) (m3cat (rev ob)) (m3cat (rev tb))])
          r (run bs os ts () () ())
          bb <>>>r ob <>>>>r tb <>>>>>r
          (? (ob = tb) (m3go <r <>r <>>r ol tl (ob . acc) nc)        ; the same edit both sides
             (ob = bb) (m3go <r <>r <>>r ol tl (tb . acc) nc)        ; only theirs moved
             (tb = bb) (m3go <r <>r <>>r ol tl (ob . acc) nc)        ; only ours moved
             (m3go <r <>r <>>r ol tl (m3marks ob tb ol tl . acc) (nc + 1)))))

   ; three texts + the two side labels -> (mergedtext nconflicts)
   (diff3 base ours theirs ol tl)
    (: b (lines base)
       bp (m3base b)
       op (m3parts (myers b (lines ours)))
       tp (m3parts (myers b (lines theirs)))
       r (m3go bp op tp ol tl () 0)
       [(unlines (m3cat (rev <r))) <>r]))

) ; module 'sb
