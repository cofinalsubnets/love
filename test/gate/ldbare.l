; test/gate/ldbare.l -- ldbare32 and obj.l's 32-bit relocs, past what a board's link exercises
;   i386  a call and an absolute linked bare at 1 MB take i386's patcher, as objdump reads
;         them: call f (rel32 6), mov $d,%eax (d at 0x10000c), ret, ret, then d's bytes
;   bcc   a thumb2 Bcc.W into another section leaves R_ARM_THM_JUMP19, linked here to the
;         word GNU ld lays for it: beq.w 0x800e at 0x8004 (f000 8003)
;   cat src/apps/kore/{text,u,asbook}.l src/love/holo/{holo,i386,thumb2,elf,obj,lds,link}.l
;       test/gate/ldbare.l | love   (prints "ldbare: ok")
(borrow 'holo)
(: (bytes l) (cask #l @ c (map (i \ pin c i (l i)) (jot #l), string c))
   (link target runs obj) (string (cats (ldbare32 target runs [["a.o" obj]] () ())))
   x86 (link 'i386 [['at 0x100000 'text 'data]]
          (string (objsecs32 'i386
             [[".text" 1 6 4 [['label '_start] ['call 'f] ['la 'r0 'd] ['ret] ['label 'f] ['ret]]]
              [".data" 1 3 4 [['label 'd] ['raw [1 2 3 4]]]]]
             '("_start") () ())))
   arm (link 'thumb2 [['at 0x8000 'text]]
          (string (objsecs32 'thumb2
             [[".text.a" 1 6 4 [['label '_start] ['cmp 'r0 'r1] ['br 'eq 'g] ['ret]]]
              [".text.b" 1 6 4 [['nop] ['label 'g] ['li 'r0 7] ['ret]]]]
             '("_start") () ())))
   ok (x86 18 = 3 && 0 <= fsub x86 (bytes [232 6 0 0 0 184 12 0 16 0 195 195 1 2 3 4]) 0
       && arm 18 = 40 && 0 <= fsub arm (bytes [176 235 1 15 0 240 3 128 112 71]) 0)
   (puts (ok ? "ldbare: ok\n" "FAIL ldbare: a 32-bit reloc\n")))
