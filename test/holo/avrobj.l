; avr objects: one program laid by objsecsn, for a family's e_flags, written to AVR_OBJ. avr.sh holds
; it to llvm-mc's of the same program: the bytes, the relocations (kind, offset, symbol, addend), the flags.
; the backend here lays only raw bytes and fixups; AVR_FAM names the family
(borrow 'holo)
(borrow '(posix bytes))
(: fam (name (getenv "AVR_FAM"))
   far (<(avr-fam fam) @ fs (elem 'jmp fs))
   _ (defbackend 'avr {'lower (ins \ <ins = 'raw ? (ins 1) (scare 'avrobj-form ins)) 'nop '(0 0) 'eflags (avr-fam fam 2)})
   ; one fixup: kind k on label l with addend ad over the instruction word w (its width n)
   (fx n k l ad w) ['raw [['fix n k l (w | (ad & 0xffffffff) << 32)]]]
   (dx n k l ad) ['raw [['fix n k l ad]]]
   text (catall [
     '((label f))
     [(fx 2 'av13 'f 0 0xcfff) (fx 2 'av13 'ext 0 0xcfff) (fx 2 'av13 'ext 4 0xc001)
      (fx 2 'av7 'loc 0 0xf001) (fx 2 'av7 'ext 0 0xf7f9)]
     (far ? [(fx 4 'avcall 'ext 0 0x940e0000) (fx 4 'avcall 'f 0 0x940e0000) (fx 4 'avcall 'ext 6 0x940c0000)] ())
     [(fx 2 'avlo8 'v 5 0xe080) (fx 2 'avhi8 'v 5 0xe090)
      (fx 2 'avlo8 'v -3 0xe080) (fx 2 'avhi8 'v -3 0xe090)
      (fx 2 'avlo8neg 'v 5 0xe080) (fx 2 'avhi8neg 'v 5 0xe090)
      (fx 2 'avlo8pm 'ext 0 0xe0e0) (fx 2 'avhi8pm 'ext 0 0xe0f0)
      (dx 2 'abs16 'ext 0)
      '(label loc) '(raw (8 149))]])
   data [['label 'v] (dx 2 'abs16 'ext 0) (dx 2 'abs16 'v 2) (fx 2 'av16pm 'ext 0 0) (dx 4 'abs32 'ext 0) (dx 1 'abs8 'v 0) ['raw [0]]]
   secs [[".text" 1 6 2 text] [".data" 1 3 1 data]]
   o (objsecsn 'avr secs ["f"] ["v"] () ["loc"] {} [() () ()] ())
   _ (getenv "AVR_OBJ" @ p (write-bytes p o))
   named (map (n \ trap (_ \ avr-rtake n) 0 (a \ b \ b)) [24 25 30 31 32])
   (? (named = ["R_AVR_LO8_LDI_GS" "R_AVR_HI8_LDI_GS" "R_AVR_DIFF8" "R_AVR_DIFF16" "R_AVR_DIFF32"])
      (puts "avrobj: ok\n") (puts "avrobj: a kind not refused by name: \(named)\n", quit 1)))
