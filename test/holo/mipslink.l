; holo's mips objects through a link: _start calls FN in another object (a jal's 26 bits), FN
; jumps inside its own section (resolved in place), _start loads PTR's address by lui and addiu
; (hi16, lo16), PTR's word holds VAL's (a big-endian abs32), and _start branches to H in the
; other object (pc16) to exit 5 + 7 + 30 = 42. MIPS_OUT names the linked ELF; MIPS_OBJ, if set,
; a directory for the two objects, for another linker
(borrow 'posix)
(borrow 'holo)
(: a (objsecs 'mips
        [[".text" 1 6 4 [['label '_start] ['li 'r0 5] ['li 'r1 7] ['call 'FN] ['mov 'r9 'r2]
                         ['la 'r6 'PTR] ['ld 'r6 'r6 0] ['ld 'r1 'r6 0] ['add 'r2 'r9 'r1] ['jmp 'H]]]]
        '("_start") () () ())
   b (objsecs 'mips
        [[".text" 1 6 4 [['align 4] ['label 'FN] ['jmp 'G] ['trap] ['label 'G] ['mov 'r2 'r0] ['add 'r2 'r2 'r1] ['ret]
                         ['label 'H] ['li 'r0 4001] ['sys]]]
         [".data" 1 3 4 [['align 4] ['label 'VAL] ['raw [0 0 0 30]] ['label 'PTR] ['raw [['fix 4 'abs32 'VAL 0]]]]]]
        '("FN" "H") '("VAL" "PTR") () ())
   dir (getenv "MIPS_OBJ")
   (dir = () || dir = "" ? 0 (write-bytes (dir + "/a.o") a, write-bytes (dir + "/b.o") b),
    ld-write (getenv "MIPS_OUT") (ldlink 'mips 0 () [["a.o" (elf-flat a)] ["b.o" (elf-flat b)]] "love" () ()),
    puts "mipslink: two objects linked\n", 0))
