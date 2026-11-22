; test/boards/rp2350/mkboot.l -- boot.o for the Pico 2 (RP2350, Arm): the vector table at flash
; base with the image definition behind it. the rom wants a block in the first 4 KB naming an
; Arm secure executable; with no vector table item it takes the table at the image's start. the
; block: start marker, image type (exe, secure, arm, rp2350), the last item (one word of items
; before it), a link to itself, end marker
(: (mkboot dst)
   (armboot dst 1 (le32 0xffffded3 + le32 0x10210142 + le32 0x000001ff + le32 0 + le32 0xab123579)
    () ()))
