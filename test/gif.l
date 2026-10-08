; src/love/lib/gif.c's gif-frame: a two-pixel image laid on a canvas, its colours read off the
; global palette and off a local one. the loop holds more each round, so the collections
; the canvas asks for move the gif and grow the heap under it (make test_gcstress)
(borrow 'gif)
(: gift-lzw "\x02\x02\x4c\x0a\x00\x3b"             ; min code 2: clear 1 1 end, one block
   gift-g ("GIF89a\x02\x00\x01\x00\x80\x00\x00" + "\x00\x00\x00\x12\x34\x56"
           + "\x2c\x00\x00\x00\x00\x02\x00\x01\x00\x00")
   gift-l ("GIF89a\x02\x00\x01\x00\x00\x00\x00"
           + "\x2c\x00\x00\x00\x00\x02\x00\x01\x00\x80" + "\x00\x00\x00\xab\xcd\xef")
   gift-px "\x12\x34\x56\xff\x12\x34\x56\xff"
   (gift-go k keep bad)
    (k = 0 ? bad
       (gif-frame (gift-g + gift-lzw) 19 (string (cask 8)) -1 @ r
        (gift-go (k - 1) (cask 16384 . keep) (bad + (r != gift-px)))))
   (test
      (gif-frame (gift-g + gift-lzw) 19 (string (cask 8)) -1 = gift-px)
      (gif-frame (gift-l + gift-lzw) 13 (string (cask 8)) -1 = "\xab\xcd\xef\xff\xab\xcd\xef\xff")
      (gif-frame (gift-g + gift-lzw) 19 (string (cask 8)) 1 = string (cask 8))   ; 1 see-through
      (gif-frame (gift-g + gift-lzw) 19 "" -1 = 3)
      (gift-go 200 () 0 = 0)))
