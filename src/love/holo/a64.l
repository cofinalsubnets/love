; a64 -- the aarch64 backend for holo. fixed 32-bit words, three-address ALU, rN = xN, sp = 31.
; a branch offset is a bitfield, so its fixup carries the base word in aux and patch ors it in.
; immediates: add/sub/cmp take imm12 (a negative flips the op), and/or/xor/test a bitmask
; immediate; mul has none, and an immediate that cannot encode scares.

(module 'holo
(: ;; the instruction table, one row a machine instruction: [name match mask kinds], a word is
   ;; the first row's with (w & mask) = match, its operands the kinds in text order (decode.l
   ;; reads them). a register kind is (class field): class r x w by sf or fixed, R X W with 31
   ;; as sp, f by ftype, b h s d q fixed, v vb vw vf vn by the vector arrangement; field d n m a
   ;; the register at bit 0, 5, 16 or 10
   ;; register classes, arrangements, shift and extend names: the decoder's and the encoder's
   a6t-rcls '(r R x w X W f fs v vb vw vn vf b h s d q)
   a6t-arr ["8b" "16b" "4h" "8h" "2s" "4s" "1d" "2d"]
   a6t-shn '(lsl lsr asr ror)
   a6t-extn '(uxtb uxth uxtw uxtx sxtb sxth sxtw sxtx)
   ;; an fp immediate's imm8 as llvm prints it
   (a6t-fimm i8)
    (: m (16 + (i8 & 15)) bcd (i8 >> 4 & 7) ex (bcd < 4 ? (bcd + 1) (bcd - 7))
       n (ex >= 4 ? (m * 100000000 * (ex - 4) 2) (m * 100000000 // (4 - ex) 2))
       fr (show (n % 100000000))
       ("#" + (i8 >> 7 ? "-" "") + show (n // 100000000) + "." + catall (map (_ \ "0") ^(8 - #fr)) + fr))
   (a6t-cc k) ('(eq ne hs lo mi pl vs vc hi ls ge lt gt le al nv) k)
   (a6t-in nm c) (show nm @ s (name (snip s 0 2 + c + snip s 2 #s)))
   (a6t-ls r)
    (: nm <r u (r 1) t (r 2) sc (r 3) b (u - 0x1000000) pf (nm = 'prfm)
       int (two? t && elem <t '(w x))
       (catall [[[nm u 0xffc00000 [t ['mu sc]]] [(pf ? 'prfum (a6t-in nm "u")) b 0xffe00c00 [t 'mo]]
                 [nm (b | 0x200800) 0xffe00c00 [t ['mr sc]]]]
                (pf ? () [[nm (b | 0x400) 0xffe00c00 [t 'mpost]] [nm (b | 0xc00) 0xffe00c00 [t 'mpre]]])
                (int ? [[(a6t-in nm "t") (b | 0x800) 0xffe00c00 [t 'mo]]] ())]))
   (a6t-pair r)
    (: nm <r b (r 1) c (r 2) sc (r 3) (ks k) [[c 'd] [c 'a] [k sc]]
       (catall [[[nm (b | 0x1000000) 0xffc00000 (ks 'mp)] [nm (b | 0x800000) 0xffc00000 (ks 'mpp)]
                 [nm (b | 0x1800000) 0xffc00000 (ks 'mpr)]]
                (nm = 'ldpsw ? () [[(name (snip (show nm) 0 2 + "np")) b 0xffc00000 (ks 'mp)]])]))
   (a6t-sz s) (["b" "h" "" ""] s)
   (a6t-ex s)
    (: rt (s = 3 ? 'x 'w) b (s << 30 | 0x08007c00)
       (map (r \ [(name (show <r + a6t-sz s)) (b | r 1) (r 2) (r 3)])
            [['stxr 0 0xffe0fc00 [['w 'm] [rt 'd] 'm0]] ['stlxr 0x8000 0xffe0fc00 [['w 'm] [rt 'd] 'm0]]
             ['ldxr 0x5f0000 0xfffffc00 [[rt 'd] 'm0]] ['ldaxr 0x5f8000 0xfffffc00 [[rt 'd] 'm0]]
             ['stllr 0x9f0000 0xfffffc00 [[rt 'd] 'm0]] ['stlr 0x9f8000 0xfffffc00 [[rt 'd] 'm0]]
             ['ldlar 0xdf0000 0xfffffc00 [[rt 'd] 'm0]] ['ldar 0xdf8000 0xfffffc00 [[rt 'd] 'm0]]]))
   (a6t-al k) (["" "l" "a" "al"] k)
   (a6t-cas s)
    ((s = 3 ? 'x 'w) @ rt
     (map (k \ [(name ("cas" + a6t-al k + a6t-sz s)) (s << 30 | 0x08a07c00 | (k >> 1) << 22 | (k & 1) << 15)
                0xffe0fc00 [[rt 'm] [rt 'd] 'm0]])
          ^4))
   (a6t-lse s)
    ((s = 3 ? 'x 'w) @ rt
     (catmap (k \ map (o \ [(name (show <o + a6t-al k + a6t-sz s))
                           (s << 30 | 0x38200000 | (k >> 1) << 23 | (k & 1) << 22 | o 1 << 12) 0xffe0fc00
                           [[rt 'm] [rt 'd] 'm0]])
                     '((ldadd 0) (ldclr 1) (ldeor 2) (ldset 3) (ldsmax 4) (ldsmin 5) (ldumax 6)
                       (ldumin 7) (swp 8)))
             ^4))
   ;; rows (name match) sharing a mask and kinds
   (a6t-all mask ks l) (map (r \ [<r (r 1) mask ks]) l)
   a64-tab (catall [
     (a6t-all 0x7f800000 '((R d) (R n) aimm) '((add 0x11000000) (sub 0x51000000)))
     (a6t-all 0x7f800000 '((r d) (R n) aimm) '((adds 0x31000000) (subs 0x71000000)))
     (a6t-all 0x7f800000 '((R d) (r n) bimm) '((and 0x12000000) (orr 0x32000000) (eor 0x52000000)))
     [['ands 0x72000000 0x7f800000 '((r d) (r n) bimm)]]
     (a6t-all 0x7f800000 '((r d) imm16) '((movn 0x12800000) (movz 0x52800000) (movk 0x72800000)))
     (a6t-all 0x7f800000 '((r d) (r n) immr imms) '((sbfm 0x13000000) (bfm 0x33000000) (ubfm 0x53000000)))
     [['extr 0x13800000 0x7fa00000 '((r d) (r n) (r m) lsb)]
      ['adr 0x10000000 0x9f000000 '((x d) adr)] ['adrp 0x90000000 0x9f000000 '((x d) adrp)]
      ['b 0x14000000 0xfc000000 '(l26)] ['bl 0x94000000 0xfc000000 '(l26)]]
     (map (c \ [(name ("b." + show (a6t-cc c))) (0x54000000 | c) 0xff00001f '(l19)]) ^16)
     (a6t-all 0x7f000000 '((r d) l19) '((cbz 0x34000000) (cbnz 0x35000000)))
     (a6t-all 0x7f000000 '(tr tbit l14) '((tbz 0x36000000) (tbnz 0x37000000)))
     (a6t-all 0xfffffc1f '((x n)) '((br 0xd61f0000) (blr 0xd63f0000) (ret 0xd65f0000)))
     [['eret 0xd69f03e0 0xffffffff ()] ['drps 0xd6bf03e0 0xffffffff ()]]
     (a6t-all 0xffe0001f '(x16) '((svc 0xd4000001) (hvc 0xd4000002) (smc 0xd4000003) (brk 0xd4200000)
                                  (hlt 0xd4400000)))
     [['udf 0 0xffff0000 '(u16)]
      ['hint 0xd503201f 0xfffff01f '(hint7)] ['clrex 0xd503305f 0xfffff0ff '(crm)]
      ['dsb 0xd503309f 0xfffff0ff '(bar)] ['dmb 0xd50330bf 0xfffff0ff '(bar)]
      ['isb 0xd50330df 0xfffff0ff '(isbo)]
      ['msr 0xd500401f 0xfff8f01f '(pstate)]
      ['sys 0xd5080000 0xfff80000 '(sysop)] ['sysl 0xd5280000 0xfff80000 '((x d) sysl)]
      ['msr 0xd5100000 0xfff00000 '(sreg (x d))] ['mrs 0xd5300000 0xfff00000 '((x d) sreg)]
      ['ldr 0x18000000 0xff000000 '((w d) l19)] ['ldr 0x58000000 0xff000000 '((x d) l19)]
      ['ldrsw 0x98000000 0xff000000 '((x d) l19)] ['ldr 0x1c000000 0xff000000 '((s d) l19)]
      ['ldr 0x5c000000 0xff000000 '((d d) l19)] ['ldr 0x9c000000 0xff000000 '((q d) l19)]
      ['prfm 0xd8000000 0xff000000 '(prf l19)]]
     (catmap a6t-ls
      '((strb 0x39000000 (w d) 1) (ldrb 0x39400000 (w d) 1) (ldrsb 0x39800000 (x d) 1)
        (ldrsb 0x39c00000 (w d) 1) (strh 0x79000000 (w d) 2) (ldrh 0x79400000 (w d) 2)
        (ldrsh 0x79800000 (x d) 2) (ldrsh 0x79c00000 (w d) 2) (str 0xb9000000 (w d) 4)
        (ldr 0xb9400000 (w d) 4) (ldrsw 0xb9800000 (x d) 4) (str 0xf9000000 (x d) 8)
        (ldr 0xf9400000 (x d) 8) (prfm 0xf9800000 prf 8)
        (str 0x3d000000 (b d) 1) (ldr 0x3d400000 (b d) 1) (str 0x3d800000 (q d) 16)
        (ldr 0x3dc00000 (q d) 16) (str 0x7d000000 (h d) 2) (ldr 0x7d400000 (h d) 2)
        (str 0xbd000000 (s d) 4) (ldr 0xbd400000 (s d) 4) (str 0xfd000000 (d d) 8)
        (ldr 0xfd400000 (d d) 8)))
     (catmap a6t-pair
      '((stp 0x28000000 w 4) (ldp 0x28400000 w 4) (ldpsw 0x68400000 x 4) (stp 0xa8000000 x 8)
        (ldp 0xa8400000 x 8) (stp 0x2c000000 s 4) (ldp 0x2c400000 s 4) (stp 0x6c000000 d 8)
        (ldp 0x6c400000 d 8) (stp 0xac000000 q 16) (ldp 0xac400000 q 16)))
     (catmap a6t-ex ^4) (catmap a6t-cas ^4) (catmap a6t-lse ^4)
     (a6t-all 0x7f200000 '((r d) (r n) (r m) lsh)
      '((and 0x0a000000) (bic 0x0a200000) (orr 0x2a000000) (orn 0x2a200000) (eor 0x4a000000)
        (eon 0x4a200000) (ands 0x6a000000) (bics 0x6a200000)))
     (a6t-all 0x7f200000 '((r d) (r n) (r m) ash)
      '((add 0x0b000000) (adds 0x2b000000) (sub 0x4b000000) (subs 0x6b000000)))
     (a6t-all 0x7fe00000 '((R d) (R n) xm ext) '((add 0x0b200000) (sub 0x4b200000)))
     (a6t-all 0x7fe00000 '((r d) (R n) xm ext) '((adds 0x2b200000) (subs 0x6b200000)))
     (a6t-all 0x7fe0fc00 '((r d) (r n) (r m))
      '((adc 0x1a000000) (adcs 0x3a000000) (sbc 0x5a000000) (sbcs 0x7a000000)
        (udiv 0x1ac00800) (sdiv 0x1ac00c00) (lslv 0x1ac02000) (lsrv 0x1ac02400) (asrv 0x1ac02800)
        (rorv 0x1ac02c00)))
     (a6t-all 0x7fe00c10 '((r n) (r m) nzcv cond) '((ccmn 0x3a400000) (ccmp 0x7a400000)))
     (a6t-all 0x7fe00c10 '((r n) ccimm nzcv cond) '((ccmn 0x3a400800) (ccmp 0x7a400800)))
     (a6t-all 0x7fe00c00 '((r d) (r n) (r m) cond)
      '((csel 0x1a800000) (csinc 0x1a800400) (csinv 0x5a800000) (csneg 0x5a800400)))
     (a6t-all 0x7ffffc00 '((r d) (r n)) '((rbit 0x5ac00000) (rev16 0x5ac00400) (clz 0x5ac01000) (cls 0x5ac01400)))
     (a6t-all 0xfffffc00 '((r d) (r n)) '((rev 0x5ac00800) (rev32 0xdac00800) (rev 0xdac00c00)))
     (a6t-all 0xffe0fc00 '((w d) (w n) (w m))
      '((crc32b 0x1ac04000) (crc32h 0x1ac04400) (crc32w 0x1ac04800)
        (crc32cb 0x1ac05000) (crc32ch 0x1ac05400) (crc32cw 0x1ac05800)))
     (a6t-all 0xffe0fc00 '((w d) (w n) (x m)) '((crc32x 0x9ac04c00) (crc32cx 0x9ac05c00)))
     (a6t-all 0x7fe08000 '((r d) (r n) (r m) (r a)) '((madd 0x1b000000) (msub 0x1b008000)))
     (a6t-all 0xffe08000 '((x d) (w n) (w m) (x a))
      '((smaddl 0x9b200000) (smsubl 0x9b208000) (umaddl 0x9ba00000) (umsubl 0x9ba08000)))
     (a6t-all 0xffe0fc00 '((x d) (x n) (x m)) '((smulh 0x9b407c00) (umulh 0x9bc07c00)))
     ;; floating point, the width by ftype
     (a6t-all 0xff3ffc00 '((f d) (f n))
      '((fmov 0x1e204000) (fabs 0x1e20c000) (fneg 0x1e214000) (fsqrt 0x1e21c000)
        (frintn 0x1e244000) (frintp 0x1e24c000) (frintm 0x1e254000) (frintz 0x1e25c000)
        (frinta 0x1e264000) (frintx 0x1e274000) (frinti 0x1e27c000)))
     [['fcvt 0x1e22c000 0xfffffc00 '((d d) (s n))] ['fcvt 0x1e624000 0xfffffc00 '((s d) (d n))]
      ['fcvt 0x1e23c000 0xfffffc00 '((h d) (s n))] ['fcvt 0x1e63c000 0xfffffc00 '((h d) (d n))]
      ['fcvt 0x1ee24000 0xfffffc00 '((s d) (h n))] ['fcvt 0x1ee2c000 0xfffffc00 '((d d) (h n))]]
     (a6t-all 0xff20fc00 '((f d) (f n) (f m))
      '((fmul 0x1e200800) (fdiv 0x1e201800) (fadd 0x1e202800) (fsub 0x1e203800) (fmax 0x1e204800)
        (fmin 0x1e205800) (fmaxnm 0x1e206800) (fminnm 0x1e207800) (fnmul 0x1e208800)))
     (a6t-all 0xff208000 '((f d) (f n) (f m) (f a))
      '((fmadd 0x1f000000) (fmsub 0x1f008000) (fnmadd 0x1f200000) (fnmsub 0x1f208000)))
     (a6t-all 0xff20fc1f '((f n) (f m)) '((fcmp 0x1e202000) (fcmpe 0x1e202010)))
     (a6t-all 0xff20fc1f '((f n) fz) '((fcmp 0x1e202008) (fcmpe 0x1e202018)))
     (a6t-all 0xff200c10 '((f n) (f m) nzcv cond) '((fccmp 0x1e200400) (fccmpe 0x1e200410)))
     [['fcsel 0x1e200c00 0xff200c00 '((f d) (f n) (f m) cond)]
      ['fmov 0x1e201000 0xff201fe0 '((f d) fimm)]]
     (a6t-all 0xfffffc00 '((w d) (s n)) '((fmov 0x1e260000)))
     (a6t-all 0xfffffc00 '((s d) (w n)) '((fmov 0x1e270000)))
     (a6t-all 0xfffffc00 '((x d) (d n)) '((fmov 0x9e660000)))
     (a6t-all 0xfffffc00 '((d d) (x n)) '((fmov 0x9e670000)))
     (a6t-all 0xfffffc00 '((w d) (h n)) '((fmov 0x1ee60000)))
     (a6t-all 0xfffffc00 '((h d) (w n)) '((fmov 0x1ee70000)))
     (a6t-all 0xfffffc00 '((x d) (h n)) '((fmov 0x9ee60000)))
     (a6t-all 0xfffffc00 '((h d) (x n)) '((fmov 0x9ee70000)))
     [['fmov 0x9eae0000 0xfffffc00 '((x d) vd1n)] ['fmov 0x9eaf0000 0xfffffc00 '(vd1d (x n))]]
     (a6t-all 0x7f3ffc00 '((r d) (f n))
      '((fcvtns 0x1e200000) (fcvtnu 0x1e210000) (fcvtas 0x1e240000) (fcvtau 0x1e250000)
        (fcvtps 0x1e280000) (fcvtpu 0x1e290000) (fcvtms 0x1e300000) (fcvtmu 0x1e310000)
        (fcvtzs 0x1e380000) (fcvtzu 0x1e390000)))
     (a6t-all 0x7f3ffc00 '((f d) (r n)) '((scvtf 0x1e220000) (ucvtf 0x1e230000)))
     (a6t-all 0x7f3f0000 '((r d) (f n) fbits) '((fcvtzs 0x1e180000) (fcvtzu 0x1e190000)))
     (a6t-all 0x7f3f0000 '((f d) (r n) fbits) '((scvtf 0x1e020000) (ucvtf 0x1e030000)))
     (a6t-all 0xffbffc00 '((fs d) (fs n))
      '((scvtf 0x5e21d800) (ucvtf 0x7e21d800) (fcvtzs 0x5ea1b800) (fcvtzu 0x7ea1b800)))
     ;; simd. the modified immediates come before the shifts, which share their bits
     (a6t-all 0xbff89c00 '(modi) '((movi 0x0f000400) (orr 0x0f001400) (mvni 0x2f000400) (bic 0x2f001400)))
     (a6t-all 0xbff8dc00 '(modi) '((movi 0x0f008400) (orr 0x0f009400) (mvni 0x2f008400) (bic 0x2f009400)))
     (a6t-all 0xbff8ec00 '(modi) '((movi 0x0f00c400) (mvni 0x2f00c400)))
     (a6t-all 0xbff8fc00 '(modi) '((movi 0x0f00e400) (fmov 0x0f00f400) (movi 0x2f00e400)))
     [['fmov 0x6f00f400 0xfff8fc00 '(modi)]]
     (a6t-all 0xbf80fc00 '((vi d) (vi n) shr)
      '((sshr 0x0f000400) (ushr 0x2f000400) (ssra 0x0f001400) (usra 0x2f001400) (sri 0x2f004400)))
     (a6t-all 0xbf80fc00 '((vi d) (vi n) shl) '((shl 0x0f005400) (sli 0x2f005400)))
     (a6t-all 0xbf80fc00 '((vin d) (viw n) shr) '((shrn 0x0f008400) (rshrn 0x0f008c00)))
     (a6t-all 0xbf80fc00 '((viw d) (vin n) shl) '((sshll 0x0f00a400) (ushll 0x2f00a400)))
     (a6t-all 0xbf20fc00 '((v d) (v n) (v m))
      '((add 0x0e208400) (sub 0x2e208400) (cmeq 0x2e208c00) (cmtst 0x0e208c00) (cmhs 0x2e203c00)
        (cmhi 0x2e203400) (cmge 0x0e203c00) (cmgt 0x0e203400) (ushl 0x2e204400) (sshl 0x0e204400)
        (addp 0x0e20bc00)))
     (a6t-all 0xbf20fc00 '((vn d) (vn n) (vn m))
      '((mla 0x0e209400) (mls 0x2e209400) (mul 0x0e209c00) (smax 0x0e206400) (smin 0x0e206c00)
        (umax 0x2e206400) (umin 0x2e206c00)))
     (a6t-all 0xbfe0fc00 '((vb d) (vb n) (vb m))
      '((and 0x0e201c00) (bic 0x0e601c00) (orr 0x0ea01c00) (orn 0x0ee01c00) (eor 0x2e201c00)
        (bsl 0x2e601c00) (bit 0x2ea01c00) (bif 0x2ee01c00)))
     (a6t-all 0xbfa0fc00 '((vf d) (vf n) (vf m))
      '((fadd 0x0e20d400) (fsub 0x0ea0d400) (fmul 0x2e20dc00) (fdiv 0x2e20fc00) (faddp 0x2e20d400)
        (fmla 0x0e20cc00) (fmls 0x0ea0cc00) (fmax 0x0e20f400) (fmin 0x0ea0f400) (fcmeq 0x0e20e400)
        (fcmge 0x2e20e400) (fcmgt 0x2ea0e400)))
     (a6t-all 0xbffffc00 '((vb d) (vb n)) '((cnt 0x0e205800) (not 0x2e205800) (rbit 0x2e605800) (rev16 0x0e201800)))
     (a6t-all 0xbf3ffc00 '((vn d) (vn n)) '((rev64 0x0e200800)))
     [['rev32 0x2e200800 0xbfbffc00 '((v d) (v n))]]
     (a6t-all 0xbf3ffc00 '((v d) (v n)) '((abs 0x0e20b800) (neg 0x2e20b800)))
     (a6t-all 0xbf3ffc00 '((v d) (v n) z0)
      '((cmgt 0x0e208800) (cmge 0x2e208800) (cmeq 0x0e209800) (cmle 0x2e209800) (cmlt 0x0e20a800)))
     (a6t-all 0xbf3ffc00 '((vn d) (vw n)) '((xtn 0x0e212800)))
     (a6t-all 0xbfbffc00 '((vf d) (vf n))
      '((fabs 0x0ea0f800) (fneg 0x2ea0f800) (fsqrt 0x2ea1f800) (scvtf 0x0e21d800) (ucvtf 0x2e21d800)
        (fcvtzs 0x0ea1b800) (fcvtzu 0x2ea1b800)))
     (a6t-all 0xbfbffc00 '((vf d) (vf n) fz)
      '((fcmgt 0x0ea0c800) (fcmeq 0x0ea0d800) (fcmlt 0x0ea0e800) (fcmge 0x2ea0c800) (fcmle 0x2ea0d800)))
     (a6t-all 0xbf3ffc00 '(vsz (v n)) '((addv 0x0e31b800) (smaxv 0x0e30a800) (sminv 0x0e31a800)
                                        (umaxv 0x2e30a800) (uminv 0x2e31a800)))
     (a6t-all 0xbf3ffc00 '(vszw (v n)) '((saddlv 0x0e303800) (uaddlv 0x2e303800)))
     [['faddp 0x7e30d800 0xffbffc00 '(vpsz vp)] ['addp 0x5ef1b800 0xfffffc00 '((d d) v2d)]]
     (a6t-all 0xbf20fc00 '((vw d) (v n) (v m))
      '((saddl 0x0e200000) (ssubl 0x0e202000) (uaddl 0x2e200000) (usubl 0x2e202000) (smull 0x0e20c000)
        (umull 0x2e20c000) (smlal 0x0e208000) (umlal 0x2e208000)))
     (a6t-all 0xbf20fc00 '((vw d) (vw n) (v m))
      '((saddw 0x0e201000) (ssubw 0x0e203000) (uaddw 0x2e201000) (usubw 0x2e203000)))
     [['dup 0x0e000400 0xbfe0fc00 '((v5 d) (e5 n))] ['dup 0x0e000c00 0xbfe0fc00 '((v5 d) g5)]
      ; by element size, b and h to w, b h s to x; umov b h s to w, d to x
      ['smov 0x0e012c00 0xffe1fc00 '((w d) (e5 n))] ['smov 0x0e022c00 0xffe3fc00 '((w d) (e5 n))]
      ['smov 0x4e012c00 0xffe1fc00 '((x d) (e5 n))] ['smov 0x4e022c00 0xffe3fc00 '((x d) (e5 n))]
      ['smov 0x4e042c00 0xffe7fc00 '((x d) (e5 n))]
      ['umov 0x0e013c00 0xffe1fc00 '((w d) (e5 n))] ['umov 0x0e023c00 0xffe3fc00 '((w d) (e5 n))]
      ['umov 0x0e043c00 0xffe7fc00 '((w d) (e5 n))] ['umov 0x4e083c00 0xffeffc00 '((x d) (e5 n))]
      ['ins 0x4e001c00 0xffe0fc00 '((e5 d) g5)] ['ins 0x6e000400 0xffe08400 '((e5 d) e4)]
      ['dup 0x5e000400 0xffe0fc00 '(s5 (e5 n))]
      ['tbl 0x0e000000 0xbfe09c00 '((vb d) tlist (vb m))] ['tbx 0x0e001000 0xbfe09c00 '((vb d) tlist (vb m))]
      ['ext 0x2e000000 0xbfe08400 '((vb d) (vb n) (vb m) exti)]
      ['sha256su0 0x5e282800 0xfffffc00 '((v4s d) (v4s n))] ['sha1su1 0x5e281800 0xfffffc00 '((v4s d) (v4s n))]
      ['sha1h 0x5e280800 0xfffffc00 '((s d) (s n))]]
     (a6t-all 0xffe0fc00 '((q d) (s n) (v4s m)) '((sha1c 0x5e000000) (sha1p 0x5e001000) (sha1m 0x5e002000)))
     (a6t-all 0xffe0fc00 '((q d) (q n) (v4s m)) '((sha256h 0x5e004000) (sha256h2 0x5e005000)))
     (a6t-all 0xffe0fc00 '((v4s d) (v4s n) (v4s m)) '((sha1su0 0x5e003000) (sha256su1 0x5e006000)))
     (a6t-all 0xfffffc00 '((v16b d) (v16b n)) '((aese 0x4e284800) (aesd 0x4e285800) (aesmc 0x4e286800)
                                               (aesimc 0x4e287800)))
     (a6t-all 0xbf20fc00 '((v d) (v n) (v m))
      '((uzp1 0x0e001800) (trn1 0x0e002800) (zip1 0x0e003800) (uzp2 0x0e005800) (trn2 0x0e006800)
        (zip2 0x0e007800)))
     (a6t-all 0xff80f400 '((fs d) (fs n) fel) '((fmla 0x5f801000) (fmls 0x5f805000) (fmul 0x5f809000)))
     (a6t-all 0xbf80f400 '((vf d) (vf n) fel) '((fmla 0x0f801000) (fmls 0x0f805000) (fmul 0x0f809000)))
     [['ld1 0x0d400000 0xbfffe000 '(lane m0)] ['ld1 0x0d404000 0xbfffe400 '(lane m0)]
      ['ld1 0x0d408000 0xbfffec00 '(lane m0)] ['ld1 0x0d408400 0xbffffc00 '(lane m0)]
      ['st1 0x0d000000 0xbfffe000 '(lane m0)] ['st1 0x0d004000 0xbfffe400 '(lane m0)]
      ['st1 0x0d008000 0xbfffec00 '(lane m0)] ['st1 0x0d008400 0xbffffc00 '(lane m0)]
      ['ld1 0x0c407000 0xbffff000 '(list1 m0)] ['st1 0x0c007000 0xbffff000 '(list1 m0)]]])
   a64-byname (foldl (\ t r (pin t <r (peep t <r () + [r]))) {} a64-tab)
   ;; the encoder: a row lays operands written as the decoder's (a6d-op), each kind taking its
   ;; operands from the front and answering [bits taken], or () when they are not its own.
   ;; acc is the word so far, which a later kind reads (the width, a shift's element)
   ;; a bitmask immediate -> N:immr:imms at bits [22:10]: a rotated run of ones repeated over a
   ;; 2..64-bit element. 0, -1 and anything else scare.
   ;; bit tests, never a 64-bit mask: (1 << 63) - 1 leaves fixnum range and & on the big misreads
   (bmbit v k)  (v >> k & 1)
   (bmones v i) ((: (go k) (i + k = 64 || 0 = bmbit v (i + k) ? k (go (k + 1)))) 0)
   (bmctz v)    ((: (go k) (k = 64 || 1 = bmbit v k ? k (go (k + 1)))) 0)
   (bmclo v)    ((: (go k) (k = 64 || 0 = bmbit v (63 - k) ? k (go (k + 1)))) 0)
   (bmrun? v)   (v = 0 ? 0 (: i (bmctz v) n (bmones v i) (i + n = 64 || 0 = v >> (i + n))))
   (bmelem v)   ((: (go e) (e = 2 ? 2 (: h (e // 2) m ((1 << h) - 1)
                                          (v & m = v >> h & m ? (go h) e)))) 64)
   (bitmask-field imm)
      (imm = 0 || imm = -1 ? (scare 'a64-bitmask-imm imm)
         (: e (bmelem imm)
            m (e = 64 ? -1 ((1 << e) - 1))
            v (imm & m)
            r (bmrun? v ? (bmctz v @ i [i (bmones v i)])
                 (: w (v | m ^ -1)                         ; the run wraps the element: ask of its complement
                    (bmrun? (w ^ -1) ?
                       (bmclo w @ c [(64 - c) (c + bmones w 0 - (64 - e))]))))
            (r = () || r 1 = e ? (scare 'a64-bitmask-imm imm)    ; a run filling its element is all ones: reserved
               (: i <r
                  ct <>r
                  immr (e - i & e - 1)
                  nimms ((e - 1 ^ -1) << 1 | ct - 1)    ; the size prefix, then imms = ones-1
                  n (nimms >> 6 & 1 ^ 1)
                  (n << 22 | (immr << 16 | (nimms & 0x3f) << 10))))))
   (a6e-n o) (o 1 = 32 ? 31 (o 1))
   (a6e-at f) (f @ 'd 0 'n 5 'm 16 10)
   (a6e-nth l k) (k < #l ? (l k) 0)
   (a6e-ix l x) ((: (go i) (i = #l ? () (l i = x ? i (go (i + 1))))) 0)
   (a6e-arr a) (a6e-ix a6t-arr a)
   (a6e-reg c f o)
    (: n (a6e-n o) at (a6e-at f) t <o
       (!(two? o && elem t '(x w f v)) ? ()
        (c @ 'r (elem t '(x w) ? ((t = 'x ? 0x80000000 0) | n << at) ())
            'R (elem t '(x w) ? ((t = 'x ? 0x80000000 0) | n << at) ())
            'x (t = 'x ? (n << at) ()) 'X (t = 'x ? (n << at) ()) 'w (t = 'w ? (n << at) ()) 'W (t = 'w ? (n << at) ())
            'f (t = 'f ? ((o 1 @ 's 0 'd 0x400000 'h 0xc00000 -1) @ k (k < 0 ? () (k | o 2 << at))) ())
            'fs (t = 'f && elem (o 1) '(s d) ? ((o 1 = 'd ? 0x400000 0) | o 2 << at) ())
            'v (t = 'v ? (a6e-arr (o 2) @ k (k = () ? () ((k >> 1) << 22 | (k & 1) << 30 | o 1 << at))) ())
            'vn (t = 'v ? (a6e-arr (o 2) @ k (k = () || k > 5 ? () ((k >> 1) << 22 | (k & 1) << 30 | o 1 << at))) ())
            'vb (t = 'v && elem (o 2) ["8b" "16b"] ? ((o 2 = "16b" ? 0x40000000 0) | o 1 << at) ())
            'vw (t = 'v ? (peep {"8h" 0 "4s" 1 "2d" 2} (o 2) -1 @ k (k < 0 ? () (k << 22 | o 1 << at))) ())
            'vf (t = 'v ? (peep {"2s" 0 "4s" 0x40000000 "2d" 0x40400000} (o 2) -1 @ k
                           (k < 0 ? () (k | o 1 << at))) ())
            (t = 'f && o 1 = c ? (o 2 << at) ()))))
   (a6e-op k os acc pc)
    (: o (two? os ? <os ()) t (two? o ? <o ()) v (two? o ? (o 1) 0)
       (one b) (b = () ? () [b 1])
       (is s) (t = s)
       sf (acc >> 31 & 1)
       (? (two? k && elem <k a6t-rcls) (two? o ? (one (a6e-reg <k (k 1) o)) ())
          (k @
           'aimm (is 'im ? (a6e-nth os 1 @ ('sh 'lsl 12) [(v << 10 | 0x400000) 2] _ [(v << 10) 1]) ())
           'bimm (is 'im ? ((trap (_ \ a6e-bimm v sf) 0 (a \ b \ ())) @ b (b = () ? () [b 1])) ())
           'imm16 (is 'im ? (a6e-nth os 1 @ ('sh 'lsl s) [(v << 5 | (s // 16) << 21) 2] _ [(v << 5) 1]) ())
           'immr (is 'dec ? [(v << 16 | sf << 22) 1] ())
           'imms (is 'dec ? [(v << 10) 1] ())
           'lsb (is 'im ? [(v << 10 | sf << 22) 1] ())
           'adr (is 'lbl ? (v - pc @ d [((d & 3) << 29 | (d >> 2 & 0x7ffff) << 5) 1]) ())
           'adrp (is 'lbl ? (v // 4096 - pc // 4096 @ d [((d & 3) << 29 | (d >> 2 & 0x7ffff) << 5) 1]) ())
           'l26 (is 'lbl ? [((v - pc) // 4 & 0x3ffffff) 1] ())
           'l19 (is 'lbl ? [(((v - pc) // 4 & 0x7ffff) << 5) 1] ())
           'l14 (is 'lbl ? [(((v - pc) // 4 & 0x3fff) << 5) 1] ())
           'tr (elem t '(x w) ? [(a6e-n o) 1] ())
           'tbit (is 'im ? [((v >> 5) << 31 | (v & 31) << 19) 1] ())
           'x16 (is 'imx ? [(v << 5) 1] ()) 'u16 (is 'im ? [v 1] ())
           'hint7 (is 'im ? [(v << 5) 1] ())
           'crm (is 'im ? [(v << 8) 1] [(15 << 8) 0])
           'bar (is 'bar ? [(v << 8) 1] ())
           'isbo (is 'bar ? [(v << 8) 1] [(15 << 8) 0])
           'pstate (is 'pst && two? >os && <(os 1) = 'im ? [(v << 16 | o 2 << 5 | os 1 1 << 8) 2] ())
           'sysop (#os >= 5 ? (: r (map (x \ x 1) (snip os 0 4))
                                 [(a6e-num (r 0) << 16 | a6e-num (r 1) << 12 | a6e-num (r 2) << 8
                                   | a6e-num (r 3) << 5 | a6e-n (os 4)) 5]) ())
           'sysl (#os >= 4 ? (: r (map (x \ x 1) (snip os 0 4))
                                [(a6e-num (r 0) << 16 | a6e-num (r 1) << 12 | a6e-num (r 2) << 8
                                  | a6e-num (r 3) << 5) 4]) ())
           'sreg (is 'sys ? [(v << 5) 1] ())
           'prf (is 'prf ? [v 1] ())
           'lsh (is 'sh ? [(a6e-shk (o 1) << 22 | o 2 << 10) 1] [0 0])
           'ash (is 'sh ? [(a6e-shk (o 1) << 22 | o 2 << 10) 1] [0 0])
           'xm (elem t '(x w) ? [(a6e-n o << 16) 1] ())
           'ext (? (is 'ext) [(a6e-extk (o 1) << 13 | o 2 << 10) 1]
                   (is 'sh) [((sf ? 3 2) << 13 | o 2 << 10) 1]
                   [((sf ? 3 2) << 13) 0])
           'cond (is 'cc ? [(v << 12) 1] ()) 'nzcv (is 'im ? [v 1] ()) 'ccimm (is 'im ? [(v << 16) 1] ())
           ('mu s) (is 'mem ? [(v << 5 | (o 2 // s) << 10) 1] ())
           'mo (is 'mem ? [(v << 5 | (o 2 & 511) << 12) 1] ())
           'mpost (is 'post ? [(v << 5 | (o 2 & 511) << 12) 1] ())
           'mpre (is 'pre ? [(v << 5 | (o 2 & 511) << 12) 1] ())
           ('mr s) (is 'memr ? [(v << 5 | a6e-n (o 2) << 16 | (o 3 = 'lsl ? 3 (a6e-extk (o 3))) << 13
                                 | o 5 << 12) 1] ())
           ('mp s) (is 'mem ? [(v << 5 | (o 2 // s & 127) << 15) 1] ())
           ('mpp s) (is 'post ? [(v << 5 | (o 2 // s & 127) << 15) 1] ())
           ('mpr s) (is 'pre ? [(v << 5 | (o 2 // s & 127) << 15) 1] ())
           'm0 (is 'mem ? [(v << 5) 1] ())
           'fz (is 'raw ? [0 1] ()) 'z0 (is 'raw ? [0 1] ())
           'fimm (is 'raw ? (a6e-fimm v @ i (i = () ? () [(i << 13) 1])) ())
           'modi (a6e-modi os acc)
           'shr (is 'im ? (a6e-ish acc @ e (e < 0 ? () [(((16 << e) - v) << 16) 1])) ())
           'shl (is 'im ? (a6e-ish acc @ e (e < 0 ? () [(((8 << e) + v) << 16) 1])) ())
           ('vi f) (is 'v ? (a6e-arr (o 2) @ k (k = () ? () [(8 << (k >> 1) << 16 | (k & 1) << 30 | o 1 << a6e-at f) 1])) ())
           ('vin f) (is 'v ? (a6e-arr (o 2) @ k (k = () ? () [(8 << (k >> 1) << 16 | (k & 1) << 30 | o 1 << a6e-at f) 1])) ())
           ('viw f) (is 'v ? (peep {"8h" 0 "4s" 1 "2d" 2} (o 2) -1 @ e (e < 0 ? () [(8 << e << 16 | o 1 << a6e-at f) 1])) ())
           'fbits (is 'im ? [((64 - v) << 10) 1] ())
           'vsz (is 'f ? (peep {'b 0 'h 1 's 2} (o 1) -1 @ s (s < 0 ? () [(s << 22 | o 2) 1])) ())
           'vszw (is 'f ? (peep {'h 0 's 1 'd 2} (o 1) -1 @ s (s < 0 ? () [(s << 22 | o 2) 1])) ())
           'vpsz (is 'f ? [((o 1 = 'd ? 0x400000 0) | o 2) 1] ())
           'vp (is 'v ? [(o 1 << 5) 1] ())
           'v2d (is 'v ? [(o 1 << 5) 1] ())
           ('v4s f) (is 'v ? [(o 1 << a6e-at f) 1] ()) ('v16b f) (is 'v ? [(o 1 << a6e-at f) 1] ())
           'vd1n (is 'el ? [(o 1 << 5) 1] ()) 'vd1d (is 'el ? [(o 1) 1] ())
           ('v5 f) (is 'v ? (a6e-arr (o 2) @ k (k = () ? () [((1 << (k >> 1)) << 16 | (k & 1) << 30 | o 1 << a6e-at f) 1])) ())
           ('e5 f) (is 'el ? (a6e-ech (o 2) @ e [(((o 3 << (e + 1)) | 1 << e) << 16 | o 1 << a6e-at f) 1]) ())
           'g5 (elem t '(x w) ? [(a6e-n o << 5) 1] ())
           'e4 (is 'el ? (a6e-ech (o 2) @ e [((o 3 << e) << 11 | o 1 << 5) 1]) ())
           's5 (is 'f ? (a6e-ech (o 1) @ e [((1 << e) << 16 | o 2) 1]) ())
           'tlist (is 'list ? [(v << 5 | (o 2 - 1) << 13) 1] ())
           'exti (is 'im ? [(v << 11) 1] ())
           'fel (is 'el ? (: d (o 2 = 'd) i (o 3)
                             [(o 1 << 16 | (d ? 0x400000 0) | (d ? i (i >> 1)) << 11 | (d ? 0 (i & 1)) << 21) 1]) ())
           'lane (is 'list ? (: i (o 4)
                              l (o 3 @ "b" [(i >> 3) (i >> 2 & 1) (i & 3)] "h" [(i >> 2) (i >> 1 & 1) ((i & 1) << 1)]
                                       "s" [(i >> 1) (i & 1) 0] [i 0 1])
                              [(l 0 << 30 | l 1 << 12 | l 2 << 10 | v) 1]) ())
           'list1 (is 'list ? (a6e-arr (o 3) @ k (k = () ? () [((k & 1) << 30 | (k >> 1) << 10 | v) 1])) ())
           ())))
   (a6e-num t) (read (snip t 1 #t))
   (a6e-shk n) (n @ 'lsl 0 'lsr 1 'asr 2 3)
   (a6e-extk n) (a6e-ix a6t-extn n)
   (a6e-ech c) (c @ 'b 0 'h 1 's 2 'd 3 "b" 0 "h" 1 "s" 2 3)
   (a6e-ish acc) (acc >> 19 & 15 @ h (? (h >= 8) 3 (h >= 4) 2 (h >= 2) 1 (h = 1) 0 -1))
   (a6e-fimm t) ((: (go i) (i = 256 ? () (a6t-fimm i = t ? i (go (i + 1))))) 0)
   ;; a logical immediate at the width, as N:immr:imms at bits 22..10; scares when none
   (a6e-bimm v sf) (sf ? (bitmask-field (v >= (63 2) ? (v - (64 2)) v))
                      (: u (v % 4294967296) (bitmask-field (u + u * 4294967296) @ b
                                              (b & 0x400000 ? (scare 'a6e-bimm v) b))))
   (a6e-modi os acc)
    (: o <os rd (<o = 'f ? (o 2) (o 1)) q (elem (o 2) ["16b" "8h" "4s" "2d"] ? 1 0)
       cm (acc >> 12 & 15) i (a6e-nth os 1) s (a6e-nth os 2)
       (lay i8) (q << 30 | (i8 >> 5) << 16 | (i8 & 31) << 5 | rd)
       (? (two? i && <i = 'im)
           (: sh (two? s && <s = 'sh ? (s 2) 0) ms (two? s && <s = 'sh && s 1 = 'msl)
              b (? ms (sh = 16 ? 0x1000 0) (cm >= 8) ((sh // 8) << 13) ((sh // 8) << 13))
              [(lay (i 1) | b) (two? s && <s = 'sh ? 3 2)])
          (two? i && <i = 'raw) (a6e-fimm (i 1) @ i8 (i8 = () ? () [(lay i8) 2]))
          (two? i && <i = 'm64)
           (: v (i 1) i8 (foldl (\ a k (a | (v // ((k * 8) 2) % 256 = 255 ? (1 << k) 0))) 0 ^8)
              [(lay i8) 2])
          ()))
   ;; a row's word from its operands, or (): every kind took its own
   (a64-fit r ops pc)
    (: (go ks os acc)
        (? !(two? ks) (os = () ? acc ())
           (a6e-op <ks os acc pc @ e (e = () ? () (go >ks (snip os (e 1) #os) (acc | <e)))))
       (go (r 3) ops (r 1) @ w (w = () || w & r 2 != r 1 ? () w)))
   ;; the lowering's word, the first row of the name its operands fit: its forms are its own
   (a64-word mn ops)
    (: (go l) (? !(two? l) (scare 'a64-word [mn ops]) (a64-fit <l ops 0 @ w (w = () ? (go >l) w)))
       (go (peep a64-byname mn ()))))

(: ;; r19..r28 are callee-saved. x16 (IP0) is borrowed by the indexed stores, the far-memory lane
   ;; and the 128-bit kit, x17 by the kit: mooncc allocates neither, so a hand-written lay naming
   ;; them must keep clear of those
   a64-regs {'sp 31 'fp 29 'lr 30
             'r0 0 'r1 1 'r2 2 'r3 3  'r4 4
             'r5 5 'r6 6 'r7 7 'r8 8  'r9 9
             'r10 10 'r11 11 'r12 12 'r13 13 'r14 14 'r15 15
             'r16 16 'r17 17 'r18 18
             'r19 19 'r20 20 'r21 21 'r22 22 'r23 23 'r24 24
             'r25 25 'r26 26 'r27 27 'r28 28}

   ;; op -> its table name
   a64-alu {'add 'add 'sub 'sub 'and 'and 'or 'orr 'xor 'eor 'adds 'adds 'subs 'subs}

   (rn r) (look a64-regs r 'badreg)
   (reg-eq a b) (rn a = rn b)       ; a64's own, or x64.l's would read x64 registers

   ;; a word by its row in a64-tab, the operands as decode.l reads them
   (a6o mn ops) (le32 (a64-word mn ops))
   (ax n) ['x n]
   (aw n) ['w n]
   (afd n) ['f 'd n]
   (afs n) ['f 's n]
   (aim v) ['im v]
   (axs l) (map (r \ ax (rn r)) l)
   (a64-hw mn dn v k) (a6o mn [(ax dn) (aim v) ['sh 'lsl (16 * k)]])     ; movz/movn/movk d, v, lsl 16k

   ;; //% and not &/>>: u can be a bignum >= 2^63, where & drops the high limb
   (a64-lane u k) ((u // k 65536) % 65536)                                     ; (k 65536) is 65536^k
   ;; a symbol survives arithmetic, so the immediate is checked a number
   (a64-li d imm)
      (: _ (constellation? imm ? 0 (scare 'badimm imm))
         dn (rn d) u (u64 imm)
         ls (map (a64-lane u) ^4)
         ; movn when more lanes are all ones than zero; movk patches the rest
         neg (#(filter (l \ l != 65535) ls) < #(filter (l \ l != 0) ls))
         skip (neg ? 65535 0)
         i0 (: (go k) (? (k = 4) 0 (ls k != skip) k (go (k + 1))) (go 0))
         (catall ((neg ? (a64-hw 'movn dn (65535 - ls i0) i0) (a64-hw 'movz dn (ls i0) i0))
                  . map (k \ (k != i0 && ls k != skip ? (a64-hw 'movk dn (ls k) k) ())) ^4)))

   ;; mov is ORR from xzr, where 31 reads as xzr, so a move to or from sp lays add #0
   (a64-mov d s) (: dn (rn d) sn (rn s)
      (? (elem 'zr [d s] && elem 'sp [d s]) (scare 'a64-mov-sp [d s])
         (d = 'sp || s = 'sp) (a6o 'add [(ax dn) (ax sn) (aim 0)])
         (a6o 'orr [(ax dn) (ax 31) (ax sn)])))

   ;; the shifted-register form reads 31 as xzr in every slot, so sp scares: move sp with lea
   ;; and do the arithmetic in a plain register
   (alu-rrr mn d a b) (: dn (rn d) an (rn a) bn (rn b)
      (dn = 31 || an = 31 || bn = 31 ? (scare 'a64-alu-sp [d a b]) 0,
       a6o mn [(ax dn) (ax an) (ax bn)]))
   (alu-rri mn d a imm) (a6o mn [(ax (rn d)) (ax (rn a)) (aim imm)])
   ;; imm12, or up to 24 bits as the LSL #12 form plus the low tail (add/sub only: a split S-form
   ;; would leave the tail's flags)
   (a64-addsub-imm op d a imm)
      (: pos  (imm < 0 ? (0 - imm) imm)
         fop  (imm < 0 ? (? (op = 'add) 'sub (op = 'sub) 'add (op = 'adds) 'subs 'adds) op)
         mn   (peep a64-alu fop 0)
         (? (pos <= 4095) (alu-rri mn d a pos)
            (pos <= 16777215 && elem fop '(add sub))
             (catall [(a6o mn [(ax (rn d)) (ax (rn a)) (aim (pos >> 12)) ['sh 'lsl 12]])
                       (pos % 4096 = 0 ? () (alu-rri mn d d (pos % 4096)))])
            (scare 'imm12-range imm)))
   ;; bitmask-field scares an immediate no mask lays
   (a64-logical-imm op d a b) (: _ (bitmask-field b) (alu-rri (peep a64-alu op 0) d a b))
   (a64-aluop op d a b)
      (? (reg? b)                  (alu-rrr (peep a64-alu op 0) d a b)
         (elem op '(and or xor))   (a64-logical-imm op d a b)
         (a64-addsub-imm op d a b))

   (a64-cmp a b)                                            ; subs xzr, a, b; cmn for a negative imm
      (rn a @ an
         (reg? b ? (a6o 'subs [(ax 31) (ax an) (ax (rn b))])
            (: pos (b < 0 ? (0 - b) b) mn (b < 0 ? 'adds 'subs)
               (? (pos <= 4095) (a6o mn [(ax 31) (ax an) (aim pos)])
                  (pos % 4096 = 0 && pos >> 12 <= 4095) (a6o mn [(ax 31) (ax an) (aim (pos >> 12)) ['sh 'lsl 12]])
                  (a64-li 'r17 b + a64-cmp a 'r17)))))                      ; past imm12, through x17

   (a64-mulh d a b) (a6o 'smulh (axs [d a b]))
   (a64-umulh d a b) (a6o 'umulh (axs [d a b]))
   (a64-imul d a b)                                         ; madd d, a, b, xzr
      (reg? b ? (a6o 'madd (axs [d a b] + [(ax 31)]))
         (scare 'a64-mul-imm ['imul d a b]))

   ;; past imm12 and imm9: x16 = bn +- |off|, then op Rt, [x16, #0]
   (a64-far umn rt bn off)
      (: u (off < 0 ? (0 - off) off)
         l0 (u % 65536) l1 (u // 65536)
         ai (off < 0 ? 'sub 'add)                          ; the immediate form, where Rn=31 reads SP
         hi (u >> 12) lo (u % 4096)
         (bn = 16 ? (scare 'far-base-x16 off) 0,
          u <= 16777215 ?
            (catall [
              (hi = 0 ? () (a6o ai [(ax 16) (ax bn) (aim hi) ['sh 'lsl 12]]))
              (lo = 0 ? () (a6o ai [(ax 16) (ax (hi = 0 ? bn 16)) (aim lo)]))
              (a6o umn [rt ['mem 16 0]])])
            (u < 4294967296 ? 0 (scare 'mem-range off),
             bn = 31 ? (scare 'far-base-sp off) 0,       ; shifted-reg add reads Rn=31 as XZR, not SP
             catall [
              (a64-hw 'movz 16 l0 0)
              (l1 = 0 ? () (a64-hw 'movk 16 l1 1))
              (a6o ai [(ax 16) (ax bn) (ax 16)])
              (a6o umn [rt ['mem 16 0]])])))
   ;; every load/store: LDR/STR imm12 in units of sc, else LDUR/STUR imm9, else far. rt the
   ;; register operand
   (a64-mem-raw lmn umn sc rt bn off)
      (charm? off ? 0 (scare 'mem-disp off),
       0 = off % sc && off >= 0 && off // sc <= 4095 ?
         (a6o umn [rt ['mem bn off]])
         (off >= -256 && off <= 255 ?
            (a6o lmn [rt ['mem bn off]])
            (a64-far umn rt bn off)))
   (a64-mem-sz lmn umn sc c d base off) (a64-mem-raw lmn umn sc (c (rn d)) (rn base) off)
   (a64-ld d base off)  (a64-mem-sz 'ldur 'ldr 8 ax d base off)
   (a64-st base off s)  (a64-mem-sz 'stur 'str 8 ax s base off)
   (a64-ld1 d base off) (a64-mem-sz 'ldursb 'ldrsb 1 ax d base off)
   (a64-ld2 d base off) (a64-mem-sz 'ldursh 'ldrsh 2 ax d base off)
   (a64-ld4 d base off) (a64-mem-sz 'ldursw 'ldrsw 4 ax d base off)
   (a64-ldu1 d base off) (a64-mem-sz 'ldurb 'ldrb 1 aw d base off)
   (a64-ldu2 d base off) (a64-mem-sz 'ldurh 'ldrh 2 aw d base off)
   (a64-ldu4 d base off) (a64-mem-sz 'ldur 'ldr 4 aw d base off)
   (a64-st1 base off s) (a64-mem-sz 'sturb 'strb 1 aw s base off)
   (a64-st2 base off s) (a64-mem-sz 'sturh 'strh 2 aw s base off)
   (a64-st4 base off s) (a64-mem-sz 'stur 'str 4 aw s base off)
   (a64-sx w d) (a64-sxs w d d)
   (a64-sxs w d s) (a6o 'sbfm (axs [d s] + [['dec 0] ['dec (8 * w - 1)]]))    ; sxtb/sxth/sxtw Xd, Ws
   (a64-zx w d) (a64-zxs w d d)
   (a64-zxs w d s) (a6o 'ubfm (axs [d s] + [['dec 0] ['dec (8 * w - 1)]]))    ; uxtb/uxth Xd, Xs (w=4 clears bits 32..63)
   (a64-shiftv op d c)                                      ; the IR pins the count to r1
      (: _ (reg-eq c 'r1 ? 0 (scare 'shiftv-count-not-r1 [op d c]))
         _ (reg-eq d 'r1 ? (scare 'shiftv-dst-is-r1 [op d c]) 0)
         dn (rn d) cn (rn c)
         mn (? (op = 'shlv) 'lslv (op = 'shrv) 'lsrv (op = 'sarv) 'asrv 'rorv)
         r (op = 'rorv4 ? aw ax)                            ; rorv4: the W form, count mod 32
         (a6o mn [(r dn) (r dn) (r cn)]))
   (a64-lea d base off)  (a64-addsub-imm 'add d base off)

   (a64-push s) (a6o 'str [(ax (rn s)) ['pre 31 -16]])
   (a64-pop  d) (a6o 'ldr [(ax (rn d)) ['post 31 16]])
   ;; the frame record: fp at [sp], lr at [sp+8], in the 32 bytes of two pushes
   a64-frpush (a6o 'stp [(ax 29) (ax 30) ['pre 31 -32]])
   a64-frpop  (a6o 'ldp [(ax 29) (ax 30) ['post 31 32]])

   (a64-neg d) (rn d @ dt (a6o 'sub [(ax dt) (ax 31) (ax dt)]))
   (a64-not d) (a64-mvn d d)
   (a64-mvn d s) (a6o 'orn [(ax (rn d)) (ax 31) (ax (rn s))])
   (a64-inc d) (a64-addsub-imm 'add d d 1)
   (a64-dec d) (a64-addsub-imm 'sub d d 1)
   (a64-decm base off) (a64-ld 'r17 base off + a64-addsub-imm 'subs 'r17 'r17 1 + a64-st base off 'r17)   ; [base+off] -= 1 through x17, the flags set

   ;; a fix's base word: its row laid against a target at the site, the field left 0
   (a64-fw mn ops) (a64-word mn (ops + [['lbl 0]]))
   (a64-jmp  label)    [(fix 4 'b26 label (a64-fw 'b ()))]
   (a64-cbr w r label) [(fix 4 'b19 label (w | rn r))]   ; cbz/cbnz, X or W by the word
   (a64-tbr w r label) [(fix 4 'b14 label (w | rn r))]   ; tbz/tbnz, the bit and the op in the word
   (a64-afix k w label ad) [(fix 4 k label (w | (ad & 4294967295) << 32))]   ; adrp, :lo12:, the addend aboard
   (a64-call label)    [(fix 4 'b26 label (a64-fw 'bl ()))]
   ;; la: adrp + add (+-4GB), the pair ELF relocates as PG_HI21 + ABS_LO12_NC
   (a64-la d label)    (rn d @ dn
                          [(fix 4 'adrp21 label (a64-fw 'adrp [(ax dn)]))
                            (fix 4 'addlo12 label (a64-word 'add [(ax dn) (ax dn) (aim 0)]))])
   ;; lar: adr, byte pc-relative (+-1MB), right at any load address -- adrp is right only when
   ;; the image loads page-aligned, which a code blob in a runtime mapping is not
   (a64-lar d label)   [(fix 4 'adr21 label (a64-fw 'adr [(ax (rn d))]))]
   ;; lia: the linked address, not where the pc runs -- for a kernel linked high that runs low
   ;; until the MMU is on. an inline literal word: ldr xd, .+8 ; b .+12 ; .quad label.
   ;; put an ('align 8) before it: an unaligned literal faults on Device memory, as before the MMU
   (a64-lia d label)   (a6o 'ldr [(ax (rn d)) ['lbl 8]] + a6o 'b [['lbl 12]] + [(fix 8 'abs64 label 0)])
   (a64-br cond label) (look arm-cc cond 'badcc @ cc
                          [(fix 4 'b19 label (a64-fw (name ("b." + show (a6t-cc cc))) ()))])
   (a64-jmpr d) (a6o 'br [(ax (rn d))])
   ;; the table and its targets are for the analyses, not the machine
   (a64-jmpt d tl labs) (a64-jmpr d)
   (a64-callr d) (a6o 'blr [(ax (rn d))])
   ;; branch to lbl on signed overflow: smulh must equal the low half's sign fill. t must
   ;; differ from a, b and d
   (a64-mulo d a b t lbl)
      (catall [(a6o 'smulh (axs [t a b]))
               (a6o 'madd (axs [d a b] + [(ax 31)]))
               (a6o 'subs [(ax 31) (ax (rn t)) (ax (rn d)) ['sh 'asr 63]])
               [(fix 4 'b19 lbl (a64-fw 'b.ne ()))]])
   ;; cset = csinc Xd, xzr, xzr, cc^1 (cc^1 inverts)
   (a64-set cond d) (look arm-cc cond 'badcc @ cc (a6o 'csinc [(ax (rn d)) (ax 31) (ax 31) ['cc (cc ^ 1)]]))
   ;; lsl/lsr are ubfm, asr sbfm, ror extr Xd,Xn,Xn,#c, rol #c ror #(64-c).
   ;; a64-shs is the three-address form (the lsl/lsr/asr rows)
   (a64-shs op d s c) (a64-wshi op (rn d) (rn s) c)
   (a64-shift op d c)
      (rn d @ dn
         (? (elem op '(shl shr sar)) (a64-shs op d d c)
            (op = 'ror) (a64-wextr dn dn dn c)
            (op = 'rol) (a64-wextr dn dn dn (64 - c & 63))
            (op = 'ror4) (a6o 'extr [(aw dn) (aw dn) (aw dn) (aim c)])                ; the W form, zero-extending
            (scare 'badshift op)))
   ;; tst = ands xzr, a, b; b a register or a bitmask immediate
   (a64-test a b)
      (reg? b ? (a6o 'ands [(ax 31) (ax (rn a)) (ax (rn b))])
         (: _ (bitmask-field b) (a6o 'ands [(ax 31) (ax (rn a)) (aim b)])))
   ;; rem = a - (a/b)*b by msub through t, which must differ from a and b
   (a64-div d a b)   (a6o 'sdiv (axs [d a b]))
   (a64-rem d a b t) (a6o 'sdiv (axs [t a b]) + a6o 'msub (axs [d t b a]))
   (a64-udiv d a b)  (a6o 'udiv (axs [d a b]))
   (a64-urem d a b t) (a6o 'udiv (axs [t a b]) + a6o 'msub (axs [d t b a]))
   ;; the 128-bit kit: a value is x2:x0 (hi:lo), a binop's left in a 16-byte cell at [sp] or, for
   ;; the r-twins, two registers. one IR form each, so no pass parts a carry pair. x16/x17 scratch
   a64-wldp (a6o 'ldp [(ax 16) (ax 17) ['mem 31 0]])                          ; ldp x16, x17, [sp]: left lo, hi
   (a64-w3 mn d n m)      (a6o mn [(ax d) (ax n) (ax m)])                   ; op Xd, Xn, Xm
   (a64-w4 mn d n m a)    (a6o mn [(ax d) (ax n) (ax m) (ax a)])            ; madd/msub Xd, Xn, Xm, Xa
   (a64-mul d n m)        (a64-w4 'madd d n m 31)
   (a64-wextr d n m c)    (a6o 'extr [(ax d) (ax n) (ax m) (aim c)])
   (a64-wsel d n m cond)  (look arm-cc cond 'badcc @ cc (a6o 'csel [(ax d) (ax n) (ax m) ['cc cc]]))
   (a64-wmov d m)         (a64-w3 'orr d 31 m)                              ; mov Xd, Xm
   (a64-wshi op d n c)                                                        ; lsl/lsr/asr Xd, Xn, #c
      (? (op = 'shl) (a6o 'ubfm [(ax d) (ax n) ['dec (64 - c & 63)] ['dec (63 - c)]])
         (op = 'shr) (a6o 'ubfm [(ax d) (ax n) ['dec c] ['dec 63]])
         (a6o 'sbfm [(ax d) (ax n) ['dec c] ['dec 63]]))
   (a64-a128 sp9) (a64-wldp + (a64-w3 'adds 0 0 16 + a64-w3 'adc 2 2 17))    ; adds x0,x0,x16; adc x2,x2,x17
   (a64-s128 sp9) (a64-wldp + (a64-w3 'subs 0 16 0 + a64-w3 'sbc 2 17 2))    ; subs x0,x16,x0; sbc x2,x17,x2
   (a64-mw128 sp9) (a6o 'ldr [(ax 16) ['mem 31 0]]                           ; ldr x16,[sp]: the low word alone
                      + (a64-w3 'umulh 2 0 16 + a64-mul 0 0 16))   ; umulh x2,x0,x16; mul x0,x0,x16
   (a64-m128 sp9)                                                             ; low 128 of the product: the cross terms onto the widening one
      (a64-wldp + (a64-mul 17 17 0                                ; mul   x17, x17, x0        Lhi*Rlo
       + (a64-w4 'madd 17 16 2 17                                        ; madd  x17, x16, x2, x17    + Llo*Rhi
       + (a64-w3 'umulh 2 16 0                                            ; umulh x2, x16, x0
       + (a64-w3 'add 2 2 17 + a64-mul 0 16 0)))))          ; add x2,x2,x17; mul x0,x16,x0
   ;; 0/1 <- (LEFT cond RIGHT). eq/ne fold the halves by eor; the ordered ones read the borrow
   ;; chain's flags, gt/above/le/be with the subtraction reversed
   (a64-w128cc cond chain rsub zch)
      (? (elem cond '(eq ne))       (zch + a64-set cond 'r0)
         (elem cond '(lt below ge ae)) (chain + a64-set cond 'r0)
         (cond = 'gt)    (rsub + a64-set 'lt 'r0)
         (cond = 'above) (rsub + a64-set 'below 'r0)
         (cond = 'le)    (rsub + a64-set 'ge 'r0)
         (cond = 'be)    (rsub + a64-set 'ae 'r0)
         (scare 'badcc128 cond))
   (a64-c128 cond sp9)
      (a64-wldp + a64-w128cc cond
         (a64-cmp 'r16 'r0 + a64-w3 'sbcs 31 17 2)                     ; cmp x16,x0; sbcs xzr,x17,x2   (L-R)
         (a64-cmp 'r0 'r16 + a64-w3 'sbcs 31 2 17)                     ; cmp x0,x16; sbcs xzr,x2,x17   (R-L)
         (a64-w3 'eor 16 16 0 + (a64-w3 'eor 17 17 2            ; eor x16,x16,x0; eor x17,x17,x2
          + (a64-w3 'orr 16 16 17 + a64-cmp 'r16 0))))                ; orr x16,x16,x17; cmp x16,#0
   ;; u128 in the cell / u64 in x0: the high half by udiv/msub, the low by 64 restoring steps; the
   ;; cell parks the high quotient. ccmp folds the doubling's carry-out into the compare, for a
   ;; divisor past 2^63. a zero divisor does not trap: high quotient 0, low all ones
   a64-divloop
      (a6o 'ands [(ax 31) (ax 17) (aim (63 2))] + (a64-wextr 17 17 16 63 + (a64-wshi 'shl 16 16 1   ; tst x17,#1<<63; extr x17,x17,x16,#63; lsl x16,x16,#1
       + (a6o 'ccmp [(ax 17) (ax 0) (aim 2) ['cc 0]] + (a64-w3 'sub 2 17 0      ; ccmp x17,x0,#2,eq (C on a carry-out); sub x2,x17,x0
       + (a64-wsel 17 2 17 'ae + (a6o 'csinc [(ax 16) (ax 16) (ax 16) ['cc 3]]   ; csel x17,x2,x17,hs; cinc x16,x16,hs
       + (a6o 'subs [(ax 1) (ax 1) (aim 1)] + a6o 'b.ne [['lbl -32]]))))))))    ; subs x1,x1,#1; b.ne -8
   a64-divpre
      (a64-wldp + (a64-w3 'udiv 2 17 0 + (a64-w4 'msub 17 2 0 17              ; udiv x2,x17,x0; msub x17,x2,x0,x17
       + (a6o 'str [(ax 2) ['mem 31 0]] + (a64-hw 'movz 1 64 0 + a64-divloop)))))   ; str x2,[sp]; mov x1,#64
   (a64-dv128 sp9) (a64-divpre + (a64-wmov 0 16 + a6o 'ldr [(ax 2) ['mem 31 0]]))
   (a64-rm128 sp9) (a64-divpre + (a64-wmov 0 17 + a64-wmov 2 31))       ; rem < d: high half 0
   ;; by a constant: extr is the funnel; from 64 the halves move. c = 0 lays nothing (extr has no #64)
   (a64-shl128 c)
      (? (c = 0) ()
         (c < 64) (a64-wextr 2 2 0 (64 - c) + a64-wshi 'shl 0 0 c)  ; extr x2,x2,x0,#64-c; lsl x0,x0,#c
         (a64-wshi 'shl 2 0 (c - 64) + a64-wmov 0 31))                      ; lsl x2,x0,#c-64; x0 = 0
   (a64-shr128 c)
      (? (c = 0) ()
         (c < 64) (a64-wextr 0 2 0 c + a64-wshi 'shr 2 2 c)         ; extr x0,x2,x0,#c; lsr x2,x2,#c
         (a64-wshi 'shr 0 2 (c - 64) + a64-wmov 2 31))                      ; lsr x0,x2,#c-64; x2 = 0
   (a64-sar128 c)
      (? (c = 0) ()
         (c < 64) (a64-wextr 0 2 0 c + a64-wshi 'sar 2 2 c)         ; extr x0,x2,x0,#c; asr x2,x2,#c
         (a64-wshi 'sar 0 2 (c - 64) + a64-wshi 'sar 2 2 63))               ; asr x0,x2,#c-64; the sign flood
   ;; by x1 (0..127): a shift reads its count mod 64, so both bands compute and csel hs picks.
   ;; c = 0 is guarded: the co-shift by 64-c would be by 0 and keep the whole word
   a64-shl128v
      (a64-w3 'sub 16 31 1                                              ; neg  x16, x1        (= 64-c mod 64)
       + (a64-w3 'lsrv 16 0 16                                           ; lsr  x16, x0, x16
       + (a64-w3 'lslv 17 2 1                                            ; lsl  x17, x2, x1
       + (a64-w3 'orr 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 2 17 'eq                             ; c = 0: the high half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 'lslv 16 0 16      ; sub x16,x1,#64; lsl x16,x0,x16
       + (a64-cmp 'r1 64 + (a64-wsel 2 16 17 'ae                            ; csel x2, x16, x17, hs
       + (a64-w3 'lslv 0 0 1 + a64-wsel 0 31 0 'ae)))))))))))           ; lsl x0,x0,x1; csel x0,xzr,x0,hs
   a64-shr128v
      (a64-w3 'sub 16 31 1                                              ; neg  x16, x1
       + (a64-w3 'lslv 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 'lsrv 17 0 1                                            ; lsr  x17, x0, x1
       + (a64-w3 'orr 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq                             ; c = 0: the low half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 'lsrv 16 2 16      ; sub x16,x1,#64; lsr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae                            ; csel x0, x16, x17, hs
       + (a64-w3 'lsrv 2 2 1 + a64-wsel 2 31 2 'ae)))))))))))           ; lsr x2,x2,x1; csel x2,xzr,x2,hs
   a64-sar128v
      (a64-w3 'sub 16 31 1                                              ; neg  x16, x1
       + (a64-w3 'lslv 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 'lsrv 17 0 1                                            ; lsr  x17, x0, x1
       + (a64-w3 'orr 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 'asrv 16 2 16      ; sub x16,x1,#64; asr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae
       + (a64-wshi 'sar 17 2 63 + (a64-w3 'asrv 2 2 1                  ; the sign flood, then asr x2,x2,x1
       + a64-wsel 2 17 2 'ae))))))))))))                                       ; csel x2, x17, x2, hs
   ;; the r-twins: the left in rl:rh (lo, hi), left untouched; the answer in x2:x0
   (a64-a128r rl rh) (: l (rn rl) h (charm? rh ? 31 (rn rh))                ; a number rh: xzr
      (a64-w3 'adds 0 0 l + a64-w3 'adc 2 2 h))                  ; adds x0,x0,rl; adc x2,x2,rh
   (a64-s128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 'subs 0 l 0 + a64-w3 'sbc 2 h 2))                  ; subs x0,rl,x0; sbc x2,rh,x2
   (a64-mw128r rl) (rn rl @ l
                      (a64-w3 'umulh 2 0 l + a64-mul 0 0 l))                  ; umulh x2,x0,rl; mul x0,x0,rl
   (a64-m128r rl rh) (: l (rn rl) h (rn rh)
      (a64-mul 16 h 0                                               ; mul   x16, rh, x0        Lhi*Rlo
       + (a64-w4 'madd 16 l 2 16                                         ; madd  x16, rl, x2, x16    + Llo*Rhi
       + (a64-w3 'umulh 2 l 0                                             ; umulh x2, rl, x0
       + (a64-w3 'add 2 2 16 + a64-mul 0 l 0)))))           ; add x2,x2,x16; mul x0,rl,x0
   (a64-c128r cond rl rh) (: l (rn rl) h (rn rh)
      (a64-w128cc cond
         (a64-cmp rl 'r0 + a64-w3 'sbcs 31 h 2)                        ; cmp rl,x0; sbcs xzr,rh,x2
         (a64-cmp 'r0 rl + a64-w3 'sbcs 31 2 h)                        ; cmp x0,rl; sbcs xzr,x2,rh
         (a64-w3 'eor 16 l 0 + (a64-w3 'eor 17 h 2
          + (a64-w3 'orr 16 16 17 + a64-cmp 'r16 0)))))
   a64-sx128  (a64-wshi 'sar 2 0 63)                                        ; asr x2, x0, #63
   a64-n128   (a64-w3 'subs 0 31 0 + a64-w3 'sbc 2 31 2)       ; negs x0,x0; ngc x2,x2
   a64-inc128 (a64-addsub-imm 'adds 'r0 'r0 1 + a64-w3 'adc 2 2 31) ; adds x0,x0,#1; adc x2,x2,xzr
   a64-dec128 (a64-addsub-imm 'subs 'r0 'r0 1 + a64-w3 'sbc 2 2 31) ; subs x0,x0,#1; sbc x2,x2,xzr

   ;; base + ix*scale by add lsl, in the dest for loads and leax, in x16 for stores
   (a64-shiftamt scale) (? (scale = 1) 0 (scale = 2) 1 (scale = 4) 2 (scale = 8) 3 (scare 'badscale scale))
   (a64-addsh dn bn ixn amt) (a6o 'add [(ax dn) (ax bn) (ax ixn) ['sh 'lsl amt]])   ; add Xdn, Xbn, Xixn, lsl #amt
   ;; or one word, [Xn, Xm, LSL #s]: no displacement, scale 1 or the element size (S = 1)
   (a64-norof _) (getenv "MOON_ABLATE" @ s (string? s && (s = "rof" || s = "fsel,rof")))
   (a64-rof? scale disp sz) (disp = 0 && (scale = 1 || scale = sz) && !(a64-norof 0))
   (a64-rofs mn rt bn ixn s) (a6o mn [rt ['memr bn (ax ixn) 'lsl 0 s]])
   (a64-ldx d base index scale disp)
      (a64-rof? scale disp 8 ? (a64-rofs 'ldr (ax (rn d)) (rn base) (rn index) (scale = 8 ? 1 0))   ; ldr Xd, [base, index, lsl #3]
         (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (a64-ld d d disp)])))
   (a64-leax d base index scale disp)
      (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (disp = 0 ? () (a64-addsub-imm 'add d d disp))]))
   (a64-stx base index scale disp s)
      (a64-rof? scale disp 8 ? (a64-rofs 'str (ax (rn s)) (rn base) (rn index) (scale = 8 ? 1 0))   ; str Xs, [base, index, lsl #3]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))
                  (a64-mem-raw 'stur 'str 8 (ax (rn s)) 16 disp)]))
   ;; the fp forms: c the register's class, sz its bytes
   (a64-fxld c sz d base index scale disp)
      (a64-rof? scale disp sz ? (a64-rofs 'ldr (c (frn d)) (rn base) (rn index) (scale = sz ? 1 0))  ; ldr Dd/Sd, [base, index, lsl]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 'ldur 'ldr sz (c (frn d)) 16 disp)]))
   (a64-fxst c sz base index scale disp s)
      (a64-rof? scale disp sz ? (a64-rofs 'str (c (frn s)) (rn base) (rn index) (scale = sz ? 1 0))  ; str Ds/Ss, [base, index, lsl]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 'stur 'str sz (c (frn s)) 16 disp)]))
   (a64-fldx d base index scale disp) (a64-fxld afd 8 d base index scale disp)
   (a64-fstx base index scale disp s) (a64-fxst afd 8 base index scale disp s)
   (a64-fldsx d base index scale disp) (a64-fxld afs 4 d base index scale disp)
   (a64-fstsx base index scale disp s) (a64-fxst afs 4 base index scale disp s)
   ;; csel Xd, Xs, Xd, cond; d = s scares
   (a64-cmov cond d s) (: dn (rn d) sn (rn s) (dn = sn ? (scare 'cmov-alias d) (a64-wsel dn sn dn cond)))
   (a64-ldxb d base index scale disp)
      (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale))
                          (a64-mem-raw 'ldurb 'ldrb 1 (aw dn) dn disp)]))              ; ldrb/ldurb Wd, [Xd, #disp]
   (a64-ldxh d base index scale disp)
      (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale))
                          (a64-mem-raw 'ldurh 'ldrh 2 (aw dn) dn disp)]))              ; ldrh/ldurh Wd, [Xd, #disp]
   (a64-stxb base index scale disp s)
      (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))
                (a64-mem-raw 'sturb 'strb 1 (aw (rn s)) 16 disp)])                    ; strb/sturb Ws, [x16, #disp]

   ;; fp: fN is vN. the two-address IR repeats d as the first source
   a64-fregs (fregs 32)
   (frn r) (look a64-fregs r 'badfreg)
   a64-fp3 {'addsd 'fadd 'subsd 'fsub 'mulsd 'fmul 'divsd 'fdiv
            'addss 'fadd 'subss 'fsub 'mulss 'fmul 'divss 'fdiv}
   (a64-fp3op op d s)                                                                    ; Dd = Dd OP Ds
      (: dn (frn d) sn (frn s) c (elem op '(addsd subsd mulsd divsd) ? afd afs)
         (a6o (peep a64-fp3 op 0) [(c dn) (c dn) (c sn)]))
   (a64-f2 mn c1 c2 a b) (a6o mn [(c1 a) (c2 b)])
   (a64-fmov  d s) (a64-f2 'fmov afd afd (frn d) (frn s))
   (a64-fcmp  a b) (a64-f2 'fcmp afd afd (frn a) (frn b))      ; unordered sets V
   (a64-fcmps a b) (a64-f2 'fcmp afs afs (frn a) (frn b))
   (a64-scvtf d g) (a64-f2 'scvtf afd ax (frn d) (rn g))
   (a64-fcvtzs g d) (a64-f2 'fcvtzs ax afd (rn g) (frn d))
   (a64-fmovxr d g) (a64-f2 'fmov afd ax (frn d) (rn g))
   (a64-fmovrx g d) (a64-f2 'fmov ax afd (rn g) (frn d))
   (a64-scvtfs d g) (a64-f2 'scvtf afs ax (frn d) (rn g))
   (a64-fcvtzss g d) (a64-f2 'fcvtzs ax afs (rn g) (frn d))
   (a64-fmovsw d g) (a64-f2 'fmov afs aw (frn d) (rn g))
   (a64-fmovws g d) (a64-f2 'fmov aw afs (rn g) (frn d))
   (a64-fst base disp s) (a64-mem-raw 'stur 'str 8 (afd (frn s)) (rn base) disp)
   (a64-fld d base disp) (a64-mem-raw 'ldur 'ldr 8 (afd (frn d)) (rn base) disp)
   (a64-fcvt-widen  d s) (a64-f2 'fcvt afd afs (frn d) (frn s))
   (a64-fcvt-narrow d s) (a64-f2 'fcvt afs afd (frn d) (frn s))
   (a64-fsts base disp s) (a64-mem-raw 'stur 'str 4 (afs (frn s)) (rn base) disp)
   (a64-flds d base disp) (a64-mem-raw 'ldur 'ldr 4 (afs (frn d)) (rn base) disp)
   (a64-xorpd d s) (: dn (frn d) sn (frn s) (a6o 'eor [['v dn "8b"] ['v dn "8b"] ['v sn "8b"]]))   ; eor Vd.8B, Vd.8B, Vs.8B

   ;; the system lane, for kernels. MRS/MSR and tlbi/ic/dc/at share one encoding: head 1101010100,
   ;; L (1 = read), and the selector op0:op1:crn:crm:op2 at [20:5] -- op0 2 or 3 a register, 1 a sys op
   (sreg o0 o1 cn cm o2) (o0 << 19 | (o1 << 16 | (cn << 12 | (cm << 8 | o2 << 5))))
   a64-sysregs {'sctlr_el1 (sreg 3 0 1 0 0) 'cpacr_el1 (sreg 3 0 1 0 2)
                'ttbr0_el1 (sreg 3 0 2 0 0) 'ttbr1_el1 (sreg 3 0 2 0 1)
                'tcr_el1 (sreg 3 0 2 0 2)
                'spsr_el1 (sreg 3 0 4 0 0) 'elr_el1 (sreg 3 0 4 0 1)
                'currentel (sreg 3 0 4 2 2)
                'esr_el1 (sreg 3 0 5 2 0) 'far_el1 (sreg 3 0 6 0 0)
                'par_el1 (sreg 3 0 7 4 0) 'mair_el1 (sreg 3 0 10 2 0)
                'vbar_el1 (sreg 3 0 12 0 0) 'mpidr_el1 (sreg 3 0 0 0 5)
                'ctr_el0 (sreg 3 3 0 0 1)
                'cntfrq_el0 (sreg 3 3 14 0 0) 'cntpct_el0 (sreg 3 3 14 0 1)
                'cntp_tval_el0 (sreg 3 3 14 2 0) 'cntp_ctl_el0 (sreg 3 3 14 2 1)
                'sp_el0 (sreg 3 0 4 1 0) 'sp_el1 (sreg 3 4 4 1 0) 'spsel (sreg 3 0 4 2 0)
                'daif (sreg 3 3 4 2 1) 'nzcv (sreg 3 3 4 2 0) 'fpcr (sreg 3 3 4 4 0) 'fpsr (sreg 3 3 4 4 1)
                'pan (sreg 3 0 4 2 3) 'uao (sreg 3 0 4 2 4) 'dit (sreg 3 3 4 2 5) 'ssbs (sreg 3 3 4 2 6)
                'tco (sreg 3 3 4 2 7) 'tpidr_el0 (sreg 3 3 13 0 2) 'tpidrro_el0 (sreg 3 3 13 0 3)
                'tpidr_el1 (sreg 3 0 13 0 4) 'tpidr_el2 (sreg 3 4 13 0 2) 'contextidr_el1 (sreg 3 0 13 0 1)
                'midr_el1 (sreg 3 0 0 0 0) 'revidr_el1 (sreg 3 0 0 0 6) 'id_aa64pfr0_el1 (sreg 3 0 0 4 0)
                'id_aa64pfr1_el1 (sreg 3 0 0 4 1) 'id_aa64zfr0_el1 (sreg 3 0 0 4 4)
                'id_aa64smfr0_el1 (sreg 3 0 0 4 5) 'id_aa64dfr0_el1 (sreg 3 0 0 5 0)
                'id_aa64dfr1_el1 (sreg 3 0 0 5 1) 'id_aa64isar0_el1 (sreg 3 0 0 6 0)
                'id_aa64isar1_el1 (sreg 3 0 0 6 1) 'id_aa64isar2_el1 (sreg 3 0 0 6 2)
                'id_aa64mmfr0_el1 (sreg 3 0 0 7 0) 'id_aa64mmfr1_el1 (sreg 3 0 0 7 1)
                'id_aa64mmfr2_el1 (sreg 3 0 0 7 2) 'id_aa64mmfr3_el1 (sreg 3 0 0 7 3)
                'ccsidr_el1 (sreg 3 1 0 0 0) 'clidr_el1 (sreg 3 1 0 0 1) 'csselr_el1 (sreg 3 2 0 0 0)
                'dczid_el0 (sreg 3 3 0 0 7) 'cntvct_el0 (sreg 3 3 14 0 2) 'cntkctl_el1 (sreg 3 0 14 1 0)
                'cntp_cval_el0 (sreg 3 3 14 2 2) 'cntv_tval_el0 (sreg 3 3 14 3 0)
                'cntv_ctl_el0 (sreg 3 3 14 3 1) 'cntv_cval_el0 (sreg 3 3 14 3 2)
                'cntvoff_el2 (sreg 3 4 14 0 3) 'cnthctl_el2 (sreg 3 4 14 1 0) 'mdscr_el1 (sreg 2 0 0 2 2)
                'oslar_el1 (sreg 2 0 1 0 4) 'osdlr_el1 (sreg 2 0 1 3 4) 'mdccsr_el0 (sreg 2 3 0 1 0)
                'pmcr_el0 (sreg 3 3 9 12 0) 'pmuserenr_el0 (sreg 3 3 9 14 0) 'afsr0_el1 (sreg 3 0 5 1 0)
                'afsr1_el1 (sreg 3 0 5 1 1) 'amair_el1 (sreg 3 0 10 3 0) 'disr_el1 (sreg 3 0 12 1 1)
                'zcr_el1 (sreg 3 0 1 2 0) 'rgsr_el1 (sreg 3 0 1 0 5) 'gcr_el1 (sreg 3 0 1 0 6)
                'tfsr_el1 (sreg 3 0 5 6 0) 'tfsre0_el1 (sreg 3 0 5 6 1) 'apiakeylo_el1 (sreg 3 0 2 1 0)
                'apiakeyhi_el1 (sreg 3 0 2 1 1) 'apibkeylo_el1 (sreg 3 0 2 1 2)
                'apibkeyhi_el1 (sreg 3 0 2 1 3) 'apdakeylo_el1 (sreg 3 0 2 2 0)
                'apdakeyhi_el1 (sreg 3 0 2 2 1) 'apdbkeylo_el1 (sreg 3 0 2 2 2)
                'apdbkeyhi_el1 (sreg 3 0 2 2 3) 'apgakeylo_el1 (sreg 3 0 2 3 0)
                'apgakeyhi_el1 (sreg 3 0 2 3 1) 'hcr_el2 (sreg 3 4 1 1 0) 'mdcr_el2 (sreg 3 4 1 1 1)
                'cptr_el2 (sreg 3 4 1 1 2) 'hstr_el2 (sreg 3 4 1 1 3) 'sctlr_el2 (sreg 3 4 1 0 0)
                'ttbr0_el2 (sreg 3 4 2 0 0) 'tcr_el2 (sreg 3 4 2 0 2) 'vttbr_el2 (sreg 3 4 2 1 0)
                'vtcr_el2 (sreg 3 4 2 1 2) 'spsr_el2 (sreg 3 4 4 0 0) 'elr_el2 (sreg 3 4 4 0 1)
                'esr_el2 (sreg 3 4 5 2 0) 'far_el2 (sreg 3 4 6 0 0) 'mair_el2 (sreg 3 4 10 2 0)
                'vbar_el2 (sreg 3 4 12 0 0) 'vpidr_el2 (sreg 3 4 0 0 0) 'vmpidr_el2 (sreg 3 4 0 0 5)
                'icc_pmr_el1 (sreg 3 0 4 6 0) 'icc_dir_el1 (sreg 3 0 12 11 1)
                'icc_rpr_el1 (sreg 3 0 12 11 3) 'icc_sgi1r_el1 (sreg 3 0 12 11 5)
                'icc_iar1_el1 (sreg 3 0 12 12 0) 'icc_eoir1_el1 (sreg 3 0 12 12 1)
                'icc_hppir1_el1 (sreg 3 0 12 12 2) 'icc_bpr1_el1 (sreg 3 0 12 12 3)
                'icc_ctlr_el1 (sreg 3 0 12 12 4) 'icc_sre_el1 (sreg 3 0 12 12 5)
                'icc_igrpen1_el1 (sreg 3 0 12 12 7) 'icc_sre_el2 (sreg 3 4 12 9 5)
                'actlr_el1 (sreg 3 0 1 0 1) 'aidr_el1 (sreg 3 1 0 0 7) 'isr_el1 (sreg 3 0 12 1 0)
                'hpfar_el2 (sreg 3 4 6 0 4) 'dacr32_el2 (sreg 3 4 3 0 0) 'ifsr32_el2 (sreg 3 4 5 0 1)
                'fpexc32_el2 (sreg 3 4 5 3 0) 'dbgvcr32_el2 (sreg 2 4 0 7 0)
                'spsr_irq (sreg 3 4 4 3 0) 'spsr_abt (sreg 3 4 4 3 1) 'spsr_und (sreg 3 4 4 3 2) 'spsr_fiq (sreg 3 4 4 3 3)
                'mdccint_el1 (sreg 2 0 0 2 0) 'oslsr_el1 (sreg 2 0 1 1 4) 'dbgdtrrx_el0 (sreg 2 3 0 5 0)
                'dbgauthstatus_el1 (sreg 2 0 7 14 6)
                'pmcntenset_el0 (sreg 3 3 9 12 1) 'pmcntenclr_el0 (sreg 3 3 9 12 2) 'pmovsclr_el0 (sreg 3 3 9 12 3)
                'pmswinc_el0 (sreg 3 3 9 12 4) 'pmselr_el0 (sreg 3 3 9 12 5) 'pmceid0_el0 (sreg 3 3 9 12 6)
                'pmceid1_el0 (sreg 3 3 9 12 7) 'pmccntr_el0 (sreg 3 3 9 13 0) 'pmxevtyper_el0 (sreg 3 3 9 13 1)
                'pmxevcntr_el0 (sreg 3 3 9 13 2) 'pmovsset_el0 (sreg 3 3 9 14 3) 'pmccfiltr_el0 (sreg 3 3 14 15 7)
                'pmintenset_el1 (sreg 3 0 9 14 1) 'pmintenclr_el1 (sreg 3 0 9 14 2)}
   ;; the numbered families: dbgb/w v/c r<n>_el1 (n < 16), pmevcntr/pmevtyper<n>_el0 (n < 31)
   (a64-sfam s)
    (: tl (snip s (#s - 4) #s)
       (num p) (snip s #p (#s - 4) @ d
                  (starts? s p && 0 < #d < 3 && foldl (a \ c \ a && 48 <= c <= 57) 1 (chars d) ?
                     (foldl (a \ c \ a * 10 + c - 48) 0 (chars d))))
       (dbg p o2) (tl = "_el1" ? (num p @ n (charm? n && n < 16 ? (sreg 2 0 0 n o2))))
       (pmev p cm) (tl = "_el0" ? (num p @ n (charm? n && n < 31 ? (sreg 3 3 14 (cm + (n >> 3)) (n & 7)))))
       (#s < 8 ? () (dbg "dbgbvr" 4 || dbg "dbgbcr" 5 || dbg "dbgwvr" 6 || dbg "dbgwcr" 7 ||
                     pmev "pmevcntr" 8 || pmev "pmevtyper" 12)))
   ;; gas's generic s<op0>_<op1>_c<n>_c<m>_<op2> names the rest (s0_3_c1_c0_1 is wfit). any case reads
   (a64-sgen s)
    (: (parts i j acc) (? (#s <= j) (rev ((snip s i j) . acc))
                          (s j = 95) (parts (j + 1) (j + 1) ((snip s i j) . acc))
                          (parts i (j + 1) acc))
       (dec t) (0 < #t && foldl (a \ c \ a && 48 <= c <= 57) 1 (chars t) ?
                  (foldl (a \ c \ a * 10 + c - 48) 0 (chars t)) -1)
       (crx t) (1 < #t && t 0 = 99 ? (dec (snip t 1 #t)) -1)
       ps (1 < #s && s 0 = 115 ? (parts 1 1 ()) ())
       (#ps != 5 ? ()
          (: o0 (dec <ps) o1 (dec (ps 1)) cn (crx (ps 2)) cm (crx (ps 3)) o2 (dec (ps 4))
             (0 <= o0 <= 3 && 0 <= o1 <= 7 && 0 <= cn <= 15 && 0 <= cm <= 15 && 0 <= o2 <= 7 ?
                (sreg o0 o1 cn cm o2) ()))))
   (a64-sysreg nm)
    (: s (lower (show nm))
       (peep a64-sysregs (name s) () @ v
          (charm? v ? v (a64-sgen s @ k (charm? k ? k (a64-sfam s @ f (charm? f ? f (scare 'badsysreg nm))))))))
   ;; mrs of a write-only register by name scares
   a64-wo {'oslar_el1 1 'icc_dir_el1 1 'icc_sgi1r_el1 1 'icc_eoir1_el1 1 'pmswinc_el0 1}
   ;; op0 2 or 3 is a register, laid by the mrs/msr rows; a generic name's op0 0 or 1 is the
   ;; hint and sys space, the selector ored into the same head
   (a64-sysw mn l nm t)
    (: v (a64-sysreg nm) rt (a64-sysrt t)
       (v >> 20 & 1 ? (a6o mn (l ? [(ax rt) ['sys (v >> 5)]] [['sys (v >> 5)] (ax rt)]))
          (le32 (0xD5000000 | (l ? 0x200000 0) | v | rt))))
   (a64-mrs d nm) (? (a64-wo (name (lower (show nm)))) (scare 'badsysreg-wo nm) (a64-sysw 'mrs 1 nm d))   ; MRS Xd, <reg>
   (a64-msr nm s) (a64-sysw 'msr 0 nm s)                                                              ; MSR <reg>, Xs

   ;; MSR (immediate) to a pstate field: op1/op2 name it, the imm4 rides crm
   a64-pstate {'spsel '(0 5) 'daifset '(3 6) 'daifclr '(3 7)}
   (a64-msri fld imm)
      (peep a64-pstate (name (lower (show fld))) () @ r
         (two? r ? 0 (scare 'badpstate fld),
          imm >= 0 && imm <= 15 ? 0 (scare 'a64-pstate-imm imm),
          a6o 'msr [['pst <r <>r] (aim imm)]))

   ;; isb takes only sy, so it is nullary
   a64-barrier-opts {'oshld 1 'oshst 2 'osh 3 'nshld 5 'nshst 6 'nsh 7
                     'ishld 9 'ishst 10 'ish 11 'ld 13 'st 14 'sy 15}
   (a64-barrier mn opt) (a6o mn [['bar (look a64-barrier-opts opt 'badbarrier)]])
   (a64-dsb opt) (a64-barrier 'dsb opt)
   (a64-dmb opt) (a64-barrier 'dmb opt)

   ;; one table per instruction: the operand names nearly collide (dc ivac, ic ivau). the
   ;; whole-system forms take zr
   a64-tlbi-ops {'vmalle1 (sreg 1 0 8 7 0) 'vmalle1is (sreg 1 0 8 3 0)
                 'vae1 (sreg 1 0 8 7 1) 'vae1is (sreg 1 0 8 3 1)
                 'aside1is (sreg 1 0 8 3 2) 'alle1 (sreg 1 4 8 7 4)
                 'aside1 (sreg 1 0 8 7 2) 'vale1 (sreg 1 0 8 7 5) 'vale1is (sreg 1 0 8 3 5)
                 'vaae1is (sreg 1 0 8 3 3) 'vaale1is (sreg 1 0 8 3 7)
                 'vmalle1os (sreg 1 0 8 1 0) 'vae1os (sreg 1 0 8 1 1) 'vale1os (sreg 1 0 8 1 5)
                 'aside1os (sreg 1 0 8 1 2) 'alle2 (sreg 1 4 8 7 0) 'alle2is (sreg 1 4 8 3 0)
                 'alle1is (sreg 1 4 8 3 4) 'vmalls12e1 (sreg 1 4 8 7 6) 'vmalls12e1is (sreg 1 4 8 3 6)
                 'ipas2e1is (sreg 1 4 8 0 1) 'vale2is (sreg 1 4 8 3 5) 'vae2 (sreg 1 4 8 7 1)
                 'vaae1os (sreg 1 0 8 1 3) 'vaale1os (sreg 1 0 8 1 7) 'ipas2le1is (sreg 1 4 8 0 5)
                 'vae2is (sreg 1 4 8 3 1) 'ripas2e1is (sreg 1 4 8 0 2) 'ripas2le1is (sreg 1 4 8 0 6)
                 ;; the ranges (v8.4): crm 6 local, 2 inner shareable, 5 outer
                 'rvae1 (sreg 1 0 8 6 1) 'rvaae1 (sreg 1 0 8 6 3) 'rvale1 (sreg 1 0 8 6 5) 'rvaale1 (sreg 1 0 8 6 7)
                 'rvae1is (sreg 1 0 8 2 1) 'rvaae1is (sreg 1 0 8 2 3) 'rvale1is (sreg 1 0 8 2 5) 'rvaale1is (sreg 1 0 8 2 7)
                 'rvae1os (sreg 1 0 8 5 1) 'rvaae1os (sreg 1 0 8 5 3) 'rvale1os (sreg 1 0 8 5 5) 'rvaale1os (sreg 1 0 8 5 7)
                 'rvae2is (sreg 1 4 8 2 1) 'rvale2is (sreg 1 4 8 2 5)
                 'ipas2e1 (sreg 1 4 8 4 1) 'ipas2le1 (sreg 1 4 8 4 5) 'ripas2e1 (sreg 1 4 8 4 2) 'ripas2le1 (sreg 1 4 8 4 6)
                 'ipas2e1os (sreg 1 4 8 4 0) 'ipas2le1os (sreg 1 4 8 4 4) 'ripas2e1os (sreg 1 4 8 4 3) 'ripas2le1os (sreg 1 4 8 4 7)
                 'vmalls12e1os (sreg 1 4 8 1 6) 'alle1os (sreg 1 4 8 1 4) 'vale2 (sreg 1 4 8 7 5)
                 'vaae1 (sreg 1 0 8 7 3) 'vaale1 (sreg 1 0 8 7 7)
                 'alle2os (sreg 1 4 8 1 0) 'vae2os (sreg 1 4 8 1 1) 'vale2os (sreg 1 4 8 1 5)
                 'rvae2 (sreg 1 4 8 6 1) 'rvale2 (sreg 1 4 8 6 5) 'rvae2os (sreg 1 4 8 5 1) 'rvale2os (sreg 1 4 8 5 5)
                 'alle3 (sreg 1 6 8 7 0) 'alle3is (sreg 1 6 8 3 0) 'alle3os (sreg 1 6 8 1 0)
                 'vae3 (sreg 1 6 8 7 1) 'vae3is (sreg 1 6 8 3 1) 'vae3os (sreg 1 6 8 1 1)
                 'vale3 (sreg 1 6 8 7 5) 'vale3is (sreg 1 6 8 3 5) 'vale3os (sreg 1 6 8 1 5)}
   a64-ic-ops {'iallu (sreg 1 0 7 5 0) 'ialluis (sreg 1 0 7 1 0) 'ivau (sreg 1 3 7 5 1)}
   a64-dc-ops {'ivac (sreg 1 0 7 6 1) 'zva (sreg 1 3 7 4 1) 'cvac (sreg 1 3 7 10 1)
               'cvau (sreg 1 3 7 11 1) 'civac (sreg 1 3 7 14 1)
               'cvap (sreg 1 3 7 12 1) 'cvadp (sreg 1 3 7 13 1) 'isw (sreg 1 0 7 6 2)
               'csw (sreg 1 0 7 10 2) 'cisw (sreg 1 0 7 14 2) 'gva (sreg 1 3 7 4 3) 'gzva (sreg 1 3 7 4 4)}
   a64-at-ops {'s1e1r (sreg 1 0 7 8 0) 's1e1w (sreg 1 0 7 8 1)}
   (a64-sysrt t) (t = 'zr ? 31 (rn t))
   (a64-sys tab bad op t)
    (look tab op bad @ v
       (a6o 'sys [['raw ("#" + show (v >> 16 & 7))] ['raw ("c" + show (v >> 12 & 15))]
                  ['raw ("c" + show (v >> 8 & 15))] ['raw ("#" + show (v >> 5 & 7))] (ax (a64-sysrt t))]))

   ;; an imm16 exception. dbrk is a64's hlt (hlt #0xf000 semihosts), named apart from x86's hlt
   (a64-exc mn imm)
      (imm >= 0 && imm <= 65535 ? 0 (scare 'a64-exc-imm imm),
       a6o mn [['imx imm]])
   (a64-udf imm) (imm >= 0 && imm <= 65535 ? 0 (scare 'a64-exc-imm imm), a6o 'udf [(aim imm)])

   a64-emitters (emsof
        [('li . a64-li) ('mov . a64-mov) ('cmp . a64-cmp) ('imul . a64-imul)
          ('ld . a64-ld) ('st . a64-st)
          ('ld1 . a64-ld1) ('ld2 . a64-ld2) ('ld4 . a64-ld4)
          ('st1 . a64-st1) ('st2 . a64-st2) ('st4 . a64-st4)
          ('ldu1 . a64-ldu1) ('ldu2 . a64-ldu2) ('ldu4 . a64-ldu4)
          ('sx1 . a64-sx 1) ('sx2 . a64-sx 2) ('sx4 . a64-sx 4)
          ('zx1 . a64-zx 1) ('zx2 . a64-zx 2) ('zx4 . a64-zx 4)
          ('shlv . a64-shiftv 'shlv) ('shrv . a64-shiftv 'shrv) ('sarv . a64-shiftv 'sarv)
          ('rorv . a64-shiftv 'rorv) ('rorv4 . a64-shiftv 'rorv4)
          ('shl . a64-shift 'shl) ('shr . a64-shift 'shr) ('sar . a64-shift 'sar)
          ('lsl . a64-shs 'shl) ('lsr . a64-shs 'shr) ('asr . a64-shs 'sar) ('mvn . a64-mvn)
          ('uxtb . a64-zxs 1) ('uxth . a64-zxs 2) ('uxtw . a64-zxs 4)
          ('sxtb . a64-sxs 1) ('sxth . a64-sxs 2) ('sxtw . a64-sxs 4)
          ('rol . a64-shift 'rol) ('ror . a64-shift 'ror) ('ror4 . a64-shift 'ror4)
          ('lea . a64-lea) ('lean . a64-lea)
          ('push . a64-push) ('pop . a64-pop) ('frpush . a64-frpush) ('frpop . a64-frpop) ('cbr . a64-cbr) ('tbr . a64-tbr) ('afix . a64-afix)
          ('neg . a64-neg) ('not . a64-not) ('inc . a64-inc) ('dec . a64-dec) ('decm . a64-decm)
          ('jmp . a64-jmp) ('br . a64-br) ('jmpr . a64-jmpr) ('jmpt . a64-jmpt) ('callr . a64-callr)
          ('mulo . a64-mulo) ('mulh . a64-mulh) ('umulh . a64-umulh) ('set . a64-set) ('test . a64-test)
          ('div . a64-div) ('rem . a64-rem) ('udiv . a64-udiv) ('urem . a64-urem)
          ('a128 . a64-a128) ('s128 . a64-s128)
          ('m128 . a64-m128) ('mw128 . a64-mw128)
          ('a128r . a64-a128r) ('s128r . a64-s128r) ('m128r . a64-m128r)
          ('mw128r . a64-mw128r) ('c128r . a64-c128r) ('c128 . a64-c128)
          ('shl128 . a64-shl128) ('shr128 . a64-shr128) ('sar128 . a64-sar128)
          ('shl128v . a64-shl128v) ('shr128v . a64-shr128v) ('sar128v . a64-sar128v)
          ('dv128 . a64-dv128) ('rm128 . a64-rm128)
          ('sx128 . a64-sx128) ('n128 . a64-n128)
          ('inc128 . a64-inc128) ('dec128 . a64-dec128)
          ('ldx . a64-ldx) ('stx . a64-stx) ('leax . a64-leax)
          ('ldxb . a64-ldxb) ('ldxh . a64-ldxh) ('stxb . a64-stxb)
          ('ldsdx . a64-fldx) ('stsdx . a64-fstx) ('ldssx . a64-fldsx) ('stssx . a64-fstsx)
          ('cmov . a64-cmov)
          ('call . a64-call) ('la . a64-la) ('lar . a64-lar) ('lia . a64-lia)
          ('movsd . a64-fmov) ('movapd . a64-fmov) ('movss . a64-fmov)
          ('addsd . a64-fp3op 'addsd) ('subsd . a64-fp3op 'subsd)
          ('mulsd . a64-fp3op 'mulsd) ('divsd . a64-fp3op 'divsd)
          ('ucomisd . a64-fcmp) ('ucomiss . a64-fcmps) ('cvtsi2sd . a64-scvtf) ('cvttsd2si . a64-fcvtzs)
          ('addss . a64-fp3op 'addss) ('subss . a64-fp3op 'subss)
          ('mulss . a64-fp3op 'mulss) ('divss . a64-fp3op 'divss)
          ('cvtsi2ss . a64-scvtfs) ('cvttss2si . a64-fcvtzss) ('movdxr . a64-fmovsw) ('movdrx . a64-fmovws)
          ('movqxr . a64-fmovxr) ('movqrx . a64-fmovrx)
          ('stsd . a64-fst) ('ldsd . a64-fld) ('stss . a64-fsts) ('ldss . a64-flds)
          ('cvtss2sd . a64-fcvt-widen) ('cvtsd2ss . a64-fcvt-narrow)
          ('xorpd . a64-xorpd)
          ('raw . 1)
          ('mrs . a64-mrs) ('msr . a64-msr) ('msri . a64-msri)
          ('dsb . a64-dsb) ('dmb . a64-dmb)
          ('tlbi . a64-sys a64-tlbi-ops 'badtlbi)
          ('ic . a64-sys a64-ic-ops 'badic)
          ('dc . a64-sys a64-dc-ops 'baddc)
          ('at . a64-sys a64-at-ops 'badat)
          ('brk . a64-exc 'brk) ('dbrk . a64-exc 'hlt)
          ('hvc . a64-exc 'hvc) ('smc . a64-exc 'smc)
          ('udf . a64-udf)
          ('isb . a6o 'isb ())                              ; isb sy
          ('wfi . a6o 'hint [(aim 3)]) ('wfe . a6o 'hint [(aim 2)])
          ('eret . a6o 'eret ())
          ('ret . a6o 'ret [(ax 30)])
          ('sys . a6o 'svc [['imx 0]])
           ; netbsd/aarch64 takes the syscall number from svc's immediate, with no
           ; indirect syscall: a runtime number goes through a table of these
          ('svcn . a64-exc 'svc)                            ; svc #imm
          ('nop . a6o 'hint [(aim 0)])
          ('trap . a6o 'brk [['imx 0]])])
   _ (map (k \ emrow a64-emitters k (a64-aluop k)) (keys a64-alu))
   (a64-lower ins) (lower-via @ f (lit? f ? (f a64-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; the target's field, laid by the table's kind for it, ors into the base word aux
   (a64-patch kind target0 site width aux0)
      (: af (elem kind a64-afixk)                              ; an address fix carries its addend
         target (af ? (target0 + afix-ad aux0) target0) aux (af ? (afix-w aux0) aux0)
         rb (target - site)
         rel (rb // 4)
         (lay k o) (le32 (aux | <(a6e-op k [o] 0 site)))
         (? (kind = 'b26) (-33554432 <= rel < 33554432 ? (lay 'l26 ['lbl target])
                             (scare 'a64-branch-range rel))
            (elem kind '(b19 ld19)) (-262144 <= rel < 262144 ? (lay 'l19 ['lbl target])
                             (scare 'a64-branch-range rel))
            (kind = 'b14) (-8192 <= rel < 8192 ? (lay 'l14 ['lbl target])
                             (scare 'a64-branch-range rel))
            (kind = 'adrp21) (lay 'adrp ['lbl target])
            (kind = 'addlo12) (lay 'aimm (aim (target % 4096)))
            ; a load/store's imm12 counts units of its access width
            (elem kind '(lo12s1 lo12s2 lo12s4 lo12s8 lo12s16))
             (lay ['mu (kind @ 'lo12s1 1 'lo12s2 2 'lo12s4 4 'lo12s8 8 16)] ['mem 0 (target % 4096)])
            (kind = 'adr21) (-1048576 <= rb < 1048576 ? (lay 'adr ['lbl target])
                               (scare 'a64-branch-range rb))
            (kind = 'abs64) (le64 (target + aux))                    ; aux the byte addend
            (scare 'badfix kind)))

   ;; the linker's door. rela: bs holds the base word. () past the field's reach
   (a64-refix kind bs target site width)
    (: wd (bs 0 + (bs 1 << 8) + (bs 2 << 16) + (bs 3 << 24))
       rb (target - site) pg (target // 4096 - site // 4096)
       (? (kind = 'b26 && !(-134217728 <= rb <= 134217727)) ()
          (kind = 'adrp21 && !(-1048576 <= pg <= 1048575)) ()
          (kind = 'adr21 && !(-1048576 <= rb <= 1048575)) ()
          (a64-patch kind target site width wd)))

   a64 {}
   (pin a64 'lower a64-lower,
    pin a64 'patch a64-patch,
    pin a64 'refix a64-refix,
    pin a64 'nop '(31 32 3 213),           ; nop d503201f
    defbackend 'a64 a64))
) ; module 'holo
