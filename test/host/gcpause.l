; test/host/gcpause.l -- the pause gauge: a minor copies the nursery's survivors and stays flat
; as the tenured set grows 16x; a major copies the live set, linearly. words carry the asserts,
; wall ns ride in the table only. the model's theorems are test/proof/rocq/gc.v's
; minor_work_bounded and minor_flat; this is their instance check.
;   gauge[7] words copied in all  gauge[8] old live  gauge[14] minor peak  gauge[15] major peak
; not in the corpus: live-word counts differ by reader door. run: cat test/00-init.l test/host/gcpause.l | out/love

(: G_LEN 0 G_GC 3 G_EVAC 7 G_OLD 8 G_MINOR 11 G_MAJCAP 12 G_MINHI 14 G_MAJHI 15
   (gget i) (peep (gauge 0) i 0)
   (mx a b) (a < b ? b a)

   ; one churn step: raise a fresh 4k list, force a minor under it (the list
   ; is the survivor set), answer `(minors words ns) for that one collection --
   ; counting minors specifically, so the asserts prove nothing escalated.
   (step _) (: e0 (gget G_EVAC) g0 (gget G_MINOR)
               keep (map (+ 1) (jot 4000))
               t0 (nclock 0)
               _  (please ())
               ns (nclock t0)
               dg (gget G_MINOR - g0) de (gget G_EVAC - e0)
               (#keep,                        ; keep lives across the minor
                [dg de ns]))

   ; k steps -> `(worst-words worst-ns collections) over the window
   (churn k) (: (go i ww wn cs)
                (i < k ? (step () @ r
                        (go (i + 1) (mx ww <>r) (mx wn <>>r) (cs + <r)))
                       [ww wn cs])
              (go 0 0 0 0))

   ; tenure n 64KB casks: build them young, then the timed forced major
   ; promotes them -> `(major-words major-ns casks); the casks ride in the
   ; answer so a later read holds every level live to the end. the major
   ; sizes its pool for the test that forced it, so the churn that follows
   ; fires minors only.
   (tenure n) (: l (map (_ \ (cask 65536)) (jot n))
                 e0 (gget G_EVAC)
                 t0 (nclock 0)
                 _  (please 1)
                 ns (nclock t0)
                 de (gget G_EVAC - e0)
               [de ns l])

   (row maj r) (puts "live-w ",
                putx (gget G_OLD),
                puts "  major-w ",
                putx <maj,
                puts "  major-ns ",
                putx <>maj,
                puts "  minor-worst-w ",
                putx <r,
                puts "  minor-worst-ns ",
                putx <>r,
                putc 10)

   ; three levels, 12x tenured growth end to end, every level held live
   t1 (tenure 16)  r1 (churn 8) _ (row t1 r1)
   t2 (tenure 48)  r2 (churn 8) _ (row t2 r2)
   t3 (tenure 192) r3 (churn 8) (row t3 r3,
                                 (#<>>t1 + #<>>t2 + #<>>t3), ; every cask list live past the last minor

                                 test (8 = <>>r1) (8 = <>>r2) (8 = <>>r3)     ; every churn collection was a minor, one each
           (0 < <r1)                               ; the minors did real work (the claim isn't vacuous)
           (<r2 < <r1 + 1024)                      ; the flat line: 12x the tenured set moves the
           (<r3 < <r1 + 1024)                      ;   worst minor by less than 8KB of copy volume
           (<t1 < <t2) (<t2 < <t3)                 ; the major's work grows with the live set
           (<r1 <= gget G_MINHI)                   ; the whole-run peaks cover what we watched
           (<t3 <= gget G_MAJHI),

                                 test_fin (),
                                 puts "gcpause: ok",
                                 putc 10))
