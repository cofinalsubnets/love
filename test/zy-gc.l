; the collector's shape, which degrades while staying correct: no major latch (gauge 9 is 0),
; and the remembered set stays clear of its cap, whose overflow forces a major
(: g (gauge 0) n (peep g 3 0) m (peep g 11 0)
 (test (n < 64 || 2 * m > n) (0 = peep g 9 0) (peep g 10 0 < 4096)))
