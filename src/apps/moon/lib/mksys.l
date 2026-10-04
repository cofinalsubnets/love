; src/apps/moon/lib/mksys.l -- lay sys.o, the raw seam's hand-written machine tail: the
; functions C cannot say. everything else in the gcc-free link is C compiled by mooncc; these are
; the register-exact leaves under it:
;   __love_sys(n,a,b,c,d,e,f)  the 7-slot syscall trampoline (moonlibc calls nothing else)
;   __sigsetjmp / siglongjmp our own jmp_buf inside the glibc-sized 25-long buffer:
;                            [0..5] rbx rbp r12 r13 r14 r15, [6] rsp, [7] rip, [8] the signal
;                            mask (love.c's fault barrier is sigsetjmp(env,1): the mask is load-bearing)
;   __love_sigret              the sa_restorer tail (rt_sigreturn) moonlibc's sigaction installs
; (mksys-x64 dst), (mksys-a64 dst), (mksys-rv64 dst) all seed mksys-as, which picks the arch's IR
; table. the x64 object serves linux and freebsd: cf cleared before the insn and a carry answer
; parked below linux's band as -(errno+4096), so impl.h's __love_call reads one law; the sigprocmask
; leaves branch on __love_osv between rt_sigprocmask 14 and sigprocmask 340.
; the Makefile cats this after kore's text/u/asbook and holo's elf/obj (out/.mksys-cat.l).
; holo registers: r0=rax r1=rcx r2=rdx r3=rbx r4=rbp r5=rsi r6=rdi r7=r8 r8=r9 r9=r10 r10=r11
; r11=r12 r12=r13 r13=r14 r14=r15.
(module 'moon
(borrow 'holo) ; objelf, the relocatable writer
(: (mksys-x64 dst) (mksys-as 'x64 dst)
   (mksys-a64 dst) (mksys-as 'a64 dst)
   (mksys-rv64 dst) (mksys-as 'rv64 dst)
   (mksys-freebsd dst) (mksys-as 'x64 dst)   ; one object serves both kernels
   (mksys-as arch dst) (write-bytes dst (mksys-bytes arch))
   ; the netbsd/aarch64 dispatch table. That kernel takes the syscall number
   ; from the svc immediate -- the number is in the instruction -- and offers no
   ; indirect door: sys_syscall (svc #0, number in x0) and sys___syscall (svc
   ; #198) both sigsys, and x8 + svc #0 sigsyses too (all three probed on the
   ; box). a runtime number is therefore unsayable in one instruction, so we lay
   ; one `svc #n; ret' per number and BRANCH INTO IT. 512 covers the roster
   ; (the highest we speak is __wait450 at 449); 4 kB of sys.o, a64 only.
   ; the bound is spelled at the two sites, not bound once: a forward VALUE in
   ; this group does not resolve the way a forward lambda does (c0's letrec).
   (nb-tab i acc) (i < 0 ? acc (nb-tab (i - 1) (['svcn i] . ['ret] . acc)))
   ; the bytes alone -- moon.l's runtime pull lays sys in-memory through this
   (mksys-bytes arch)
    (: ir (? (arch = 'x64)
         '(
         ; -- __love_sys: SysV args (rdi rsi rdx rcx r8 r9 [rsp+8]) -> the kernel's
         ;    (rax rdi rsi rdx r10 r8 r9). each mov reads a slot the previous one
         ;    just drained, so the chain needs no scratch. the tail is OS-BLIND:
         ;    cf goes in clear (linux hands it back untouched through r11), and a
         ;    carry answer -- freebsd's error, +errno in rax ('below IS jc) --
         ;    parks below linux's band as -(errno+4096). impl.h's __love_call
         ;    unparks; the tail never learns which kernel answered.
         (label __love_sys)
         (mov r0 r6)                 ; rax <- n
         (mov r6 r5)                 ; rdi <- a
         (mov r5 r2)                 ; rsi <- b
         (mov r2 r1)                 ; rdx <- c
         (mov r9 r7)                 ; r10 <- d
         (mov r7 r8)                 ; r8  <- e
         (ld r8 sp 8)                ; r9  <- f (the one stack arg)
         (cmp r0 0)                  ; clears cf; flags ride the insn both ways
         (sys)
         (br below sys-err)
         (ret)                       ; rax rides out (-errno included; C wraps it)
         (label sys-err)
         (neg r0)
         (lea r0 r0 -4096)           ; -(errno+4096): parked for __love_call
         (ret)

         ; -- __sigsetjmp(buf, save): pin the callee-saved file + the return seam,
         ;    then read the current mask into buf[8] by the kernel under us
         ;    (__love_osv, os.c's probe): rt_sigprocmask(0, NULL, &buf[8], 8), or
         ;    freebsd's sigprocmask(1, NULL, &buf[8]) -- a 16-byte set, so it
         ;    takes buf[8..9] (the glibc-sized buffer has room).
         (label __sigsetjmp)
         (st r6 0  r3)               ; rbx
         (st r6 8  r4)               ; rbp
         (st r6 16 r11)              ; r12
         (st r6 24 r12)              ; r13
         (st r6 32 r13)              ; r14
         (st r6 40 r14)              ; r15
         (ld r0 sp 0)                ; the return rip sits at [rsp]
         (st r6 56 r0)
         (lea r0 sp 8)               ; the caller's rsp once we return
         (st r6 48 r0)
         (lea r2 r6 64)              ; rdx = &buf[8] (oldset)
         (li r5 0)                   ; rsi = NULL (read only)
         (la r1 __love_osv)
         (ld r1 r1 0)
         (cmp r1 2)
         (br eq sj-fb)
         (cmp r1 3)
         (br eq sj-nb)
         (li r6 0)                   ; rdi = SIG_BLOCK
         (li r9 8)                   ; r10 = sigsetsize
         (li r0 14)                  ; rt_sigprocmask
         (sys)
         (li r0 0)                   ; the first arrival answers 0
         (ret)
         (label sj-fb)
         (li r6 1)                   ; rdi = SIG_BLOCK (both BSDs: 1)
         (li r0 340)                 ; sigprocmask
         (sys)
         (li r0 0)
         (ret)
         (label sj-nb)
         (li r6 1)
         (li r0 293)                 ; __sigprocmask14: the same 16-byte shape
         (sys)
         (li r0 0)
         (ret)

         ; -- siglongjmp(buf, val): restore the mask first (the fault barrier jumps
         ;    out of a signal handler), then the register file, then jump the saved
         ;    rip. val and buf ride rbp/rbx: freebsd's syscall exit zeroes the
         ;    scratch registers (a leak mitigation linux does not have), so only
         ;    the callee-saved file survives the kernel -- and it is about to be
         ;    overwritten anyway. rbx restores last, off itself.
         (label siglongjmp)
         (mov r4 r5)                 ; rbp <- val
         (mov r3 r6)                 ; rbx <- buf
         (lea r5 r6 64)              ; rsi = &buf[8] (the saved mask)
         (li r2 0)                   ; rdx = NULL
         (la r1 __love_osv)
         (ld r1 r1 0)
         (cmp r1 2)
         (br eq lj-fb)
         (cmp r1 3)
         (br eq lj-nb)
         (li r6 2)                   ; rdi = SIG_SETMASK
         (li r9 8)                   ; r10 = sigsetsize
         (li r0 14)                  ; rt_sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-fb)
         (li r6 3)                   ; rdi = SIG_SETMASK (both BSDs: 3)
         (li r0 340)                 ; sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-nb)
         (li r6 3)
         (li r0 293)                 ; __sigprocmask14
         (sys)
         (label lj-file)
         (mov r0 r4)                 ; rax <- val, before rbp is restored
         (ld r4  r3 8)               ; rbp
         (ld r11 r3 16)              ; r12
         (ld r12 r3 24)              ; r13
         (ld r13 r3 32)              ; r14
         (ld r14 r3 40)              ; r15
         (ld sp r3 48)               ; the saved rsp
         (ld r1 r3 56)               ; the saved rip
         (ld r3 r3 0)                ; rbx, last, off itself
         (cmp r0 0)                  ; 0 lifted to 1 (the setjmp law)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (jmpr r1)

         ; -- __love_sigret: the restorer a kernel sigaction wants under sa_restorer.
         ;    linux's number: only linux's sigaction installs it -- freebsd has no
         ;    sa_restorer, a handler there returns on the kernel's own trampoline.
         (label __love_sigret)
         (li r0 15)                  ; rt_sigreturn
         (sys)

         ; -- __love_clone(flags, sp, ptid, ctid, tls): linux's clone takes the same order
         ;    (rdi rsi rdx r10 r8). the parent returns the tid or -errno; the child
         ;    wakes on sp, where its caller laid [fn arg], and calls fn(arg), which
         ;    never returns -- the exit after it (this thread alone) is the backstop.
         (label __love_clone)
         (mov r9 r1)                 ; r10 <- ctid
         (li r0 56)                  ; clone
         (sys)
         (cmp r0 0)
         (br ne clone-out)
         (ld r6 sp 8)                ; rdi <- arg
         (ld r1 sp 0)                ; fn
         (callr r1)
         (li r6 0)
         (li r0 60)                  ; exit
         (sys)
         (label clone-out)
         (ret)

         ; -- __love_sys7(n,a..g): the wide door for netbsd's classic pads -- the
         ;    kernel reads a seventh argument at [rsp+8], so g overwrites the
         ;    incoming f slot (drained into r9 first; a callee owns its stack args).
         (label __love_sys7)
         (mov r0 r6)                 ; rax <- n
         (mov r6 r5)                 ; rdi <- a
         (mov r5 r2)                 ; rsi <- b
         (mov r2 r1)                 ; rdx <- c
         (mov r9 r7)                 ; r10 <- d
         (mov r7 r8)                 ; r8  <- e
         (ld r8 sp 8)                ; r9  <- f
         (ld r1 sp 16)               ; rcx <- g (scratch; the kernel clobbers rcx anyway)
         (st sp 8 r1)                ; [rsp+8] <- g, where the kernel reads arg 7
         (cmp r0 0)
         (sys)
         (br below sys7-err)
         (ret)
         (label sys7-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)

         ; -- __love_nb_sigtramp: netbsd's return path -- the kernel calls the
         ;    handler directly and leaves the ucontext in r15; the registered
         ;    tramp (version 2) returns through setcontext, and a fall-through
         ;    exits loudly rather than wandering.
         (label __love_nb_sigtramp)
         (mov r6 r14)                ; rdi <- r15 (the ucontext)
         (li r0 308)                 ; setcontext
         (sys)
         (li r6 -1)
         (li r0 1)                   ; exit
         (sys))

         (arch = 'a64)
         ; one expression: the written leaves ++ the generated netbsd table.
         ; the a64 lane: same four leaves on the asm-generic table. registers are
         ; holo's a64 file, rN = xN one-to-one (plus fp/lr/sp by name). the jmp_buf
         ; inside the same 25-long buffer: [0..9] x19..x28, [10] fp, [11] sp, [12] lr
         ; (the return pc -- BL parked it there, so it IS the return seam), [13..20]
         ; d8..d15 (AAPCS saves the LOW HALVES only -- str dN is exactly that),
         ; [21] the signal mask. rt_sigprocmask is 135; the kernel preserves every
         ; register but x0 across svc, so buf/val stage in x9/x10 and ride through.
         ; __love_sigret stays laid (rt_sigreturn 139) though a64's sigaction never
         ; points at it -- the kernel supplies its own vdso trampoline (moonlibc gates
         ; sa_restorer off); the symbol keeps the two sys.o surfaces identical.
         ('(
         ; -- __love_sys: args x0..x6 (n,a..f) -> the kernel's x8=nr, x0..x5.
         ;    x8 drains first, then each mov reads the slot ahead of it. the tail
         ;    is OS-BLIND, as x64's is: the BSDs answer an error by setting the
         ;    carry with a positive errno in x0, and linux preserves nzcv across
         ;    svc (it rides SPSR through the eret), so a carry going in clear can
         ;    only have been raised by a BSD. clearing it takes a borrow --
         ;    a64's cmp is subs, and subtracting 0 leaves C set.
         (label __love_sys)
         (la r9 __love_osv)            ; netbsd wants the number in the instruction
         (ld r9 r9 0)
         (cmp r9 3)
         (br eq sys-nb)
         (mov r8 r0)                 ; x8 <- n
         (mov r0 r1)                 ; x0 <- a
         (mov r1 r2)                 ; x1 <- b
         (mov r2 r3)                 ; x2 <- c
         (mov r3 r4)                 ; x3 <- d
         (mov r4 r5)                 ; x4 <- e
         (mov r5 r6)                 ; x5 <- f
         (li r9 0)                   ; 0 - 1 borrows, so C goes clear
         (cmp r9 1)
         (sys)
         (br ae sys-err)             ; `ae' IS carry-set on this file: a BSD error
         (ret)                       ; x0 rides out (-errno included; C wraps it)
         (label sys-err)
         (neg r0)
         (lea r0 r0 -4096)           ; -(errno+4096): parked for __love_call
         (ret)

         ; -- the netbsd lane: the same shuffle, then a branch into the stub for
         ;    this number (each is `svc #n; ret'). callr parks the return in lr,
         ;    so the stub's ret comes back here and the carry answer is read the
         ;    same way the register lanes read it. Out of range refuses enosys
         ;    rather than jumping past the table.
         (label sys-nb)
         (mov r10 r0)                ; x10 <- n, before the shuffle drains x0
         (cmp r10 512)
         (br ae sysnb-nosys)
         (mov r0 r1)
         (mov r1 r2)
         (mov r2 r3)
         (mov r3 r4)
         (mov r4 r5)
         (mov r5 r6)
         (la r9 __love_nbsvc)
         (shl r10 3)                 ; 8 bytes a stub
         (add r9 r9 r10)
         (push lr)
         (li r11 0)
         (cmp r11 1)                 ; clear C the same way
         (callr r9)
         (pop lr)
         (br ae sysnb-err)
         (ret)
         (label sysnb-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)
         (label sysnb-nosys)
         (li r0 -38)                 ; -enosys, canonically
         (ret)

         ; -- __love_sys7(n,a..g): the wide door netbsd's classic pads want. On
         ;    a64 the seventh argument is just another register -- the kernel
         ;    reads x0..x7 -- so unlike x64 nothing rides the stack.
         (label __love_sys7)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (cmp r9 3)
         (br eq sys7-nb)
         (mov r8 r0)                 ; x8 <- n
         (mov r0 r1)
         (mov r1 r2)
         (mov r2 r3)
         (mov r3 r4)
         (mov r4 r5)
         (mov r5 r6)
         (mov r6 r7)                 ; x6 <- g, the seventh
         (li r9 0)
         (cmp r9 1)
         (sys)
         (br ae sys7-err)
         (ret)
         (label sys7-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)
         ; the wide door on netbsd -- the kernel this one exists for. Seven
         ; arguments and no number to carry, so x0..x6 take a..g outright.
         (label sys7-nb)
         (mov r10 r0)
         (cmp r10 512)
         (br ae sys7nb-nosys)
         (mov r0 r1)
         (mov r1 r2)
         (mov r2 r3)
         (mov r3 r4)
         (mov r4 r5)
         (mov r5 r6)
         (mov r6 r7)
         (la r9 __love_nbsvc)
         (shl r10 3)
         (add r9 r9 r10)
         (push lr)
         (li r11 0)
         (cmp r11 1)
         (callr r9)
         (pop lr)
         (br ae sys7-err)
         (ret)
         (label sys7nb-nosys)
         (li r0 -38)
         (ret)

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam,
         ;    then the current mask into buf[21] (rt_sigprocmask how=0 set=NULL).
         (label __sigsetjmp)
         (st r0 0   r19)
         (st r0 8   r20)
         (st r0 16  r21)
         (st r0 24  r22)
         (st r0 32  r23)
         (st r0 40  r24)
         (st r0 48  r25)
         (st r0 56  r26)
         (st r0 64  r27)
         (st r0 72  r28)
         (st r0 80  fp)
         (lea r9 sp 0)               ; sp reads through an add
         (st r0 88  r9)
         (st r0 96  lr)
         (stsd r0 104 f8)
         (stsd r0 112 f9)
         (stsd r0 120 f10)
         (stsd r0 128 f11)
         (stsd r0 136 f12)
         (stsd r0 144 f13)
         (stsd r0 152 f14)
         (stsd r0 160 f15)
         (lea r2 r0 168)             ; x2 = &buf[21] (oldset)
         (li r1 0)                   ; x1 = NULL (read only)
         (li r3 8)                   ; x3 = sigsetsize (linux's fourth)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (cmp r9 2)
         (br eq sj-fb)
         (cmp r9 3)
         (br eq sj-nb)
         (li r0 0)                   ; x0 = SIG_BLOCK (linux 0)
         (li r8 135)                 ; rt_sigprocmask
         (sys)
         (li r0 0)                   ; the first arrival answers 0
         (ret)
         (label sj-fb)
         (li r0 1)                   ; SIG_BLOCK (both BSDs: 1), 16-byte set
         (li r8 340)                 ; sigprocmask
         (sys)
         (li r0 0)
         (ret)
         (label sj-nb)
         (li r0 1)
         (svcn 293)                  ; __sigprocmask14, the number in the instruction
         (li r0 0)
         (ret)

         ; -- siglongjmp(buf, val): the mask first (the fault barrier jumps out
         ;    of a signal handler), then the file, then ret through the saved lr.
         ; buf and val ride x19/x20, not the scratch file: freebsd's syscall exit
         ;    zeroes the caller-saved registers (a leak mitigation linux has not),
         ;    so only the callee-saved half survives the kernel -- and that half is
         ;    about to be overwritten from the buffer anyway. x19 restores last,
         ;    off itself, x20 the line before it.
         (label siglongjmp)
         (mov r19 r0)                ; x19 <- buf
         (mov r20 r1)                ; x20 <- val
         (lea r1 r19 168)            ; x1 = &buf[21] (the saved mask)
         (li r2 0)                   ; x2 = NULL (oset)
         (li r3 8)                   ; x3 = sigsetsize (linux's fourth)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (cmp r9 2)
         (br eq lj-fb)
         (cmp r9 3)
         (br eq lj-nb)
         (li r0 2)                   ; x0 = SIG_SETMASK (linux 2)
         (li r8 135)                 ; rt_sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-fb)
         (li r0 3)                   ; SIG_SETMASK (both BSDs: 3)
         (li r8 340)                 ; sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-nb)
         (li r0 3)
         (svcn 293)                  ; __sigprocmask14, the number in the instruction
         (label lj-file)
         (ld r21 r19 16)
         (ld r22 r19 24)
         (ld r23 r19 32)
         (ld r24 r19 40)
         (ld r25 r19 48)
         (ld r26 r19 56)
         (ld r27 r19 64)
         (ld r28 r19 72)
         (ld fp  r19 80)
         (ldsd f8  r19 104)
         (ldsd f9  r19 112)
         (ldsd f10 r19 120)
         (ldsd f11 r19 128)
         (ldsd f12 r19 136)
         (ldsd f13 r19 144)
         (ldsd f14 r19 152)
         (ldsd f15 r19 160)
         (mov r0 r20)                ; x0 <- val, 0 lifted to 1 (the setjmp law)
         (cmp r0 0)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (ld r11 r19 88)
         (lea sp r11 0)              ; sp <- the saved sp
         (ld lr r19 96)
         (ld r20 r19 8)              ; x20 back, then x19 off itself
         (ld r19 r19 0)
         (ret)                       ; ret x30 = the saved return pc

         ; -- __love_sigret: rt_sigreturn, laid for surface parity (see above).
         (label __love_sigret)
         (li r8 139)                 ; rt_sigreturn
         (sys)

         ; -- __love_clone(flags, sp, ptid, ctid, tls): arm64's clone wants tls before
         ;    ctid, so x3/x4 swap; then as x64's: the child calls sp[0](sp[1]).
         (label __love_clone)
         (mov r9 r3)                 ; x9 <- ctid
         (mov r3 r4)                 ; x3 <- tls
         (mov r4 r9)                 ; x4 <- ctid
         (li r8 220)                 ; clone
         (sys)
         (cmp r0 0)
         (br ne clone-out)
         (ld r0 sp 8)                ; x0 <- arg
         (ld r9 sp 0)                ; fn
         (callr r9)
         (li r0 0)
         (li r8 93)                  ; exit
         (sys)
         (label clone-out)
         (ret)
         ; -- __love_tp: the thread pointer clone set (zero on the first thread)
         (label __love_tp)
         (raw (64 208 59 213))       ; mrs x0, tpidr_el0
         (ret)

         ; -- the netbsd leaves. __love_nb_sigtramp is read off the box's own libc
         ;    (nm + objdump: `mov x0, x28; svc #0x134'): the kernel calls the
         ;    handler directly and leaves the ucontext in x28 -- a64's r15 --
         ;    and setcontext is the way back. a fall-through exits loudly.
         (label __love_nb_sigtramp)
         (mov r0 r28)
         (svcn 308)                  ; setcontext
         (li r0 1)
         (svcn 1)                    ; exit, never reached

         ; -- the OS probe's two doors, asked before __love_osv is known and so in
         ;    a form two kernels can answer at once: x8 and the immediate carry
         ;    the same number, linux ignores the immediate and runs x8, netbsd
         ;    reads the immediate. `20' is getpid on netbsd (positive) and
         ;    epoll_create1 on linux/arm64 (-EINVAL, negative) -- the
         ;    discriminator os.c wants -- and 202 is __sysctl, which parts netbsd
         ;    from any other BSD arriving on this door later.
         ; freebsd may never hear either: it signals sigill/ill_illopn for any
         ;    svc immediate but zero. It is out before this runs -- crt0 knows it
         ;    by the entry protocol and answers 2 without asking anyone.
         (label __love_nbp20)
         (li r8 20)
         (svcn 20)
         (ret)
         (label __love_nbp202)
         (li r8 202)
         (svcn 202)
         (ret)

         (label __love_nbsvc))
          + nb-tab 511 ())       ; 512 stubs: 0 .. 511

         ; the rv64 lane: the same four leaves on the same asm-generic table
         ; (rt_sigprocmask 135, rt_sigreturn 139; ecall preserves every register
         ; but a0, so buf/val stage in t0/t1 and ride through). registers are
         ; holo's riscv file: r0..r7 = a0..a7, r8/r9 = t0/t1, fp = s0,
         ; r15/r13/r14 = s1/s2/s3, r19..r26 = s4..s11, lr = ra. the jmp_buf
         ; inside the 25-long buffer: [0] ra (the return pc), [1] sp,
         ; [2..13] s0..s11, [14] the signal mask. no fp slots: the backend's
         ; fp file is all caller-saved (fa/ft; the fs bank is unmapped), so no
         ; mooncc-compiled frame can hold a live double in one across a call.
         '(
         ; -- __love_sys: args a0..a6 (n,a..f) -> the kernel's a7=nr, a0..a5.
         ;    a7 drains n first, then each mov reads the slot ahead of it.
         (label __love_sys)
         (mov r7 r0)                 ; a7 <- n
         (mov r0 r1)                 ; a0 <- a
         (mov r1 r2)                 ; a1 <- b
         (mov r2 r3)                 ; a2 <- c
         (mov r3 r4)                 ; a3 <- d
         (mov r4 r5)                 ; a4 <- e
         (mov r5 r6)                 ; a5 <- f
         (sys)
         (ret)                       ; a0 rides out (-errno included; C wraps it)

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam,
         ;    then the current mask into buf[14] (rt_sigprocmask how=0 set=NULL).
         (label __sigsetjmp)
         (st r0 0   lr)
         (st r0 8   sp)
         (st r0 16  fp)
         (st r0 24  r15)
         (st r0 32  r13)
         (st r0 40  r14)
         (st r0 48  r19)
         (st r0 56  r20)
         (st r0 64  r21)
         (st r0 72  r22)
         (st r0 80  r23)
         (st r0 88  r24)
         (st r0 96  r25)
         (st r0 104 r26)
         (lea r2 r0 112)             ; a2 = &buf[14] (oldset)
         (li r1 0)                   ; a1 = NULL (read only)
         (li r0 0)                   ; a0 = SIG_BLOCK
         (li r3 8)                   ; a3 = sigsetsize
         (li r7 135)                 ; rt_sigprocmask
         (sys)
         (li r0 0)                   ; the first arrival answers 0
         (ret)

         ; -- siglongjmp(buf, val): the mask first (the fault barrier jumps out
         ;    of a signal handler), then the file, then ret through the saved ra.
         (label siglongjmp)
         (mov r8 r0)                 ; t0 <- buf
         (mov r9 r1)                 ; t1 <- val
         (lea r1 r8 112)             ; a1 = &buf[14] (the saved mask)
         (li r0 2)                   ; a0 = SIG_SETMASK
         (li r2 0)                   ; a2 = NULL
         (li r3 8)                   ; a3 = sigsetsize
         (li r7 135)                 ; rt_sigprocmask
         (sys)
         (ld fp  r8 16)
         (ld r15 r8 24)
         (ld r13 r8 32)
         (ld r14 r8 40)
         (ld r19 r8 48)
         (ld r20 r8 56)
         (ld r21 r8 64)
         (ld r22 r8 72)
         (ld r23 r8 80)
         (ld r24 r8 88)
         (ld r25 r8 96)
         (ld r26 r8 104)
         (mov r0 r9)                 ; a0 <- val, 0 lifted to 1 (the setjmp law)
         (cmp r0 0)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (ld sp r8 8)                ; the saved sp
         (ld lr r8 0)                ; the saved return pc
         (ret)                       ; jalr x0, 0(ra)

         ; -- __love_sigret: rt_sigreturn, laid for surface parity (riscv's
         ;    sigaction rides the kernel's vdso trampoline, like a64).
         (label __love_sigret)
         (li r7 139)                 ; rt_sigreturn
         (sys)

         ; -- __love_clone, __love_tp: as a64's (riscv's clone also wants tls before ctid)
         (label __love_clone)
         (mov r8 r3)                 ; t0 <- ctid
         (mov r3 r4)                 ; a3 <- tls
         (mov r4 r8)                 ; a4 <- ctid
         (li r7 220)                 ; clone
         (sys)
         (cmp r0 0)
         (br ne clone-out)
         (ld r0 sp 8)                ; a0 <- arg
         (ld r8 sp 0)                ; fn
         (callr r8)
         (li r0 0)
         (li r7 93)                  ; exit
         (sys)
         (label clone-out)
         (ret)
         (label __love_tp)
         (raw (19 5 2 0))            ; addi a0, tp, 0
         (ret)))
       ; what each lane exports, and the three differ: the wide door rides wherever
       ; a BSD does (x64 through the stack, arm64 through x6), and riscv exports
       ; neither it nor the netbsd pair -- nothing has laid that tail, which is
       ; the whole of what impl.h's LvOsTranslate says to the C.
       (objelf arch ir ()
               (? (arch = 'x64)
                  '("__love_sys" "__love_sys7" "__sigsetjmp" "siglongjmp" "__love_sigret" "__love_nb_sigtramp" "__love_clone")
                  (arch = 'a64)
                  '("__love_sys" "__love_sys7" "__sigsetjmp" "siglongjmp" "__love_sigret"
                    "__love_nb_sigtramp" "__love_nbp20" "__love_nbp202" "__love_clone" "__love_tp")
                  '("__love_sys" "__sigsetjmp" "siglongjmp" "__love_sigret" "__love_clone" "__love_tp"))
               () () () () () () ())))
) ; module 'moon
