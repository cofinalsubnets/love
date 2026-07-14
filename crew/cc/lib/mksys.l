; crew/cc/lib/mksys.l -- lay sys.o, the raw seam's hand-written machine tail (rung 4):
; the five functions C cannot say. everything else in the gcc-free link is C compiled
; by aicc (nolibc.c + math/); these are the register-exact leaves under it:
;   __ai_sys(n,a,b,c,d,e,f)  the 7-slot syscall trampoline (nolibc.c calls nothing else)
;   __sigsetjmp / siglongjmp our own jmp_buf INSIDE the glibc-sized 25-long buffer:
;                            [0..5] rbx rbp r12 r13 r14 r15, [6] rsp, [7] rip,
;                            [8] the signal mask (rt_sigprocmask saves/restores it --
;                            ai.c's fault barrier is sigsetjmp(env,1), the mask is load-bearing)
;   __ai_sigret              the SA_RESTORER tail (rt_sigreturn) nolibc's sigaction installs
; (sqrt stays in C -- crew/cc/lib/math/am.c's am_sqrt, OURS and IEEE-exact; a thing
; C CAN say has no place here.) two targets: (mksys dst) lays x64, (mksys-arm64 dst)
; aarch64. runs after crew/holo/{elf,obj}.l in a cat (the aicc prefix
; layers; the assembler itself rides the baked holo book):
;   { cat crew/kore/{text,core,asbook}.l crew/holo/{elf,obj}.l crew/cc/lib/mksys.l;
;     echo '(mksys "out/.../sys.o")'; } | out/host/ai
; register vocabulary is holo's: r0=rax r1=rcx r2=rdx r3=rbx r4=rbp r5=rsi r6=rdi
; r7=r8 r8=r9 r9=r10 r10=r11 r11=r12 r12=r13 r13=r14 r14=r15.
(: (mksys dst)
    (: ir (L
         ; -- __ai_sys: SysV args (rdi rsi rdx rcx r8 r9 [rsp+8]) -> the kernel's
         ;    (rax rdi rsi rdx r10 r8 r9). each mov reads a slot the previous one
         ;    just drained, so the chain needs no scratch.
         (L 'label '__ai_sys)
         (L 'mov 'r0 'r6)                 ; rax <- n
         (L 'mov 'r6 'r5)                 ; rdi <- a
         (L 'mov 'r5 'r2)                 ; rsi <- b
         (L 'mov 'r2 'r1)                 ; rdx <- c
         (L 'mov 'r9 'r7)                 ; r10 <- d
         (L 'mov 'r7 'r8)                 ; r8  <- e
         (L 'ld 'r8 'sp 8)                ; r9  <- f (the one stack arg)
         (L 'sys)
         (L 'ret)                         ; rax rides out (-errno included; C wraps it)

         ; -- __sigsetjmp(buf, save): pin the callee-saved file + the return seam,
         ;    then read the current mask into buf[8] (rt_sigprocmask how=0 set=NULL).
         (L 'label '__sigsetjmp)
         (L 'st 'r6 0  'r3)               ; rbx
         (L 'st 'r6 8  'r4)               ; rbp
         (L 'st 'r6 16 'r11)              ; r12
         (L 'st 'r6 24 'r12)              ; r13
         (L 'st 'r6 32 'r13)              ; r14
         (L 'st 'r6 40 'r14)              ; r15
         (L 'ld 'r0 'sp 0)                ; the return rip sits at [rsp]
         (L 'st 'r6 56 'r0)
         (L 'lea 'r0 'sp 8)               ; the caller's rsp once we return
         (L 'st 'r6 48 'r0)
         (L 'lea 'r2 'r6 64)              ; rdx = &buf[8] (oldset)
         (L 'li 'r5 0)                    ; rsi = NULL (read only)
         (L 'li 'r6 0)                    ; rdi = SIG_BLOCK
         (L 'li 'r9 8)                    ; r10 = sigsetsize
         (L 'li 'r0 14)                   ; rt_sigprocmask
         (L 'sys)
         (L 'li 'r0 0)                    ; the first arrival answers 0
         (L 'ret)

         ; -- siglongjmp(buf, val): restore the mask FIRST (the fault barrier jumps out
         ;    of a signal handler), then the register file, then jump the saved rip.
         ;    val and buf ride r8/r9 -- the two registers rt_sigprocmask neither reads
         ;    nor clobbers (the kernel eats rcx/r11).
         (L 'label 'siglongjmp)
         (L 'mov 'r7 'r5)                 ; r8 <- val
         (L 'mov 'r8 'r6)                 ; r9 <- buf
         (L 'lea 'r5 'r6 64)              ; rsi = &buf[8] (the saved mask)
         (L 'li 'r6 2)                    ; rdi = SIG_SETMASK
         (L 'li 'r2 0)                    ; rdx = NULL
         (L 'li 'r9 8)                    ; r10 = sigsetsize
         (L 'li 'r0 14)                   ; rt_sigprocmask
         (L 'sys)
         (L 'ld 'r3  'r8 0)               ; rbx
         (L 'ld 'r4  'r8 8)               ; rbp
         (L 'ld 'r11 'r8 16)              ; r12
         (L 'ld 'r12 'r8 24)              ; r13
         (L 'ld 'r13 'r8 32)              ; r14
         (L 'ld 'r14 'r8 40)              ; r15
         (L 'mov 'r0 'r7)                 ; rax <- val, 0 lifted to 1 (the setjmp law)
         (L 'cmp 'r0 0)
         (L 'br 'ne 'lj-live)
         (L 'li 'r0 1)
         (L 'label 'lj-live)
         (L 'ld 'sp 'r8 48)               ; the saved rsp
         (L 'ld 'r1 'r8 56)               ; the saved rip
         (L 'jmpr 'r1)

         ; -- __ai_sigret: the restorer a kernel sigaction wants under SA_RESTORER.
         (L 'label '__ai_sigret)
         (L 'li 'r0 15)                   ; rt_sigreturn
         (L 'sys))
       fns (L "__ai_sys" "__sigsetjmp" "siglongjmp" "__ai_sigret")
       (write-bytes dst (objelf 'x64 ir () fns () () ()))))

; the aarch64 lane: same four leaves on the asm-generic table. registers are
; holo's arm64 file, rN = xN one-to-one (plus fp/lr/sp by name). the jmp_buf
; inside the same 25-long buffer: [0..9] x19..x28, [10] fp, [11] sp, [12] lr
; (the return pc -- BL parked it there, so it IS the return seam), [13..20]
; d8..d15 (AAPCS saves the LOW HALVES only -- str dN is exactly that),
; [21] the signal mask. rt_sigprocmask is 135; the kernel preserves every
; register but x0 across svc, so buf/val stage in x9/x10 and ride through.
; __ai_sigret stays laid (rt_sigreturn 139) though aarch64's sigaction never
; points at it -- the kernel supplies its own vdso trampoline (nolibc gates
; SA_RESTORER off); the symbol keeps the two sys.o surfaces identical.
(: (mksys-arm64 dst)
    (: ir (L
         ; -- __ai_sys: args x0..x6 (n,a..f) -> the kernel's x8=nr, x0..x5.
         ;    x8 drains first, then each mov reads the slot ahead of it.
         (L 'label '__ai_sys)
         (L 'mov 'r8 'r0)                 ; x8 <- n
         (L 'mov 'r0 'r1)                 ; x0 <- a
         (L 'mov 'r1 'r2)                 ; x1 <- b
         (L 'mov 'r2 'r3)                 ; x2 <- c
         (L 'mov 'r3 'r4)                 ; x3 <- d
         (L 'mov 'r4 'r5)                 ; x4 <- e
         (L 'mov 'r5 'r6)                 ; x5 <- f
         (L 'sys)
         (L 'ret)                         ; x0 rides out (-errno included; C wraps it)

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam,
         ;    then the current mask into buf[21] (rt_sigprocmask how=0 set=NULL).
         (L 'label '__sigsetjmp)
         (L 'st 'r0 0   'r19)
         (L 'st 'r0 8   'r20)
         (L 'st 'r0 16  'r21)
         (L 'st 'r0 24  'r22)
         (L 'st 'r0 32  'r23)
         (L 'st 'r0 40  'r24)
         (L 'st 'r0 48  'r25)
         (L 'st 'r0 56  'r26)
         (L 'st 'r0 64  'r27)
         (L 'st 'r0 72  'r28)
         (L 'st 'r0 80  'fp)
         (L 'lea 'r9 'sp 0)               ; sp reads through an add
         (L 'st 'r0 88  'r9)
         (L 'st 'r0 96  'lr)
         (L 'stsd 'r0 104 'f8)
         (L 'stsd 'r0 112 'f9)
         (L 'stsd 'r0 120 'f10)
         (L 'stsd 'r0 128 'f11)
         (L 'stsd 'r0 136 'f12)
         (L 'stsd 'r0 144 'f13)
         (L 'stsd 'r0 152 'f14)
         (L 'stsd 'r0 160 'f15)
         (L 'lea 'r2 'r0 168)             ; x2 = &buf[21] (oldset)
         (L 'li 'r1 0)                    ; x1 = NULL (read only)
         (L 'li 'r0 0)                    ; x0 = SIG_BLOCK
         (L 'li 'r3 8)                    ; x3 = sigsetsize
         (L 'li 'r8 135)                  ; rt_sigprocmask
         (L 'sys)
         (L 'li 'r0 0)                    ; the first arrival answers 0
         (L 'ret)

         ; -- siglongjmp(buf, val): the mask FIRST (the fault barrier jumps out
         ;    of a signal handler), then the file, then ret through the saved lr.
         (L 'label 'siglongjmp)
         (L 'mov 'r9 'r0)                 ; x9  <- buf
         (L 'mov 'r10 'r1)                ; x10 <- val
         (L 'lea 'r1 'r9 168)             ; x1 = &buf[21] (the saved mask)
         (L 'li 'r0 2)                    ; x0 = SIG_SETMASK
         (L 'li 'r2 0)                    ; x2 = NULL
         (L 'li 'r3 8)                    ; x3 = sigsetsize
         (L 'li 'r8 135)                  ; rt_sigprocmask
         (L 'sys)
         (L 'ld 'r19 'r9 0)
         (L 'ld 'r20 'r9 8)
         (L 'ld 'r21 'r9 16)
         (L 'ld 'r22 'r9 24)
         (L 'ld 'r23 'r9 32)
         (L 'ld 'r24 'r9 40)
         (L 'ld 'r25 'r9 48)
         (L 'ld 'r26 'r9 56)
         (L 'ld 'r27 'r9 64)
         (L 'ld 'r28 'r9 72)
         (L 'ld 'fp  'r9 80)
         (L 'ldsd 'f8  'r9 104)
         (L 'ldsd 'f9  'r9 112)
         (L 'ldsd 'f10 'r9 120)
         (L 'ldsd 'f11 'r9 128)
         (L 'ldsd 'f12 'r9 136)
         (L 'ldsd 'f13 'r9 144)
         (L 'ldsd 'f14 'r9 152)
         (L 'ldsd 'f15 'r9 160)
         (L 'mov 'r0 'r10)                ; x0 <- val, 0 lifted to 1 (the setjmp law)
         (L 'cmp 'r0 0)
         (L 'br 'ne 'lj-live)
         (L 'li 'r0 1)
         (L 'label 'lj-live)
         (L 'ld 'r11 'r9 88)
         (L 'lea 'sp 'r11 0)              ; sp <- the saved sp
         (L 'ld 'lr 'r9 96)
         (L 'ret)                         ; ret x30 = the saved return pc

         ; -- __ai_sigret: rt_sigreturn, laid for surface parity (see above).
         (L 'label '__ai_sigret)
         (L 'li 'r8 139)                  ; rt_sigreturn
         (L 'sys))
       fns (L "__ai_sys" "__sigsetjmp" "siglongjmp" "__ai_sigret")
       (write-bytes dst (objelf 'arm64 ir () fns () () ()))))
