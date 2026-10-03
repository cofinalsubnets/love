# osbox guests

`test/gate/osbox.sh` runs against a host bee knows with the cap `freebsd-x64`, `netbsd-x64`,
`freebsd-a64` or `netbsd-a64` (doc/bee.md, HOSTS), reached by its `reach` words. For a release
the env still names one (`FBSD_SSH`, `NBSD_SSH`, `FBSD_ARM64_SSH`, `NBSD_ARM64_SSH`), each an
ssh command prefix.

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
