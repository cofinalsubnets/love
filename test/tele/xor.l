; the end-to-end gate for tele: a 2-layer mlp learns XOR over the pure constellation algebra
; (no host nif), so the same code runs on the host, wasm and inle. test/tele/grad.l checks each
; op alone; this asks whether they compose into a net that learns.
;   run:  cat test/00-init.l test/tele/xor.l test/zz-fin.l | out/love -l src/apps/tele/tele.l
; not in the corpus: tele is no module, so it arrives on -l; zz-fin.l prints the "N tests pass"
; line, since a reader that stops early leaves the tests below unrun and exits 0.
; the net: 2 -> H (tanh) -> 1 (sigmoid), full-batch sgd on mse. seeded, so the rounding and
; the loss ceiling are deterministic, not a tolerance.

(: _ (rng-set (wheel 1))
   H 8  lr 0.6  epochs 4000  ceil 0.01     ; the observed final loss is ~2e-4

   X (gem-tray '(4 2) '(0.0 0.0  0.0 1.0  1.0 0.0  1.0 1.0))   ; the four inputs
   Y (gem-tray '(4 1) '(0.0 1.0 1.0 0.0))                       ; XOR of each

   model (seq [(linear 2 H) tanh (linear H 1) sig])
   opt   (sgd (params model) lr)

   ; a dummy arg: a nullary call (f) answers f, it does not fire
   (trainstep _) (: _ (tl-reset 0) _ (zero opt)
                  loss (mse (call model X) Y) (back loss, step opt, tl-val loss))
   (loop k lv) (k = 0 ? lv
                  (trainstep 0 @ nv
                   ((? (0 = k % 1000) (puts $
                     "epoch " + show (epochs - k) + "   loss " + show nv + "\n")),
                    loop (k - 1) nv)))

   _ (puts "training a 2-8-1 MLP on XOR ...") _ (putc 10)
   final (loop epochs 1.0)
   _ (putc 10)

   ; the learned outputs (want ~0 1 1 0)
   _ (tl-reset 0)
   out (tl-val (call model X))
   (cell k) (peep out (k . 0 . ()) 0)
   (yes k v) (0.5 < cell k ? (v = 1) (v = 0))               ; does row k round to v?
   (puts $ "00 -> " + show (cell 0) + "\n",
    puts $ "01 -> " + show (cell 1) + "\n",
    puts $ "10 -> " + show (cell 2) + "\n",
    puts $ "11 -> " + show (cell 3) + "\n",
    puts $ "final loss " + show final + " (ceiling " + show ceil + ")\n",

    ; both halves: rounding alone passes a net that merely leans the right way
    (test (yes 0 0) (yes 1 1) (yes 2 1) (yes 3 0) (final < ceil)),
    0))
