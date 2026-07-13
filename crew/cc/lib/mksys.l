; crew/cc/lib/mksys.l -- lay sys.o, the raw seam's hand-written machine tail (rung 4):
; the five functions C cannot say. everything else in the gcc-free link is C compiled
; by aicc (nolibc.c + math/); these are the register-exact leaves under it:
;   __ai_sys(n,a,b,c,d,e,f)  the 7-slot syscall trampoline (nolibc.c calls nothing else)
;   __sigsetjmp / siglongjmp our own jmp_buf INSIDE the glibc-sized 25-long buffer:
;                            [0..5] rbx rbp r12 r13 r14 r15, [6] rsp, [7] rip,
;                            [8] the signal mask (rt_sigprocmask saves/restores it --
;                            ai.c's fault barrier is sigsetjmp(env,1), the mask is load-bearing)
;   __ai_sigret              the SA_RESTORER tail (rt_sigreturn) nolibc's sigaction installs
; (sqrt stays in C -- crew/cc/lib/math/sqrt.c, the corpus-proven fdlibm body; a thing
; C CAN say has no place here.) x64 only, like the linker. runs after crew/holo/{elf,obj}.l in a cat (the aicc prefix
; layers; the assembler itself rides the baked holo book):
;   { cat crew/utils/{text,core,asbook}.l crew/holo/{elf,obj}.l crew/cc/lib/mksys.l;
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
