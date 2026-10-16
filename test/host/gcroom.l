; test/host/gcroom.l -- after a major, a forced minor stays a minor, whatever the nursery
; the live set steps across one major0 step so no pool rounding carries the claim; two majors
; per run so the second sees no dead set

(: GR_EVAC 7 GR_MINOR 11
   (gr-get i) (peep (gauge 0) i 0)
   was (tune ())
   step (was 2)
   _ (tune [(was 0) (2 * 1048576) step (was 3)])          ; a 2M-word nursery floor
   _ (please 1)

   (gr-run k)                                         ; k eighths of a step past the base -> minors counted
    (: l (map (_ \ cask 65536) ^64) x (cask (k * step)) _ (please 1) _ (please 1)
       g0 (gr-get GR_MINOR)
       (go i) (? (i < 16) (: keep (map (+ 1) ^4000) _ (please ()) (#keep, go (i + 1))) 0)
       _ (go 0)
       (#l + #x, gr-get GR_MINOR - g0))
   runs (map gr-run ^8)
   _ (tune was)

   _ (test (runs = [16 16 16 16 16 16 16 16]))
   (test_fin (), puts "gcroom: ok", putc 10))
