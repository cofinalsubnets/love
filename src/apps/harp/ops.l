; ops -- voices as small operator graphs for the tones kernel (src/love/audio/tones.h): an
; operator's row from a tablet, and a voice in play's shape. test/host/ops.l holds the kernel to
; the same arithmetic worked out in love.
;   (ops-row o)        an operator's 49 numbers from a tablet: 'f 'slide 'drop 'kappa 'wave 'mod
;                      'depth 'fb 'l 'r 'vib 'vrate 'trem 'trate 'am 'duty 'lvl, 'segs [[t0 kind a b
;                      c] ..], 'at the frame its voice starts; what is missing 0, 'mod and 'am -1,
;                      'duty 0.5, 'lvl 1
;   (ops-rows os)      the operators' rows, one float tray
;   (ops-run R os st n f0 rate ws)  the kernel over rows R (of operators os) for n frames from f0,
;                      st their last two outputs each (() at rest): n of left then n of right,
;                      each operator's last two outputs, then scratch unless ws, a (tones-ws k)
;                      big enough, holds it; silence on a seat built without the kernel
;   (ops-voice os at end gl gr rate)  play's voice [end fn gl gr raw], fn the left the operators
;                      sum to, their outputs fed back from one run to the next
(module (ops ops-row ops-rows ops-run ops-voice ops-db)
(:
 width 49
 ops-db 8.685889638065035                ; dB a neper: 20 / ln 10
 (ops-row o) (: (g k d) (peep o k d) ss (o 'segs)
   ([(1.0 * g 'at 0) (1.0 * g 'f 0) (1.0 * g 'slide 0) (1.0 * g 'drop 0) (1.0 * g 'kappa 0) (1.0 * g 'wave 0)
    (1.0 * g 'mod -1) (1.0 * g 'depth 0) (1.0 * g 'fb 0) (1.0 * g 'l 0) (1.0 * g 'r 0) (1.0 * g 'vib 0)
    (1.0 * g 'vrate 0) (1.0 * g 'trem 0) (1.0 * g 'trate 0) (1.0 * g 'am -1) (1.0 * g 'duty 0.5) (1.0 * g 'lvl 1)
    (1.0 * #ss)] + catmap (map (* 1.0)) ss + map (_ \ 0.0) ^(5 * (6 - #ss))))
 (ops-rows os) (gem-tray [(width * #os)] (catmap ops-row os))
 kern (cite 'dsp 'tones)
 kern-ws (cite 'dsp 'tones-ws)
 (ops-run R os st n f0 rate ws) (kern ? (kern R st n f0 rate ws) (gem-tray [(2 * n + 2 * #os)] (map (_ \ 0.0) ^(2 * n + 2 * #os))))

 ; --- a voice: the kernel run for the frames asked, outputs carried; frames asked out of
 ;     order rerun from the start ---
 (ops-voice os at end gl gr rate) (: k #os os0 (map (o \ pin o 'at at) os) R (ops-rows os0) box {'next at 'ys () 'wk 0 'ws ()}
   S (iota (2 * k) + 0)
   ; the kernel's scratch, kept from run to run and grown when a run is longer
   (ws n) (: m (k * n) (box 'wk >= m ? (box 'ws) (pins box 'ws (kern-ws && kern-ws m) 'wk m @ b (b 'ws))))
   (run f0 n) (: r (ops-run R os0 (box 'ys) n f0 rate (ws n)) (pins box 'next (f0 + n) 'ys (peep r (S + 2 * n) 0.0), r))
   (reach f0) (? (f0 = box 'next) 0
                 (f0 <= at) (pins box 'next f0 'ys ())
                 (: _ (pins box 'next at 'ys ())
                    (go p) (p >= f0 ? 0 (: _ (run p (min 4096 (f0 - p))) (go (box 'next))))
                    (go at)))
   ; ..raw the kernel's whole answer, its first n the left, for a mixdown that reads it in place
   (raw ix) (: n #ix f0 (peep ix 0 0) _ (reach f0) (run f0 n))
   fn (ix \ peep (raw ix) (iota #ix) 0.0)
   [end fn gl gr raw])
)) ; module ops
