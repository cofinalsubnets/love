# osbox guests

`test/gate/osbox.sh` runs against a host bee knows with the cap `freebsd-x64`, `netbsd-x64`,
`freebsd-a64`, `netbsd-a64`, `freebsd-rv64` or `netbsd-rv64` (doc/bee.md, HOSTS), reached by its
`reach` words. For a release the env still names one (`FBSD_SSH`, `NBSD_SSH`, `FBSD_ARM64_SSH`,
`NBSD_ARM64_SSH`, `FBSD_RV64_SSH`, `NBSD_RV64_SSH`), each an ssh command prefix.

## freebsd x64

The BASIC-CLOUDINIT qcow2 from `download.freebsd.org/releases/VM-IMAGES/<rel>/amd64/Latest/`,
with a NoCloud seed iso (`mkisofs -V cidata user-data meta-data`: `disable_root: false`, an
authorized key, `PermitRootLogin prohibit-password`):

    qemu-system-x86_64 -enable-kvm -m 2048 -drive file=img.qcow2,if=virtio \
      -cdrom seed.iso -nic user,hostfwd=tcp:127.0.0.1:2222-:22 -display none

First boot runs freebsd-update; sshd answers a few minutes in.

## netbsd x64

The `-live.img.gz` from `cdn.netbsd.org/pub/NetBSD/NetBSD-<rel>/images/`, gunzipped and
grown with `qemu-img resize`, booted the same way with `-qmp`. Its console is VGA, so the
one-time setup (rc.conf `sshd=YES dhcpcd=YES`, the key, `consdev=com0`) is typed in by QMP
send-key, as root with no password. sshd already takes keyed root.

## arm64

Both boot on `qemu-system-aarch64 -M virt -accel kvm` on an a64 host (TCG elsewhere is
about 2x slower again), with edk2 firmware:

- the disk must be `virtio-blk-pci` spelled out: `if=virtio` puts it on the MMIO bus,
  which edk2 does not enumerate, and UEFI walks its whole PXE list instead
- edk2 is not packaged for arch-arm; the `.fd` is guest code, so a copy from any host
  serves, and an empty 64M file is a fine varstore
- freebsd: the aarch64 BASIC-CLOUDINIT qcow2 from the same VM-IMAGES tree
- netbsd: the evbarm-aarch64 `arm64.img.gz` from the same cdn tree; it boots to a serial
  login, so the setup is typed over `-serial stdio`

## riscv64

Both boot on `qemu-system-riscv64 -M virt,acpi=off` under TCG, with the edk2 riscv firmware
(`RISCV_VIRT_CODE.fd`, and a copy of `RISCV_VIRT_VARS.fd` as the varstore):

- `acpi=off`: with acpi on, edk2 hands the kernel acpi tables and no device tree, and
  freebsd's riscv kernel reads only the device tree
- freebsd: the riscv64 `-ufs.qcow2` from `VM-IMAGES/<rel>/riscv64/Latest/` (no cloud-init
  variant). 14.5's loader does not name the boot hart, and the kernel panics before its
  console ("Boot hart ID was not properly set"). The fix is a device tree with
  `/chosen/boot-hartid`: dump QEMU's (`-M virt,acpi=off,dumpdtb=virt.dtb`, same `-smp`),
  add the property with `dtc`, and have the loader load it: once by hand from the ESP
  (`load /boot/kernel/kernel`, `load -t dtb disk0p1:/hart.dtb`, `boot`; mtools writes the ESP
  of a raw image at its partition offset), then from `/boot/loader.conf`
  (`hart_load`, `hart_type="dtb"`, `hart_name="/boot/dtb/hart.dtb"`). One hart, so the boot
  hart is always 0. The setup is typed over the serial socket: root has no password,
  `sysrc sshd_enable=YES fsck_y_enable=YES`, the key, `PermitRootLogin prohibit-password`
- netbsd: riscv64 images start at 11.0 (`NetBSD-11.0/riscv-riscv64/binary/gzimg/riscv64.img.gz`
  and the `netbsd-GENERIC64` kernel beside it); 10.x has none, and its syscall return
  convention differs. The kernel goes straight to qemu's opensbi (`-kernel netbsd-GENERIC64
  -append root=dk1`, virtio-*-device on the mmio bus), and it boots to a serial login like
  arm64's. It halts but never powers off, so a stop waits out the sync and then ends qemu
- neither has a power button for qmp's powerdown: both are asked over ssh
