; test/gate/ldbare.l -- ldbare32 past the arm family: an i386 object, a call and an
; absolute, linked bare at 1 MB. the relocs take i386's patcher, as objdump reads them:
; call f (rel32 6), mov $d,%eax (d at 0x10000c), ret, ret, then d's four bytes.
;   cat src/apps/kore/{text,u,asbook}.l src/love/holo/{holo,i386,thumb2,elf,obj,link}.l
;       test/gate/ldbare.l | love   (prints "ldbare: ok")
(borrow 'holo)
(: obj (string (objsecs32 'i386
          [[".text" 1 6 4 [['label '_start] ['call 'f] ['la 'r0 'd] ['ret] ['label 'f] ['ret]]]
           [".data" 1 3 4 [['label 'd] ['raw [1 2 3 4]]]]]
          '("_start") () ()))
   img (string (cats (ldbare32 'i386 [['at 0x100000 'text 'data]] [["a.o" obj]] () ())))
   (bytes l) (cask #l @ c (map (i \ pin c i (l i)) (jot #l), string c))
   want (bytes [232 6 0 0 0 184 12 0 16 0 195 195 1 2 3 4])
   (puts ((0 <= fsub img want 0 && img 18 = 3) ? "ldbare: ok\n" "FAIL ldbare: i386's relocs\n")))
