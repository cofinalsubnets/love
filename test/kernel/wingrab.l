; test/kernel/wingrab.l -- a window that grabs the pointer, under test/gate/grab.mjs: the grab
; and the page's motions, as moves from the paper's middle, until a release; a warp and the
; real pointer's steps from there, until another; then it lets go
(borrow 'window)
(: win (window-open 0 0 "wingrab")
   wh (window-size win)
   (say s) (puts ("wingrab: " + s + "\n"), flush out)
   (go k) (window-events win @ l
             ((each l (r \ say (show r))),
              (any (r \ <r = 'release) l || 600 < k ? 0 (rest 20, go (k + 1)))))
   _ (say ("grabbed " + show (window-hold win 1) + " on " + show <wh + "x" + show (wh 1)))
   _ (go 0)
   _ (say ("warped " + show (window-warp win 10 10)))
   _ (go 0)
   _ (say ("let go " + show (window-hold win 0)))
   (rest 500, say "done", reset ()))
