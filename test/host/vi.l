; --- test/host/vi.l: vi on berth's harbour, over a real pty ---
; not in the test/*.l corpus (the harbour rides screen/scribe/tether in inle/*.c). the
; engine's laws are test/law/vi.l; this is the visit: a buffer berthed as a stage,
; :vs and :sp opening another beside or under it, the prefix steering the focus, and
; :q shutting the one it is typed in until the last leaves.
;   cat test/00-init.l test/host/vi.l | out/love

(borrow 'posix)

(: (sub? h n i) ((i + #n) < (#h + 1) ? (n = snip h i (i + #n) ? 1 (sub? h n (i + 1))) 0)
   ; type, and take what came back within a beat
   (drink m) (:- (go "") (go acc) (? (cue? m) (: b (cask 4096) n (swig m b)
                                                  (? (charm? n && 0 < n) (go (acc + snip b 0 n)) acc))
                                    (rest 150, cue? m) (go acc)
                                    acc))
   (say! m s) (: _ (say m s) _ (flush m) (drink m))
   md (tether ["out/love" "vi"])
   _ (test (two? md))
   m >md
   _ (rest 1200)
   b0 (drink m)
   b1 (say! m "ihello\e")
   b2 (say! m ":vs\r")                     ; a fresh buffer beside, 39 + bar + 40
   b3 (say! m "isecond\e")
   b4 (say! m "\x01h")                     ; C-a h: the focus back to the first
   b5 (say! m "Aagain\e")
   b6 (say! m ":sp\r")                     ; a third, under the first
   b7 (say! m ":q\r")                      ; ... and shut again
   b8 (say! m ":q!\r")                     ; the first, dirty
   b9 (say! m "\x01l:q!\r")                ; the last one leaves, and so does vi
   st (: (wf p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wf p))) (wf <md))
 (test (sub? b0 "\e[?1049h" 0)
       (sub? b1 "hello" 0)
       (sub? b2 "\e[1;40H" 0) (sub? b2 "\e[2;41H" 0)
       (sub? b3 "second" 0)
       (sub? b5 "helloagain" 0)
       (sub? b9 "\e[?1049l" 0)
       (two? st)))

(test_fin ())
(puts "vi: ok -- a buffer is a berth, :vs and :sp open another, and :q shuts the one it is in\n")
