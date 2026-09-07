; test/gate/rvboot.l -- bind the riscv boot gate's ELF, through the kernel linker's own
; door. mooncc's driver puts its crt0 first and enters through it, which is right for a
; hosted exe and wrong for a machine: SBI enters at the ELF's entry, and that has to be
; the boot stub. `ldkern` is the door built for exactly this -- lanes in boot order, the
; entry named rather than taken off the first object -- and this drives it over the three
; objects the gate links: boot.o, the device-tree door, and the gate's own kmain.
;
;   love -l <holo cat> test/gate/rvboot.l boot.o dtb.o gate.o out.elf
;
; the rv64 backend is read in rather than used: the host bakes its NATIVE encoder only,
; and the linker reaches back into the backend to re-encode a relocated field.

(reads (open "core/holo/rv64.l" "r"))
(use 'holo)

(: (rvg-die m) (: _ (say err ("rvboot: " + m + "\n")) (quit 1))
   (rvg-read p) (: q (open p "r")
                   (? q (: s (slurp q) _ (close q) [p (s + "")])
                      (rvg-die ("cannot read " + p))))

   rvg-base 0x80200000                  ; where OpenSBI hands a kernel the hart

   (rvg-main av)
    (? (4 <= tally av)
       (: srcs (map rvg-read [<av <>av <>>av])
          dst (av 3)
          ; ldkern answers (header . pieces), which ld-write is what lays down
          k (ldkern 'rv64 "rvboot" rvg-base 0 srcs)
          _ (ld-write dst (<k >< >k))
          (say out ("RVBOOT\t" + (av 3) + "\n")))
       (rvg-die "usage: rvboot.l BOOT.o DTB.o GATE.o OUT.elf"))

   (rvg-main >argv))
