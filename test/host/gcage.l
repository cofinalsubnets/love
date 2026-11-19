; test/host/gcage.l -- a minor tenures only what outlived the minor before: a list kept across one
; minor stays young, one kept across two tenures, young a tenured tablet holds stays young
; while it is replaced each minor, and lives whole through the minors that move it. not in the corpus: live-word counts
; differ by reader door. run: cat test/00-init.l test/host/gcage.l | out/love

(: G_GC 3 G_OLD 8 G_MINOR 11
   (gget i) (peep (gauge 0) i 0)
   (majors _) (gget G_GC - gget G_MINOR)
   _ (please 1)                                     ; a clean start, all of it tenured

   ; a fresh 4k list kept across one minor, dropped after it
   (once _) (: keep (map (+ 1) ^4000) _ (please ()) #keep)
   o0 (gget G_OLD) m0 (majors 0)
   _ (each ^16 once)
   o1 (gget G_OLD) m1 (majors 0)

   ; ..and across two
   (twice _) (: keep (map (+ 1) ^4000) _ (please ()) _ (please ()) #keep)
   _ (each ^4 twice)
   o2 (gget G_OLD)

   ; young pinned into a tenured tablet, replaced before the next minor
   mt {} _ (please 1)
   o3 (gget G_OLD)
   (repin _) (pin mt 'l (map (+ 1) ^4000), please ())
   _ (each ^16 repin)
   o4 (gget G_OLD)

   ; young held only by a tenured tablet, moved by the minors after its pin, read whole
   t {} _ (please 1)
   _ (pin t 'l (map (+ 1) ^4000))
   _ (please ()) _ (please ()) _ (please ())
   s1 (net (t 'l))
   _ (pin t 'l (map (+ 2) ^4000))
   _ (please ()) _ (pin t 'm (map (+ 3) ^10)) _ (please ()) _ (please ())
   s2 (net (t 'l)) s3 (net (t 'm))

   (test (m1 = m0)                                  ; the churn took minors only
         (o1 - o0 < 4000)                           ; ..and tenured none of its lists
         (o2 - o1 > 4 * 4000)                       ; a list kept across two tenures
         (o4 - o3 < 4000)                           ; ..and none a tenured tablet held a minor
         (s1 = 8002000) (s2 = 8006000) (s3 = 75),
    test_fin (),
    puts "gcage: ok",
    putc 10))
