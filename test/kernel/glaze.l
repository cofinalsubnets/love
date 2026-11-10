; test/kernel/glaze.l -- a native made at run time runs on the kernel: the hook's loop is code, and on x64
; a grid nest runs at least 3x its interp twin's speed, the twin a nest whose escape test the native declines
(: G (cite 'glaze)
   row (G 'targets love-arch)
   kgz-f (ev '(: (go i acc) (i = 0 ? acc (go (i - 1) (acc + i))) go))
   (kgz-nest t) (ev (': . ['(mand c z it) ['? ['&& '(it < 40) t] '(mand c (z * z + c) (it + 1)) 'it]
                          '(col px py acc) '(py < 100 ? (col px (py + 1) (acc + mand ((px * 0.015 - 2.0) ~ (py * 0.03 - 1.5)) (0.0 ~ 0.0) 0)) acc)
                          '(grid px acc) '(px < 200 ? (grid (px + 1) (acc + col px 0 0)) acc) 'grid]))
   (kgz-tm f) (: t0 (clock 0) r (f 0 0) [r (clock t0)])
   (? (row == ()) 0
      (: na (kgz-tm (kgz-nest '(re z * re z + im z * im z <= 4.0)))  tw (kgz-tm (kgz-nest '(abs z <= 2.0)))
         (test (nat? kgz-f) (kgz-f 1000 0 = 500500) (<na = <tw)
               (love-arch != 'x64 || 3 * <>na < <>tw)))))
