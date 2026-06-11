; `+` extended over symbols, name-compatible with strings, dispatched through the
; explicit type-by-type matrix (l.c g_add_mx). The text tower is
;   STRING (rank 0) < UNINTERNED-SYM (1) < INTERNED-SYM (2),
; a number contributes one byte and lifts to its partner's type, and mixing two
; text values demotes to the LOWER rank. A symbol's bytes are its name; an
; anonymous symbol behaves like "" (the empty string). This file walks the whole
; 6x6 category matrix {NUM ARR LIST STR USYM ISYM} and checks the result TYPE and
; CONTENT of every cell, plus the empty-string / empty-symbol identities.

(: sa-i (\ x (? (symp x) (= x (intern (string x))) 0))        ; interned symbol?
   sa-u (\ x (? (symp x) (nilp (= x (intern (string x)))) 0)) ; named-uninterned symbol?
   sa-U (nom (\ cd))                                                   ; one fixed uninterned sym, name "cd"
   sa-z (intern ""))                                          ; the empty symbol (anonymous singleton)

(assert
 ; --- the empty string / empty symbol are unique singletons & two-sided identities
 (strp "")   (= "" (+ "" ""))                 ; empty string identity
 (= "foo" (+ "" "foo"))   (= "foo" (+ "foo" ""))
 (symp sa-z)   (= sa-z (intern ""))   (= sa-z (+ sa-z sa-z)) ; empty symbol singleton

 ; === row NUM (a = 65 = 'A') ===========================================
 (= 67 (+ 65 2))                               ; NUM+NUM -> arithmetic
 (aall (= @(66 67) (+ 65 @(1 2))))             ; NUM+ARR -> broadcast add
 (= '(65 1 2) (+ 65 '(1 2)))                   ; NUM+LIST -> X (num element)
 (= "Aab" (+ 65 "ab"))   (strp (+ 65 "ab"))    ; NUM+STR -> byte+str (string)
 (= "Acd" (string (+ 65 sa-U)))   (sa-u (+ 65 sa-U)) ; NUM+USYM -> sym, byte lifted
 (= 'Aef (+ 65 'ef))   (sa-i (+ 65 'ef))       ; NUM+ISYM -> interned sym

 ; === row ARR (a = @(1 2)) =============================================
 (aall (= @(3 4) (+ @(1 2) 2)))                ; ARR+NUM -> broadcast
 (aall (= @(4 6) (+ @(1 2) @(3 4))))           ; ARR+ARR
 (= "(@(1 2) 7 8)" (show (+ @(1 2) '(7 8))))   ; ARR+LIST -> array as a single list element
 (nilp (+ @(1 2) "ab"))                        ; ARR+STR  -> nil
 (nilp (+ @(1 2) sa-U))                        ; ARR+USYM -> nil
 (nilp (+ @(1 2) 'ef))                         ; ARR+ISYM -> nil

 ; === row LIST (a = '(1 2)) ============================================
 (= '(1 2 65) (+ '(1 2) 65))                   ; LIST+NUM -> append element
 (= "(1 2 @(3 4))" (show (+ '(1 2) @(3 4))))   ; LIST+ARR -> append (array element)
 (= '(1 2 3 4) (+ '(1 2) '(3 4)))              ; LIST+LIST
 (= '(1 2 "ab") (+ '(1 2) "ab"))               ; LIST+STR -> append (str element)
 (= 'ef (cabp (cbp (+ '(1 2) 'ef))))               ; LIST+ISYM -> append (sym element)

 ; === row STR (a = "ab") ===============================================
 (= "abC" (+ "ab" 67))   (strp (+ "ab" 67))    ; STR+NUM -> byte at back
 (nilp (+ "ab" @(1 2)))                        ; STR+ARR -> nil
 (= '("ab" 1 2) (+ "ab" '(1 2)))               ; STR+LIST -> X (str element)
 (= "abcd" (+ "ab" "cd"))                      ; STR+STR
 (= "abcd" (+ "ab" sa-U))   (strp (+ "ab" sa-U)) ; STR+USYM -> demote to str
 (= "abef" (+ "ab" 'ef))    (strp (+ "ab" 'ef))  ; STR+ISYM -> demote to str

 ; === row USYM (a = (nom (\ cd))) ===============================================
 (= "cdC" (string (+ sa-U 67)))   (sa-u (+ sa-U 67)) ; USYM+NUM -> sym (byte at back)
 (nilp (+ sa-U @(1 2)))                        ; USYM+ARR -> nil
 (= "($cd 1 2)" (show (+ sa-U '(1 2))))        ; USYM+LIST -> cons (sym element)
 (= "cdab" (+ sa-U "ab"))   (strp (+ sa-U "ab"))  ; USYM+STR -> demote to str
 (= "cdcd" (string (+ sa-U sa-U)))   (sa-u (+ sa-U sa-U)) ; USYM+USYM -> usym
 (= "cdef" (string (+ sa-U 'ef)))    (sa-u (+ sa-U 'ef))  ; USYM+ISYM -> demote to usym

 ; === row ISYM (a = 'ef) ===============================================
 (= 'efC (+ 'ef 67))   (sa-i (+ 'ef 67))       ; ISYM+NUM -> interned sym
 (nilp (+ 'ef @(1 2)))                         ; ISYM+ARR -> nil
 (= "(ef 1 2)" (show (+ 'ef '(1 2))))          ; ISYM+LIST -> cons (sym element)
 (= "efab" (+ 'ef "ab"))   (strp (+ 'ef "ab")) ; ISYM+STR -> demote to str
 (= "efcd" (string (+ 'ef sa-U)))   (sa-u (+ 'ef sa-U)) ; ISYM+USYM -> demote to usym
 (= 'efef (+ 'ef 'ef))   (sa-i (+ 'ef 'ef))    ; ISYM+ISYM -> interned sym

 ; --- the lattice & lifting, stated directly ---------------------------
 (sa-i (+ 'a 'b))                              ; isym + isym  = isym
 (sa-u (+ 'a sa-U))                            ; isym + usym  = usym (demote)
 (strp (+ 'a "b"))                             ; isym + str   = str  (demote)
 (sa-i (+ 65 'b))                              ; num  + isym  = isym (lift)
 (sa-u (+ 65 sa-U))                            ; num  + usym  = usym (lift)
 (strp (+ 65 "b"))                             ; num  + str   = str
 ; the empty symbol () = (intern "") is canonical, not anonymous: the two-sided
 ; + identity, partner unchanged (a real anonymous nom still demotes, rows above)
 (= 'ef (+ sa-z 'ef))   (sa-i (+ sa-z 'ef))    ; () + isym -> the isym itself
 (= 'ef (+ 'ef sa-z))   (sa-i (+ 'ef sa-z)))   ; isym + () -> the isym itself
