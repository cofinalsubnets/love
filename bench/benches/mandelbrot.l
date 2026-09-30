; mandelbrot -- iterate z = z^2 + c over a 128x128 grid of c in [-2,1]x[-1.5,1.5], counting escape
; iterations (|z| > 2) up to 128. checksum = sum of the per-pixel counts (= 424578). love writes the
; step with complex twins; the glaze's twin lane (twolow, src/love/boot/glaze.l) lowers it to a
; real/imag float pair on the float-grid kernel, bit-exact. the ports use a real/imag float pair.
(: (mand c z it)
    (it < 128 && re z * re z + im z * im z <= 4.0 ? (mand c (z * z + c) (it + 1)) it)
   (col px py acc) (py < 128
                    ? (col px (py + 1) (acc + mand ((-2.0 + px * 0.0234375) ~ (-1.5 + py * 0.0234375)) (0.0 ~ 0.0) 0))
                      acc)
   (grid px acc) (px < 128 ? (grid (px + 1) (acc + col px 0 0)) acc)
 (bench "mandelbrot" (_ \ grid 0 0)))
