; src/inle/rp2040/mkboot2.l -- lay boot2.o for the Pico: the 256-byte second stage the mask ROM
; copies into SRAM to open the QSPI XIP window. the ROM runs it only if the last 4 bytes are a valid
; CRC over the preceding 252, so the stamp is the point of this file. the payload (boot2.bin, the
; vendor W25Q080 sequence) is zero-padded to 252, stamped, and handed to holo as one section.
; CRC-32/MPEG-2, not zlib's: poly 0x04c11db7, init 0xffffffff, no reflection, xorout 0.
; boot2.bin checksums to 0x7a4eb274.
; runs after src/love/holo/{elf,obj}.l in a cat with the thumb1 backend spliced into the sealed
; holo module (src/inle/rp2040/Makefile).
(: m32 4294967295
   (crc-step c) (c << 1 & m32 @ c2 (0 < c & 2147483648 ? (c2 ^ 79764919) c2))
   (crc-byte c b) (: (go c i) (i < 1 ? c (go (crc-step c) (i - 1)))
                     (go (c ^ (b & 255) << 24) 8))
   ; the payload's bytes, then the pad's -- a zero byte still turns the register
   (crc-mpeg2 s n) (: (go c i) (n <= i ? c (go (crc-byte c (#s <= i ? 0 (s i))) (i + 1)))
                      (go m32 0))
   (mkboot2 src dst)
    (: r (uread src)
       _ (two? r ? 0 (scare 'mkboot2-no-payload src))
       s <>r
       _ (#s <= 252 ? 0 (scare 'mkboot2-too-big #s))
       crc (crc-mpeg2 s 252)
       ; 252 payload+pad bytes, then the CRC little-endian: exactly 256
       bs ((: (go i acc) (252 <= i ? (rev acc) (go (i + 1) ((#s <= i ? 0 (s i)) . acc)))
              (go 0 ()))
           + le32 crc)
       ir [['label 'boot2] ['raw bs]]
       ; PROGBITS, ALLOC (read-only -- it is flash), on its own 256-byte grain
       (write-bytes dst (objsecs32 'thumb1 [[".boot2" 1 2 256 ir]] () '("boot2") ()))))
