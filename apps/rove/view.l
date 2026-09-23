; view -- what a first-person level in half blocks rides: the screen as a camera on the
; state, the rays its columns cast, the pens said a change at a time, and the small
; arithmetic the scenes share. wade (apps/rove/wade.l) and shaft (apps/rove/shaft.l) borrow it.
(module (view esc pi clamp flo wrap min2 max2 over throw sgr view! view-hz view-size view-rays)
(:
 esc (string 27)
 pi 3.141592653589793
 (clamp v lo hi) (v < lo ? lo (hi < v ? hi v))
 (flo v) (int (v + 1000.0) - 1000)
 (wrap a) (a < -pi ? (wrap (a + 2.0 * pi)) (pi < a ? (wrap (a - 2.0 * pi)) a))
 (min2 a b) (a < b ? a b)
 (max2 a b) (a < b ? b a)
 (over c m v) (c + m * (v - c))                          ; v where the mask holds, c elsewhere
 ; the hash: two rounds of multiply, shift and mask kept under 32 bits, so a tray's
 ; machine words and a number throw alike
 m32 4294967295
 (mash a) (: h (((a & m32) * 1103515245) & m32) h2 (((h ^ (h >> 15)) * 1664525) & m32) (h2 ^ (h2 >> 13)))
 (throw x y s k) ((mash (y * 374761393 + x * 668265263 + s * 2654435761 + 1)) % k)
 ; a pen on a ground as an sgr, kept once said
 sgrs {}
 (sgr f b) (: k (f * 256 + b) s (sgrs k)
              (string? s ? s (: s2 (esc + "[38;5;" + show f + ";48;5;" + show b + "m") (pin sgrs k s2, s2))))
 ; the screen rides the state: 'w and 'h its pixels, 'cx the middle column, 'foc the
 ; focal length, half the width for a view ninety degrees wide, 'hz the horizon's row
 (view! st w h hz) (pins st 'w w 'h h 'cx (w / 2.0) 'foc (w / 2.0) 'hz hz)
 ; the horizon at a row, kept out of the screen's top and bottom nth
 (view-hz st hz n) (: h (st 'h) (pin st 'hz (clamp hz (h // n) ((n - 1) * h // n))))
 ; resized to w cells across and r rows, two pixels a row, the horizon kept where it
 ; stood in proportion
 (view-size st w r n) (: h (2 * r) hz (st 'hz * h // st 'h) (view-hz (view! st w h hz) hz n))
 ; each column's ray through its middle, facing 'th: [x z] trays of its direction
 (view-rays st) (: th (st 'th) sn (sin th) cs (cos th) u ((iota (st 'w) + 0.5 - st 'cx) / st 'foc)
                   [(sn + u * cs) (cs - u * sn)]))
) ; module view
