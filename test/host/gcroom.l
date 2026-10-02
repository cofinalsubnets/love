; test/host/gcroom.l -- after a major, the minors have room to promote into, whatever the
; nursery: a forced minor stays a minor. the nursery floor is raised past a quarter of the
; live set, the live set steps across one major0 step so no rounding of the pool carries
; the claim, and each run forces two majors so the second sees no dead set. hostnif's fork
; lane runs it, the child on the shell's warm heap.

(: GR_EVAC 7 GR_MINOR 11
   (gr-get i) (peep (gauge 0) i 0)
   was (tune ())
   step (was 2)
   _ (tune [(was 0) (2 * 1048576) step (was 3)])          ; a 2M-word nursery floor
   _ (please 1)

   ; one live set: base casks plus an offset of k eighths of a step, then the forced majors,
   ; then sixteen forced minors each promoting a fresh 4000-cell list -> the minors counted
   (gr-run k)
    (: l (map (_ \ cask 65536) ^64) x (cask (k * step)) _ (please 1) _ (please 1)
       g0 (gr-get GR_MINOR)
       (go i) (? (i < 16) (: keep (map (+ 1) ^4000) _ (please ()) (#keep, go (i + 1))) 0)
       _ (go 0)
       (#l + #x, gr-get GR_MINOR - g0))
   runs (map gr-run ^8)
   _ (tune was)

   _ (test (runs = [16 16 16 16 16 16 16 16]))                    ; every forced minor stayed a minor
   (test_fin (), puts "gcroom: ok", putc 10))
