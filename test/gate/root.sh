#!/bin/sh
# root.sh -- the privileged verbs: chroot, mount, umount, sync, mkfifo, mknod.
#
# TWO HALVES, and the second is the one that means something:
#   unprivileged  -- every refusal comes back as a STATUS and a word, never a crash,
#                    and the bare `mount` listing is byte-identical to what
#                    /proc/self/mounts says. That much can be said as any user.
#   in a userns   -- test/gate/rootns.l, which makes itself root in an unprivileged
#                    user namespace and then does the real thing: a tmpfs mounted, a
#                    bind that really shows the other tree, both unmounted, and a
#                    chroot with a command running inside the new root. A gate that
#                    only watched these answer 'eperm would pass against a stub.
#
# usage: root.sh OUTDIR LOVE
set -u
ho=$1
m=$2
fail() { echo "FAIL $*" >&2; exit 1; }
case $ho in /*) HO=$ho;; *) HO=$PWD/$ho;; esac
W=$HO/.root; rm -rf "$W"; mkdir -p "$W"

# ---------------------------------------------------------------- refusals
# ⚠ a refusal has to be a STATUS. these all run as an ordinary user, so the kernel
# says no to every one of them, and what is being checked is that the no arrives as
# an exit code and a line on stderr rather than as a scare or a silent 0.
"$m" chroot /tmp/definitely-not-here 2>/dev/null && fail "chroot: a missing dir must fail"
"$m" chroot / /bin/true 2>/dev/null              && fail "chroot: unprivileged must fail"
"$m" umount /                        2>/dev/null && fail "umount /: unprivileged must fail"
"$m" mount -t tmpfs tmpfs /mnt       2>/dev/null && fail "mount: unprivileged must fail"
"$m" mount -o nosuchflag a b         2>/dev/null && fail "mount: an unknown -o word must fail"
"$m" mount onlyone                   2>/dev/null && fail "mount: one operand must fail"
"$m" chroot                          2>/dev/null && fail "chroot: no operand must fail"
"$m" umount                          2>/dev/null && fail "umount: no operand must fail"
"$m" sync extra                      2>/dev/null && fail "sync: an operand must be refused"
echo "root: the refusals are statuses (chroot/mount/umount/sync say no and live) ok"

# ---------------------------------------------------------------- sync and fifos
"$m" sync || fail "sync"
"$m" mkfifo "$W/f" || fail "mkfifo"
[ -p "$W/f" ] || fail "mkfifo: that is not a fifo"
"$m" mkfifo -m 600 "$W/g" || fail "mkfifo -m"
[ "$(stat -c %a "$W/g")" = 600 ] || fail "mkfifo -m: the mode did not land"
"$m" mknod "$W/h" p || fail "mknod p"
[ -p "$W/h" ] || fail "mknod p: that is not a fifo"
"$m" mkfifo "$W/f" 2>/dev/null && fail "mkfifo: an existing name must fail"
echo "root: sync, mkfifo and mknod p (the modes land, the second create refuses) ok"

# ---------------------------------------------------------------- the mount listing
# the oracle is /proc/self/mounts itself, formatted by awk -- NOT util-linux's own
# `mount`, which canonicalizes device names and consults /etc/mtab where there is
# one. Both usually agree; only one of them is a definition.
if [ -r /proc/self/mounts ]; then
  awk '{ printf "%s on %s type %s (%s)\n", $1, $2, $3, $4 }' /proc/self/mounts > "$W/want"
  "$m" mount > "$W/got" || fail "mount (bare)"
  cmp -s "$W/want" "$W/got" || { diff "$W/want" "$W/got" | head -6; fail "mount: the listing"; }
  echo "root: bare mount is /proc/self/mounts, formatted (byte-identical) ok"
fi

# ---------------------------------------------------------------- the real thing
"$m" "$PWD/test/gate/rootns.l" || fail "rootns.l"

rm -rf "$W"
