; src/inle/teensy41/mkimg.l -- wrap the baked heap image (love.img, from src/inle/mps2's baker) as
; an object, in place of `ld -r -b binary`. main.c reads it between the two brackets ld -b binary
; would have spelled off the file name, so they keep those names. the section is ALLOC-only
; PROGBITS on an 8-byte grain: the image header's uint64 fields are read in place before any copy.
; runs after src/love/holo/{elf,obj}.l in a cat with the thumb2 backend spliced into the sealed
; holo module; src/inle/teensy41/Makefile drives it.
(: (mkimg src dst)
   (: r (uread src)
      _ (two? r ? 0 (scare 'mkimg-no-image src))
      s <>r  n #s                                    ; 0 bytes: no qemu baked it, and main.c,
                                                     ; finding no image, bakes the egg
      ir [['label '_binary_love_img_start]
          ['raw (map (i \ s i) ^n)]
          ['label '_binary_love_img_end]]
      (write-bytes dst
       (objsecs32 'thumb2 [[".love.image" 1 2 8 ir]] ()
        '("_binary_love_img_start" "_binary_love_img_end") ()))))
