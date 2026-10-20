; the tty apps on a pty, scribed onto a quay screen. the child sizes itself by stty: a fresh
; pty is 0x0 and a parent's settty races its first read. no bare ESC: ESC then a key is alt.
; tether is not in love0, so no corpus. run: cat test/00-init.l test/host/00-host.l test/host/tty.l | out/love
(borrow 'synth)
(: reaped {}
   deadline 20000
   (waitfor pid) (gather pid @ s
                    (two? s || nom? s ? (pin reaped pid 1, s) (do (rest 2) (waitfor pid))))
   ; the child's whole session goes at the deadline, so its law reads red
   (watch pid t0) (? (peep reaped pid 0) 0
                     (deadline < clock t0) (still (0 - pid) 9)
                     (rest 50, watch pid t0))
   (guard t) ((two? t ? (twirl (_ \ watch <t (clock 0)) 0) 0), t)
   ; read until n has passed, a chunk at a time: a byte at a time is slower than a box stays deaf
   (wire p n) (: (go acc) (see p @ ch
                             (ch = -1 ? acc
                                (: acc2 (acc + string ch + chug p)
                                   from (max 0 (#acc - #n))
                                   (0 <= findsub (snip acc2 from #acc2) n ? acc2 (go acc2)))))
                 (go ""))
   (blank? t) (foldl (a \ ch \ (a && ch = 32)) 1 t)
   (count h n) (: k #n m #h
                  (go i c) (? (m - k < i) c
                              (n = snip h i (i + k)) (go (i + k) (c + 1))
                              (go (i + 1) c))
                  (go 0 0))
   ; up to the last 1049 leave, else quay lays the empty primary screen over the last frame
   (held h) (: n #h k 8
               (go i best) (? (n < i + k) best
                            ("\e[?1049l" = snip h i (i + k)) (go (i + 1) i)
                            (go (i + 1) best))
               (go 0 -1 @ b (b < 0 ? h (snip h 0 b))))
   (chat s i) (2097151 & glass s i 0)
   (cbg s i) (glass s i 2 @ k (k >> 24 = 1 ? (k & 255) 0))
   (rowtx s r) (gaze s 2 @ c
                  (foldl (a \ i \ (a + (chat s (r * c + i) @ ch (0 = ch ? " " (utf8 ch)))))
                         "" (jot c)))
   ; the floor is seeded off the clock: that @ stands somewhere is the law, not where
   (at s) (: c (gaze s 2) r (gaze s 1)
             (go i) (? (r * c <= i) () (64 = chat s i) ((i // c) . (i % c)) (go (i + 1)))
             (go 0))
   (spawn cmd r c)
    (guard (tether ["sh" "-c" ("stty rows " + show r + " columns " + show c + " -echo; exec " + cmd)]))
   ; -> [stream screen]
   (run cmd keys r c)
    (: t (spawn cmd r c)
       _ (test (two? t))
       m >t
       _ (say m keys)
       txt (slurp m)
       _ (waitfor <t)
       s (h-mkscr r c)
       (scribe s (held txt),
        [txt s]))

; tower: the bar on the last row; 20x70, since a sizeless climb's fallback is exactly 24 rows
 a (run "out/love lore tower" "q" 20 70)
 _ (test
    (has? <a "\e[?1049h")
    ("finally, the tower" = snip (rowtx <>a 0) 0 18)
    ("the garden" = snip (rowtx <>a 19) 0 10)
    (has? <a "you leave the tower"))
 ; the opening sign hides the floor, so where you stand is asked below

; a turn spends the note: a blank row 0 is the climb saying it read a key
 b (run "out/love lore tower" "hjklq" 20 70)
 _ (test
    (blank? (rowtx <>b 0))
    ("the garden" = snip (rowtx <>b 19) 0 10)
    (at <>b))

; an arrow is one key: a bare ESC would quit with the note still on row 0
 c (run "out/love lore tower" "\e[Chq" 20 70)
 _ (test (blank? (rowtx <>c 0)) (has? <c "you leave the tower"))

; keys left behind the quit must not reach the shell: z takes the sign down, q leaves,
; and the non-blocking cat reads whatever survived
 dr (: t (guard (tether ["sh" "-c" ("stty rows 20 columns 70 -echo; out/love lore tower; "
                                    + "stty -icanon min 0 time 3; cat")]))
       m >t
       ; wait for raw mode, else the echo hides the leftovers
       _ (rest 500)
       _ (say m "zqzzzz")
       txt (slurp m)
       (waitfor <t,
        txt))
 _ (test (has? dr "you leave the tower")
         !(has? dr "zzzz"))

; slop's sign is deaf for half a second, so a key typed then is eaten: counted by
; cursor-homes (one per frame), where a heard key would lay many
 sgt (spawn "out/love lore slop phone 38" 14 64)
 sgm >sgt
 sgseen (wire sgm "-- any key --")
 _ (say sgm "z")
 _ (rest 800)
 _ (say sgm "\rq")
 sgtx (sgseen + slurp sgm)
 _ (waitfor <sgt)
 _ (test
    (has? sgtx "is this still the tower?")
    (has? sgtx "phone")
    (has? sgtx "38 pennies")
    (has? sgtx "forward remains")   ; wrapped at 64
    (4 > count sgtx "\e[H"))
 sn (run "out/love lore slop" "q" 14 64)
 _ (test !(has? <sn "forward remains"))

; slop: only forward moves; type once the road's pen is on the wire, the shore being off screen
 st (spawn "out/love lore slop" 12 40)
 sm >st
 sseen (wire sm "\e[38;5;94m")
 _ (say sm "k")
 _ (rest 200)
 _ (say sm "jlq")
 stx (sseen + slurp sm)
 _ (waitfor <st)
 ss (h-mkscr 12 40 @ s (scribe s (held stx), s))
 _ (test
    (has? stx "\e[?1049h") (has? stx "\e[?1049l")
    !(has? stx "\e[48;5;")
    !(has? stx "\e[38;5;180m")
    (0 = cbg ss 0)
    ((9 . 23) = at ss)
    (46 = chat ss (9 * 40 + 24))
    (has? (rowtx ss 11) "you turn back")
    (has? stx "you turn back, 1 press in\r\n"))   ; j and l spent nothing; the line ends

; story: a level file is a fixed map, so the place is a law
 d (run "out/love lore story" ":q\r" 14 60)
 _ (test
    (has? <d "the lighthouse")
    ((8 . 6) = at <>d))
 e (run "out/love lore story" "k:q\r" 14 60)
 _ (test ((7 . 6) = at <>e))
; synth: ESC and a key in one write is alt, striking the quarter tone, not ESC then a plain note
 sq (synth-new ())
 c4 (synth-digits 0 . synth-name (synth-semis sq [0 0 0]))  ; as the legend cells them
 an (synth-name (synth-semis sq [0 0 1]))
 sy (spawn "env HORN=none out/love synth" 16 70)
 sm >sy
 a1 (wire sm (string <c4 + " " + >c4))
 _ (say sm "\e1", flush sm)
 _ (rest 300)
 _ (say sm "q", flush sm)
 a2 (slurp sm)
 _ (waitfor <sy)
 _ (test !(has? a1 an) (has? a2 an))
; shaft and court: a frame of half blocks, and q ends it
 (blocks m acc k n) ((k < n ? (see m) -1) @ c
                       (c < 0 ? acc
                        (: acc2 (acc + string c) l #acc2
                           (blocks m acc2 (k + (3 <= l && "▀" = snip acc2 (l - 3) l)) n))))
 sh (spawn "env HORN=none out/love lore shaft" 12 70)
 shm >sh
 b1 (blocks shm "" 0 840)
 ((say shm "q", flush shm),
  slurp shm,
  waitfor <sh,
  test (840 <= #b1 // 3),
  (: cs (spawn "env HORN=none out/love lore court" 12 70) csm >cs
     b2 (blocks csm "" 0 840)
     ((say csm "q", flush csm), slurp csm, waitfor <cs, test (840 <= #b2 // 3))),
  test_fin (),
  puts "tty: ok"))
