; src/apps/tele/device.l -- sim-dev, a metered backend for tele's device seam, and a roofline.
; same math as tl-cpu, but each kernel tallies flops, bytes and launches into dv-stats;
; dv-roofline turns the tally into a time estimate for a named device.
;   cat src/apps/tele/tele.l src/apps/tele/device.l | out/love      # then (tl-use sim-dev)

(: ;; -- shape helpers (shape is a list) --
   (dv-prod l)   (two? l ? (<l * dv-prod >l) 1)
   (dv-rows v)   <(shape v)
   (dv-cols v)   <>(shape v)
   (dv-cells v)  (tray? v ? (dv-prod (shape v)) 1)
   dv-elsz 8                                           ; a gem is 8 bytes (f64)

   ;; -- the meter: a mutable tally the sim kernels feed --
   dv-stats {}
   (dv-reset _) (pins dv-stats 'flop 0 'byte 0 'launch 0)
   (dv-bump f b) (pins dv-stats
    'flop   (f + peep dv-stats 'flop 0)
    'byte   (b + peep dv-stats 'byte 0)
    'launch (1 + peep dv-stats 'launch 0))

   ;; per-kernel (flops . bytes): gemm 2mkn, reads A+B writes C; ew reads 2 writes 1
   (dv-gemm-cost a b) (: m (dv-rows a) k (dv-cols a) n (dv-cols b)
                       (2 * m * k * n . dv-elsz * (m * k + k * n + m * n)))
   (dv-ew-cost a)     (dv-cells a @ n (n . dv-elsz * 3 * n))
   (dv-red-cost a)    (dv-cells a @ n (n . dv-elsz * n))
   (dv-tr-cost a)     (dv-cells a @ n (0 . dv-elsz * 2 * n))

   ;; -- the sim backend: keys match tele's seam --
   sim-dev {'name "sim"
            'gemm   (a \ b \ (dv-gemm-cost a b @ c (dv-bump <c >c, inner a b)))
            'ew     (op \ a \ b \ (dv-ew-cost a @ c (dv-bump <c >c, op a b)))
            'reduce (a \ (dv-red-cost a @ c (dv-bump <c >c, net a)))
            'transp (m \ (dv-tr-cost m @ c (dv-bump <c >c, transp2 m)))}

   ;; -- the roofline: spec = { name tflops gbps }; time = max(flops/peak, bytes/bw) --
   (device name tflops gbps) (hash 'name name 'tflops tflops 'gbps gbps)
   (dv-roofline spec)
      (: f  (peep dv-stats 'flop 0)   b (peep dv-stats 'byte 0)
         tf (peep spec 'tflops 0 * 1e12) bw (peep spec 'gbps 0 * 1e9)
         tc (f / tf)  tm (b / bw)                       ; seconds
         t  (tc < tm ? tm tc)  bound (tc < tm ? "memory" "compute")
         love (!b ? 0 (f / b))                            ; flop/byte
         (puts "-- roofline on ", puts (peep spec 'name "?"), putc 10,
          puts "   flops     = ", puts (show f), putc 10,
          puts "   bytes     = ", puts (show b), putc 10,
          puts "   launches  = ", puts (show (peep dv-stats 'launch 0)), putc 10,
          puts "   intensity = ", puts (show love), puts " flop/byte", putc 10,
          puts "   est time  = ", puts (show (t * 1e3)), puts " ms (", puts bound, puts "-bound)", putc 10,
          t)))
