; holo's xtensa objects through its own link: _start calls FN in another object (a slot0
; call0), FN jumps inside its own section (resolved in place), and _start reads VAL's
; address from an abs32 word. 5 + 7 + 30, exit 42. XT_OUT names the linux ELF it writes
(borrow 'posix)
(borrow 'holo)
(: a (objsecs 'xtensa
        [[".text" 1 6 4 [['label '_start] ['li 'r0 5] ['li 'r1 7] ['call 'FN] ['mov 'r9 'r2]
                         ['align 4] ['jmp 'L1] ['raw [0]] ['raw [['fix 4 'abs32 'VAL 0]]] ['label 'L1] ['lapool 'r1]
                         ['ld 'r1 'r1 0] ['add 'r4 'r9 'r1] ['li 'r0 119] ['sys]]]]
        '("_start") () () ())
   b (objsecs 'xtensa
        [[".text" 1 6 4 [['align 4] ['label 'FN] ['jmp 'G] ['trap] ['label 'G] ['mov 'r2 'r0] ['add 'r2 'r2 'r1] ['ret]]]
         [".data" 1 3 4 [['align 4] ['label 'VAL] ['raw [30 0 0 0]]]]]
        '("FN") '("VAL") () ())
   (ld-write (getenv "XT_OUT") (ldlink 'xtensa 0 () [["a.o" (string a)] ["b.o" (string b)]] "love" ()),
    puts "xtlink: two objects linked\n", 0))
