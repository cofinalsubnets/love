; src/apps/moon/lib/mksys.l -- lay sys.o, the hand-written leaves C cannot say: the syscall
; doors (__love_sys..), __sigsetjmp / siglongjmp (the mask is load-bearing: the fault barrier
; jumps out of a handler), the signal trampolines, clone and the thread pointer.
; one object per arch serves every kernel, branching on __love_osv; a BSD's carry error is
; parked as -(errno+4096), so __love_call reads one law.
; x64 jmp_buf (25 longs): [0..5] rbx rbp r12 r13 r14 r15, [6] rsp, [7] rip, [8] the mask.
; holo x64: r0=rax r1=rcx r2=rdx r3=rbx r4=rbp r5=rsi r6=rdi r7=r8 r8=r9 r9=r10 r10=r11
; r11=r12 r12=r13 r13=r14 r14=r15.
(module 'moon
(borrow 'holo) ; objelf, the relocatable writer
(: (mksys-x64 dst) (mksys-as 'x64 dst)
   (mksys-a64 dst) (mksys-as 'a64 dst)
   (mksys-rv64 dst) (mksys-as 'rv64 dst)
   (mksys-i386 dst) (mksys-as 'i386 dst)
   (mksys-arm dst) (mksys-as 'arm dst)
   (mksys-freebsd dst) (mksys-as 'x64 dst)   ; one object serves both kernels
   (mksys-as arch dst) (write-bytes dst (mksys-bytes arch))
   ; netbsd/a64 reads the syscall number from the svc immediate only, with no indirect
   ; door, so lay one `svc #n; ret' per number and branch into it. the bound 512 is spelled
   ; at each site: a forward value in this group would not resolve
   (nb-tab i acc) (i < 0 ? acc (nb-tab (i - 1) (['svcn i] . ['ret] . acc)))
   (mksys-bytes arch)
    (: ir (? (arch = 'x64)
         '(
         ; -- __love_sys: SysV args -> the kernel's (rax rdi rsi rdx r10 r8 r9), each mov
         ;    reading a slot just drained. os-blind: cf goes in clear, linux leaves it
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

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam, then the
         ;    mask into buf[8] (a BSD's 16-byte set takes buf[8..9])
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
         (cmp r1 4)
         (br eq sj-mac)
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
         (label sj-mac)
         (li r6 1)
         (sub sp sp 8)
         (call __love_macmask)       ; xnu's sigprocmask, a 4-byte set: by libSystem or the trap
         (add sp sp 8)
         (li r0 0)
         (ret)

         ; -- siglongjmp(buf, val): the mask first, then the file, then the saved rip.
         ;    val and buf ride rbp/rbx: freebsd's syscall exit zeroes the scratch registers
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
         (cmp r1 4)
         (br eq lj-mac)
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
         (jmp lj-file)
         (label lj-mac)
         (li r6 3)
         (sub sp sp 8)
         (call __love_macmask)       ; rbp and rbx ride the call
         (add sp sp 8)
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

         ; -- __love_sigret: linux's sa_restorer
         (label __love_sigret)
         (li r0 15)                  ; rt_sigreturn
         (sys)

         ; -- __love_clone(flags, sp, ptid, ctid, tls): linux's order. the child wakes on sp,
         ;    where its caller laid [fn arg], and calls fn(arg); the exit is a backstop
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

         ; -- __love_sys7(n,a..g): netbsd reads a 7th argument at [rsp+8], so g overwrites
         ;    the f slot once drained
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

         ; -- __love_nb_sigtramp: netbsd leaves the ucontext in r15; back through setcontext
         (label __love_nb_sigtramp)
         (mov r6 r14)                ; rdi <- r15 (the ucontext)
         (li r0 308)                 ; setcontext
         (sys)
         (li r6 -1)
         (li r0 1)                   ; exit
         (sys)

         ; -- __love_mac_sigtramp: xnu enters with (handler, style, sig, info, uctx, token)
         ;    and wants sigreturn(uctx, style, token); the three ride callee-saved registers
         (label __love_mac_sigtramp)
         (mov r3 r7)                 ; rbx <- uctx
         (mov r11 r5)                ; r12 <- style
         (mov r12 r8)                ; r13 <- token
         (mov r0 r6)                 ; the handler
         (mov r6 r2)                 ; rdi <- sig
         (mov r5 r1)                 ; rsi <- info
         (mov r2 r3)                 ; rdx <- uctx
         (and sp sp -16)
         (callr r0)
         (mov r6 r3)
         (mov r5 r11)
         (mov r2 r12)
         (li r0 33554616)            ; sigreturn 184
         (sys)
         (li r6 -1)
         (li r0 33554433)            ; exit
         (sys)

         ; -- __love_macfork: xnu's child gets the parent's pid and rdx 1; answer it 0
         (label __love_macfork)
         (li r0 33554434)            ; fork 2
         (cmp r0 0)
         (sys)
         (br below mf-err)
         (cmp r2 0)
         (br eq mf-out)
         (li r0 0)
         (label mf-out)
         (ret)
         (label mf-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)

         ; -- __love_macpipe: eax and edx answered as one word, edx high
         (label __love_macpipe)
         (li r0 33554474)            ; pipe 42
         (cmp r0 0)
         (sys)
         (br below mf-err)
         (shl r2 32)
         (or r0 r0 r2)
         (ret))

         (arch = 'i386)
         ; i386: linux reads ebx ecx edx esi edi ebp; the BSDs read the user stack above a
         ; return slot, error by carry, 64-bit answers in edx:eax. r0..r6 = eax ecx edx ebx
         ; ebp esi edi. jmp_buf: [0] ebx [4] esi [8] edi [12] ebp [16] esp [20] eip [32] mask
         '(
         (label __love_sys)
         (label __love_sysw)         ; __love_sys read as long long: a BSD's lseek in edx:eax
         (la r1 __love_osv)
         (ld r1 r1 0)
         (cmp r1 2)
         (br ge sys-bsd)
         (push r4) (push r6) (push r5) (push r3)
         (ld r0 sp 20)               ; eax <- n
         (ld r3 sp 24)               ; ebx <- a
         (ld r1 sp 28)               ; ecx <- b
         (ld r2 sp 32)               ; edx <- c
         (ld r5 sp 36)               ; esi <- d
         (ld r6 sp 40)               ; edi <- e
         (ld r4 sp 44)               ; ebp <- f
         (sys)
         (pop r3) (pop r5) (pop r6) (pop r4)
         (ret)
         (label sys-bsd)             ; f..a pushed: each push brings the next one to the same slot
         (ld r1 sp 28) (push r1) (ld r1 sp 28) (push r1) (ld r1 sp 28) (push r1)
         (ld r1 sp 28) (push r1) (ld r1 sp 28) (push r1) (ld r1 sp 28) (push r1)
         (push r1)                   ; the return slot
         (ld r0 sp 32)               ; eax <- n
         (cmp r0 0)                  ; clears the carry
         (sys)
         (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1)   ; a pop leaves the flags
         (br below sys-err)          ; `below' is carry set: a BSD error
         (ret)
         (label sys-err)
         (neg r0)
         (lea r0 r0 -4096)           ; -(errno+4096): parked for __love_call
         (li r2 -1)                  ; ..and the high word, for __love_sysw
         (ret)

         ; -- __love_sys8(n,a..h): a BSD's mmap, eight words; never linux's
         (label __love_sys8)
         (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1)
         (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1) (ld r1 sp 36) (push r1)
         (push r1)
         (ld r0 sp 40)               ; eax <- n
         (cmp r0 0)
         (sys)
         (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1) (pop r1)
         (br below sys-err)
         (ret)

         (label __sigsetjmp)
         (ld r1 sp 4)                ; ecx <- buf
         (st r1 0 r3)
         (st r1 4 r5)
         (st r1 8 r6)
         (st r1 12 r4)
         (lea r0 sp 4)               ; the caller's esp once we return
         (st r1 16 r0)
         (ld r0 sp 0)
         (st r1 20 r0)
         (lea r2 r1 32)              ; edx = oldset
         (la r0 __love_osv)
         (ld r0 r0 0)
         (cmp r0 2)
         (br ge sj-bsd)
         (push r3) (push r5)
         (li r3 0)                   ; ebx = SIG_BLOCK
         (li r1 0)                   ; ecx = NULL (read only)
         (li r5 8)                   ; esi = sigsetsize
         (li r0 175)                 ; rt_sigprocmask
         (sys)
         (pop r5) (pop r3)
         (li r0 0)
         (ret)
         (label sj-bsd)              ; sigprocmask(SIG_BLOCK, NULL, oldset), a 16-byte set
         (li r1 340)                 ; freebsd's
         (cmp r0 3)
         (br ne sj-num)
         (li r1 293)                 ; netbsd's __sigprocmask14
         (label sj-num)
         (push r2)
         (li r2 0) (push r2)
         (li r2 1) (push r2)
         (push r2)
         (mov r0 r1)
         (sys)
         (pop r1) (pop r1) (pop r1) (pop r1)
         (li r0 0)
         (ret)

         (label siglongjmp)
         (ld r6 sp 4)                ; edi <- buf, through the kernel
         (ld r4 sp 8)                ; ebp <- val
         (lea r1 r6 32)              ; ecx = the saved mask
         (la r0 __love_osv)
         (ld r0 r0 0)
         (cmp r0 2)
         (br ge lj-bsd)
         (li r3 2)                   ; ebx = SIG_SETMASK
         (li r2 0)
         (li r5 8)
         (li r0 175)
         (sys)
         (jmp lj-file)
         (label lj-bsd)              ; sigprocmask(SIG_SETMASK, mask, NULL)
         (li r2 340)
         (cmp r0 3)
         (br ne lj-num)
         (li r2 293)
         (label lj-num)
         (li r0 0) (push r0)
         (push r1)
         (li r0 3) (push r0)
         (push r0)
         (mov r0 r2)
         (sys)
         (pop r1) (pop r1) (pop r1) (pop r1)
         (label lj-file)
         (mov r0 r4)
         (ld r3 r6 0)
         (ld r5 r6 4)
         (ld r4 r6 12)
         (ld sp r6 16)
         (ld r1 r6 20)
         (ld r6 r6 8)                ; edi, last, off itself
         (cmp r0 0)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (jmpr r1)

         ; -- __love_sigret0: linux's return from a non-SA_SIGINFO frame
         (label __love_sigret0)
         (pop r0)
         (li r0 119)                 ; sigreturn
         (sys)

         ; -- __love_nb_sigtramp: the ucontext sits 140 bytes up; setcontext takes it
         (label __love_nb_sigtramp)
         (lea r0 sp 140)
         (st sp 4 r0)
         (li r0 308)                 ; setcontext
         (sys)
         (li r1 -1)
         (st sp 4 r1)
         (li r0 1)                   ; exit
         (sys)

         (label __love_sigret)
         (li r0 173)                 ; rt_sigreturn
         (sys)

         ; -- __love_clone: i386 orders (flags sp ptid tls ctid). the child finds [fn arg sel]
         ;    on sp, loads gs with sel and calls fn(arg)
         (label __love_clone)
         (push r4) (push r6) (push r5) (push r3)
         (ld r3 sp 20)
         (ld r1 sp 24)
         (ld r2 sp 28)
         (ld r6 sp 32)
         (ld r5 sp 36)
         (li r0 120)                 ; clone
         (sys)
         (cmp r0 0)
         (br ne clone-out)
         (ld r0 sp 8)
         (raw (142 232))             ; mov gs, eax
         (ld r0 sp 0)
         (ld r1 sp 4)
         (push r1)
         (callr r0)
         (li r3 0)
         (li r0 1)                   ; exit
         (sys)
         (label clone-out)
         (pop r3) (pop r5) (pop r6) (pop r4)
         (ret)

         ; -- __love_tp: the word at gs:0, or 0 while gs holds no selector (the first thread)
         (label __love_tp)
         (li r0 0)
         (raw (102 140 232))         ; mov ax, gs
         (cmp r0 0)
         (br eq tp-none)
         (raw (101 161 0 0 0 0))     ; mov eax, gs:[0]
         (label tp-none)
         (ret))

         (arch = 'arm)
         ; arm: linux reads r0-r5, number in r7; freebsd r0-r3 + the stack, number in r7;
         ; netbsd number in r0, first arg in ip, svc #255. a BSD errors by carry, linux keeps
         ; the flags. jmp_buf: [0..28] r4-r11, [32] sp, [36] lr, [40..103] d8-d15, [104] mask
         '(
         ; -- __love_sys8 and __love_sys: g h, or two zeros, pushed, then one tail.
         ;    __love_sysw: a BSD's lseek answers in r0:r1
         (label __love_sys8)
         (push r4) (push r5) (push r7)
         (ld r4 sp 28)               ; h, past the three pushes
         (ld r5 sp 24)               ; g
         (push r4) (push r5)
         (jmp sys-tail)
         (label __love_sys)
         (label __love_sysw)
         (push r4) (push r5) (push r7)
         (li r4 0)
         (push r4) (push r4)
         (label sys-tail)            ; [sp] g, [sp+4] h, [sp+20] d, [sp+24] e, [sp+28] f
         (la r12 __love_osv)
         (ld r12 r12 0)
         (cmp r12 2)
         (br ge sys-bsd)
         (mov r7 r0)                 ; r7 <- n
         (mov r0 r1)                 ; r0 <- a
         (mov r1 r2)                 ; r1 <- b
         (mov r2 r3)                 ; r2 <- c
         (ld r3 sp 20)               ; r3 <- d
         (ld r4 sp 24)               ; r4 <- e
         (ld r5 sp 28)               ; r5 <- f
         (sys)
         (jmp sys-out)
         (label sys-bsd)
         (ld r4 sp 4)                ; h
         (ld r5 sp 0)                ; g
         (ld r7 sp 28)               ; f
         (push r4) (push r5) (push r7)
         (ld r7 sp 36)               ; e
         (push r7)                   ; [sp] e f g h: where the kernel reads them
         (cmp r12 3)
         (br eq sys-nb)
         (mov r7 r0)                 ; freebsd: r7 <- n, r0 <- a
         (mov r0 r1)
         (mov r1 r2)
         (mov r2 r3)
         (ld r3 sp 36)               ; d
         (li r4 0)                   ; 0 - 1 borrows, so C goes clear
         (cmp r4 1)
         (sys)                       ; svc #0: freebsd on arm64 sigills any other
         (jmp sys-bsd1)
         (label sys-nb)
         (mov r12 r1)                ; netbsd: ip <- a, n stays in r0
         (mov r1 r2)
         (mov r2 r3)
         (ld r3 sp 36)
         (li r4 0)
         (cmp r4 1)
         (raw (255 223))             ; svc #255: netbsd's 32-bit lane on arm64 wants no other
         (label sys-bsd1)
         (pop r4) (pop r4) (pop r4) (pop r4)   ; e f g h off; a pop leaves the flags
         (br ae sys-err)
         (label sys-out)
         (pop r4) (pop r4)           ; g h off
         (pop r7) (pop r5) (pop r4)
         (ret)
         (label sys-err)
         (neg r0)
         (lea r0 r0 -4096)           ; -(errno+4096): parked for __love_call
         (li r1 -1)                  ; ..and the high word, for __love_sysw
         (jmp sys-out)

         (label __sigsetjmp)
         (st r0 0 r4) (st r0 4 r5) (st r0 8 r6) (st r0 12 r7)
         (st r0 16 r8) (st r0 20 r9) (st r0 24 r10) (st r0 28 r11)
         (mov r12 sp)                ; str cannot take sp
         (st r0 32 r12)
         (st r0 36 lr)
         (lea r12 r0 40)
         (raw (140 236 16 139))      ; vstmia r12, {d8-d15}
         (lea r2 r0 104)             ; oldset
         (push r7)
         (li r1 0)                   ; NULL (read only)
         (la r12 __love_osv)
         (ld r12 r12 0)
         (cmp r12 2)
         (br eq sj-fb)
         (cmp r12 3)
         (br eq sj-nb)
         (li r0 0)                   ; SIG_BLOCK
         (li r3 8)                   ; sigsetsize
         (li r7 175)                 ; rt_sigprocmask
         (sys)
         (jmp sj-out)
         (label sj-fb)
         (li r0 1)                   ; SIG_BLOCK (both BSDs: 1), a 16-byte set
         (li r7 340)                 ; sigprocmask
         (sys)
         (jmp sj-out)
         (label sj-nb)
         (li r12 1)
         (li r0 293)                 ; __sigprocmask14
         (raw (255 223))
         (label sj-out)
         (pop r7)
         (li r0 0)
         (ret)

         (label siglongjmp)
         (mov r4 r0)                 ; buf and val ride callee-saved through the kernel
         (mov r5 r1)
         (lea r1 r4 104)             ; the saved mask
         (li r2 0)
         (la r12 __love_osv)
         (ld r12 r12 0)
         (cmp r12 2)
         (br eq lj-fb)
         (cmp r12 3)
         (br eq lj-nb)
         (li r0 2)                   ; SIG_SETMASK
         (li r3 8)
         (li r7 175)
         (sys)
         (jmp lj-file)
         (label lj-fb)
         (li r0 3)                   ; SIG_SETMASK (both BSDs: 3)
         (li r7 340)
         (sys)
         (jmp lj-file)
         (label lj-nb)
         (li r12 3)
         (li r0 293)
         (raw (255 223))
         (label lj-file)
         (mov r0 r5)
         (cmp r0 0)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (lea r12 r4 40)
         (raw (156 236 16 139))      ; vldmia r12, {d8-d15}
         (ld r5 r4 4) (ld r6 r4 8) (ld r7 r4 12) (ld r8 r4 16)
         (ld r9 r4 20) (ld r10 r4 24) (ld r11 r4 28)
         (ld r12 r4 32)
         (mov sp r12)
         (ld lr r4 36)
         (ld r4 r4 0)                ; r4, last, off itself
         (jmpr lr)

         ; -- __love_fbfork: freebsd's fork from arm state -- its child keeps the mode but
         ;    not the thumb bit. the carry rides the bx
         (label __love_fbfork)
         (push lr)
         (la r12 fbfork-arm)
         (raw (44 240 1 12))         ; bic ip, ip, #1: the link marks a label in this text thumb
         (callr r12)                 ; blx to an even address: arm state
         (pop lr)
         (br ae fbfork-err)
         (ret)
         (label fbfork-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)
         (align 4)
         (label fbfork-arm)
         (raw (4 112 45 229))        ; str r7, [sp, #-4]!
         (raw (2 112 160 227))       ; mov r7, #2 (fork)
         (raw (0 0 0 239))           ; svc #0
         (raw (4 112 157 228))       ; ldr r7, [sp], #4
         (raw (30 255 47 225))       ; bx lr

         ; -- __love_nb_sigtramp: the ucontext in r5, back through setcontext
         (label __love_nb_sigtramp)
         (mov r12 r5)
         (li r0 308)                 ; setcontext
         (raw (255 223))
         (mov r12 r0)
         (li r0 1)                   ; exit
         (raw (255 223))

         (label __love_sigret)
         (li r7 173)                 ; rt_sigreturn
         (sys)

         ; -- __love_clone: arm orders (flags sp ptid tls ctid); the child calls fn(arg) off sp
         (label __love_clone)
         (push r4) (push r7)
         (mov r4 r3)                 ; r4 <- ctid
         (ld r3 sp 8)                ; r3 <- tls, the stack arg past two pushes
         (li r7 120)                 ; clone
         (sys)
         (cmp r0 0)
         (br ne clone-out)
         (ld r0 sp 4)
         (ld r12 sp 0)
         (callr r12)
         (li r0 0)
         (li r7 1)                   ; exit
         (sys)
         (label clone-out)
         (pop r7) (pop r4)
         (ret)

         ; -- __love_tp: TPIDRURO, 0 in the first thread
         (label __love_tp)
         (raw (29 238 112 15))       ; mrc p15, 0, r0, c13, c0, 3
         (ret))

         (arch = 'a64)
         ; a64: the written leaves ++ the netbsd table. rN = xN. jmp_buf: [0..9] x19..x28,
         ; [10] fp, [11] sp, [12] lr, [13..20] d8..d15 (low halves, as AAPCS), [21] mask
         ('(
         ; -- __love_sys: x0..x6 (n,a..f) -> x8=nr, x0..x5. os-blind: C goes in clear and
         ;    linux preserves nzcv, so a set carry is a BSD's error
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

         ; -- netbsd: the same shuffle, then call into the number's stub; out of range is enosys
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

         ; -- __love_sys7(n,a..g): the seventh is just another register
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

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam, the mask into buf[21]
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

         ; -- siglongjmp(buf, val): the mask, the file, ret through the saved lr. buf and val
         ;    ride x19/x20: freebsd's syscall exit zeroes the caller-saved registers
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

         ; -- __love_sigret: unused (the kernel's vdso trampoline serves), laid for parity
         (label __love_sigret)
         (li r8 139)                 ; rt_sigreturn
         (sys)

         ; -- __love_clone: tls before ctid, so x3/x4 swap; the child calls sp[0](sp[1])
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

         ; -- __love_nb_sigtramp: the ucontext in x28, back through setcontext
         (label __love_nb_sigtramp)
         (mov r0 r28)
         (svcn 308)                  ; setcontext
         (li r0 1)
         (svcn 1)                    ; exit, never reached

         ; -- the OS probe, before __love_osv is known: x8 and the immediate carry one number,
         ;    linux reads x8, netbsd the immediate. 20: getpid on netbsd, -EINVAL on linux;
         ;    202 is __sysctl. freebsd sigills on any nonzero immediate; crt0 knows it first
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

         ; rv64: the number in a7 (linux), t0 (freebsd), t6 (netbsd). a BSD error: freebsd
         ; raises t0; netbsd resumes one word past the ecall, success three, so the raw tail
         ; li t0 1 / j .+8 / li t0 0 makes one flag. t6 is holo's scratch: netbsd's number
         ; goes in raw. r0..r7 = a0..a7, r8..r11 = t0..t3, fp = s0, r15/r13/r14 = s1/s2/s3,
         ; r19..r26 = s4..s11, lr = ra. jmp_buf: [0] ra, [1] sp, [2..13] s0..s11, [14] mask;
         ; no fp slots, as mooncc's fp file is all caller-saved
         '(
         ; -- __love_sys: args a0..a6 (n,a..f) -> the number, then a0..a5.
         (label __love_sys)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (mov r8 r0)                 ; t0 <- n (freebsd's)
         (mov r7 r0)                 ; a7 <- n (linux's)
         (mov r0 r1)                 ; a0 <- a
         (mov r1 r2)                 ; a1 <- b
         (mov r2 r3)                 ; a2 <- c
         (mov r3 r4)                 ; a3 <- d
         (mov r4 r5)                 ; a4 <- e
         (mov r5 r6)                 ; a5 <- f
         (cmp r9 2)
         (br eq sys-fb)
         (cmp r9 3)
         (br eq sys-nb)
         (sys)
         (ret)                       ; linux: a0 rides out (-errno included; C wraps it)
         (label sys-fb)
         (sys)                       ; t0 0, or 1 with the errno in a0
         (jmp sys-chk)
         (label sys-nb)
         (raw (147 143 2 0))         ; mv t6, t0
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1: an error resumes here
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0: success resumes here
         (label sys-chk)
         (cmp r8 0)
         (br ne sys-err)
         (ret)
         (label sys-err)
         (neg r0)
         (lea r0 r0 -4096)           ; -(errno+4096): parked for __love_call
         (ret)

         ; -- __love_sys7(n,a..g): the seventh in a6
         (label __love_sys7)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (mov r8 r0)                 ; t0 <- n
         (mov r0 r1)
         (mov r1 r2)
         (mov r2 r3)
         (mov r3 r4)
         (mov r4 r5)
         (mov r5 r6)
         (mov r6 r7)                 ; a6 <- g, the seventh
         (mov r7 r8)                 ; a7 <- n
         (cmp r9 2)
         (br eq sys7-fb)
         (cmp r9 3)
         (br eq sys7-nb)
         (sys)
         (ret)
         (label sys7-fb)
         (sys)
         (jmp sys7-chk)
         (label sys7-nb)
         (raw (147 143 2 0))         ; mv t6, t0
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (label sys7-chk)
         (cmp r8 0)
         (br ne sys7-err)
         (ret)
         (label sys7-err)
         (neg r0)
         (lea r0 r0 -4096)
         (ret)

         ; -- __sigsetjmp(buf, save): the callee-saved file, the return seam, the mask into buf[14]
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
         (li r3 8)                   ; a3 = sigsetsize (linux's fourth)
         (la r9 __love_osv)
         (ld r9 r9 0)
         (cmp r9 2)
         (br eq sj-fb)
         (cmp r9 3)
         (br eq sj-nb)
         (li r0 0)                   ; a0 = SIG_BLOCK (linux 0)
         (li r7 135)                 ; rt_sigprocmask
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
         (raw (147 15 80 18))        ; li t6, 293: __sigprocmask14
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (li r0 0)
         (ret)

         ; -- siglongjmp(buf, val): buf and val ride t1/t2, which every kernel here keeps
         (label siglongjmp)
         (mov r9 r0)                 ; t1 <- buf
         (mov r10 r1)                ; t2 <- val
         (lea r1 r9 112)             ; a1 = &buf[14] (the saved mask)
         (li r2 0)                   ; a2 = NULL (oset)
         (li r3 8)                   ; a3 = sigsetsize (linux's fourth)
         (la r11 __love_osv)
         (ld r11 r11 0)
         (cmp r11 2)
         (br eq lj-fb)
         (cmp r11 3)
         (br eq lj-nb)
         (li r0 2)                   ; a0 = SIG_SETMASK (linux 2)
         (li r7 135)                 ; rt_sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-fb)
         (li r0 3)                   ; SIG_SETMASK (both BSDs: 3)
         (li r8 340)                 ; sigprocmask
         (sys)
         (jmp lj-file)
         (label lj-nb)
         (li r0 3)
         (raw (147 15 80 18))        ; li t6, 293: __sigprocmask14
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (label lj-file)
         (ld fp  r9 16)
         (ld r15 r9 24)
         (ld r13 r9 32)
         (ld r14 r9 40)
         (ld r19 r9 48)
         (ld r20 r9 56)
         (ld r21 r9 64)
         (ld r22 r9 72)
         (ld r23 r9 80)
         (ld r24 r9 88)
         (ld r25 r9 96)
         (ld r26 r9 104)
         (mov r0 r10)                ; a0 <- val, 0 lifted to 1 (the setjmp law)
         (cmp r0 0)
         (br ne lj-live)
         (li r0 1)
         (label lj-live)
         (ld sp r9 8)                ; the saved sp
         (ld lr r9 0)                ; the saved return pc
         (ret)                       ; jalr x0, 0(ra)

         ; -- __love_sigret: unused (vdso trampoline), laid for parity
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
         (ret)

         ; -- __love_nb_sigtramp: sp at the 128-byte siginfo, then the ucontext for setcontext
         (label __love_nb_sigtramp)
         (lea r0 sp 128)             ; a0 <- the ucontext
         (raw (147 15 64 19))        ; li t6, 308: setcontext
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (li r0 1)
         (raw (147 15 16 0))         ; li t6, 1: exit, never reached
         (raw (115 0 0 0))           ; ecall

         ; -- the OS probe, as a64's: a7 and t6 carry one number
         (label __love_nbp20)
         (li r7 20)
         (raw (147 15 64 1))         ; li t6, 20
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (ret)
         (label __love_nbp202)
         (li r7 202)
         (raw (147 15 160 12))       ; li t6, 202
         (raw (115 0 0 0))           ; ecall
         (raw (147 2 16 0))          ; li t0, 1
         (raw (111 0 128 0))         ; j .+8
         (raw (147 2 0 0))           ; li t0, 0
         (ret)))
       ; what each lane exports; the 32-bit lanes lay no __love_sys7 and no probes
       (objelf arch ir ()
               (? (arch = 'x64)
                  '("__love_sys" "__love_sys7" "__sigsetjmp" "siglongjmp" "__love_sigret" "__love_nb_sigtramp" "__love_clone"
                    "__love_mac_sigtramp" "__love_macfork" "__love_macpipe")
                  (arch = 'a64)
                  '("__love_sys" "__love_sys7" "__sigsetjmp" "siglongjmp" "__love_sigret"
                    "__love_nb_sigtramp" "__love_nbp20" "__love_nbp202" "__love_clone" "__love_tp")
                  (arch = 'arm)
                  '("__love_sys" "__love_sysw" "__love_sys8" "__love_fbfork" "__sigsetjmp" "siglongjmp" "__love_sigret" "__love_nb_sigtramp" "__love_clone" "__love_tp")
                  (arch = 'i386)
                  '("__love_sys" "__love_sysw" "__love_sys8" "__sigsetjmp" "siglongjmp" "__love_sigret" "__love_sigret0" "__love_nb_sigtramp" "__love_clone" "__love_tp")
                  '("__love_sys" "__love_sys7" "__sigsetjmp" "siglongjmp" "__love_sigret"
                    "__love_nb_sigtramp" "__love_nbp20" "__love_nbp202" "__love_clone" "__love_tp"))
               () () () () () () ())))
) ; module 'moon
