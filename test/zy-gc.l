; the collector's shape: both degenerate while staying correct, so no other assert reads
; them, and both are vacuous in a lane that barely collects.
; latch -- please majors while major_free < g->len, so a pool left with no room past a
; nursery's promotion (a budget's, or a denied spare's) forces one at every collection;
; a latch reads 0.
; rem set -- an overflow is sound (a miss forces a major) but gen_remembered is a linear
; scan, so a grown set costs quadratically. peak 19 baked, 154 egg, 230 stress, cap 4096.
(: g (gauge 0) n (peep g 3 0) m (peep g 11 0)
 (test (n < 64 || 2 * m > n) (0 = peep g 9 0) (peep g 10 0 < 1024)))
