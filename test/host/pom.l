; test/host/pom.l -- the phase of the moon (src/apps/pom.l), against the perl pom's answers
;   cat test/00-init.l test/host/pom.l | out/love
(borrow 'pom)
(: (said h m d y) ("The Moon is " + pom-name (pom-phase h m d y) + " (" + show (pom-percent (pom-phase h m d y)) + "% of Full)")
   art (pom-art (pom-phase 12 9 23 2026) 38 9 "9/23/2026:12")
   (test (2461307 = pom-julian 9 23 2026)
         (2299170 = pom-julian 10 14 1582)                  ; the julian calendar's last day
         (2299161 = pom-julian 10 15 1582)                  ; ..and gregory's first
         (abs (pom-phase 12 9 23 2026 - 0.401967376881775) < 0.000000001)
         ("The Moon is Waxing Gibbous (81% of Full)" = said 12 9 23 2026)
         ("The Moon is Waning Crescent (33% of Full)" = said 23 12 31 1999)
         ("The Moon is Waxing Crescent (43% of Full)" = said 20 7 20 1969)
         ("The Moon is Waning Crescent (10% of Full)" = said 12 10 14 1582)
         ("The Moon is Waxing Gibbous (74% of Full)" = said 0 6 7 5)
         ("Date : 9/23/2026:12::0@@@@@@@@@\nPhase: Waxing Gibbous::::@@@@@@@@@@@@@@@@\nFull : 81%::::+@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n       ::::+@@@@@@@@@@@@@@@@@@@\n         ::::@@@@@@@@@@@@@@@@\n             ::0@@@@@@@@@\n" = art),
    puts "pom: ok\n"))
