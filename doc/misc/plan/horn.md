# plan: horn — the audio door, on both seats

**THE CLAIM: sound is a PORT, and once it is, the hosted side comes with it.** The tree has no
audio anywhere. It does have a port layer whose write contract is already the contract a sound
card wants — land what fits, answer 0 when the ring is full, let the scheduler park the writer
— and `ai_io_alloc` is core rather than host, so an fd is a port on inle exactly as it is under
Linux. So the question "can the host have this too" is not a second implementation; it is the
same door with a different fd under it.

⚠ **`sound` is TAKEN and it is not close.** `sound` is love's reader — one datum off text,
`src/core/boot/p1.l`, and salt, dns, cli and bao all stand on it. There is a `sound0` nif beside it.
Naming the audio door `sound` would shadow the reader in every file that uses both. **`horn`**
is free and is what this plan spells; `reed`, `drum` and `chime` are free too if a better ear
than mine prefers one.

## what already exists, and it is most of it

* **the port vtable is the ring contract, verbatim.** `src/core/love.h`: *"writen: land up to n bytes
  in one motion: >0 landed, 0 no room now (caller keeps the residue), -1 the device is gone."*
  That is a DMA ring with backpressure, described without knowing it. A full audio buffer
  answers 0, the caller keeps the residue, and the scheduler's existing fd-park wakes it.
* ⚠ **it must be a HEAP port, and the vtable says why:** *"only a door whose port keeps a write
  run may refuse; the static ports cannot park."* So the horn is `ai_io_alloc`'s, never a boot
  row — and that is the same sentence on both seats.
* **an fd is a port on both seats already.** src/host/sock.c's whole method is "produce an OS fd,
  hand it to `ai_io_alloc`, and read and write come free"; doc/misc/inle.md says `ai_io_alloc`
  is core, not host. Neither seat needs a new mechanism, only a new device.
* **the PCI walk is written** (src/inle/blk.c, CF8/CFC) and so is virtio-mmio on a64. The disk
  rung already paid for both transports.
* **the flow doors are written** — spout/drip, backpressure, parking, the reader-bootstrap
  arc's whole rung 9. PCM is a byte stream that must not be dropped, which is the one shape
  those doors were built for.

## the shape

One device, two faces, the way the framebuffer already has two:

* **the love face** is a port. `(horn ...)` opens it and answers a port; PCM goes out through
  the ordinary write path, and a full ring is backpressure rather than a dropped frame. Rate,
  channels and format are the ONE thing an fd cannot carry, so they ride the open.
* **the C face** is a direct call (`k_horn_write`), for a program linked into the image that
  has no love heap in hand — src/inle/doom.c reaches `k_fb` the same way today.

⚠ **the door is a vtable, not an AC'97 shape.** qemu's a64 `virt` has no AC'97 (it offers
virtio-sound), and the hosted seats have neither. If the second device is a rewrite, the first
one was designed wrong.

## the ladder

Hosted first, and deliberately: it is where a mixer can be got right against real speakers with
no driver in the way, and where a gate can run on the dev box. inle is the rung that needs
hardware written; it should not also be the rung that debugs resampling.

### rung 0 — the name, the port, and a sink that discards

`horn` opens, answers a port, accepts PCM, throws it away. No hardware on either seat. This is
the rung that proves the *shape*: that a heap port refuses with 0 rather than dropping, that a
blocked writer parks and wakes, that the residue is kept.

*gate:* a love law that writes more frames than the ring holds and reads the backpressure —
`test/host/horn.l`, and the same file in the kernel corpus. **~1 day.**

### rung 1 — the BSD seat, which is nearly free

`/dev/dsp` is native on FreeBSD and NetBSD: open, three ioctls (`SNDCTL_DSP_SETFMT`, `SPEED`,
`CHANNELS`), then `write`. No library, no protocol, and the seed-universal arc already has boxes
on both (test_freebsd_a64, test_netbsd_a64).

⚠ **this is not the Linux lane.** This box has `/dev/snd/*` and no `/dev/dsp` at all — OSS is
gone from ordinary Linux, so anyone reading "just use /dev/dsp" will find nothing there.
**~1 day.**

### rung 2 — the Linux seat, by ioctl and no libasound

`/dev/snd/pcmC0D0p` with the ALSA ioctl protocol directly — `HW_REFINE`/`HW_PARAMS`,
`SW_PARAMS`, `PREPARE`, then `WRITEI_FRAMES`. It is a real protocol with a large parameter
struct, but it is **plain syscalls**, which is the only kind this tree may have: linking
libasound would put an ambient library under the artifact and the bare-cc door (rung 7 of
self-host-default) exists precisely so nothing does.

⚠ I have not written this handshake here — the size is an estimate off the interface, not off a
measurement. ⚠ device naming is a policy question, not a lookup: `pcmC0D0p` is not always the
one you want (this box's first playback node is `pcmC0D3p`). **~2-4 days**, and the widest error
bar on the ladder.

### rung 3 — inle on x64: AC'97

`-device AC97`, and it is the friendly one: **two I/O-port BARs**, so none of the 64-bit-MMIO
grief rung 5 hit under OVMF. A 32-entry buffer descriptor list of `kmallocw` buffers, the run
bit set, and the current-index register read from the write path — **polled, no interrupt**,
src/inle/blk.c's own posture and for blk.c's own reason.

⚠ `pa = va - khhdm` holds for heap memory and NOT for image statics — blk.c's warning, and the
BDL and every sample buffer are subject to it. ⚠ every door's map stops at 4 GiB.
⚠ `asmops.h` has `k_inb`/`k_outb`/`k_inl`/`k_outl` and **no 16-bit pair**; AC'97's mixer
registers are 16-bit, so `k_inw`/`k_outw` are a prerequisite. **~2-3 days**, ~200 lines, a twin
of blk.c in shape.

### rung 4 — inle on a64: virtio-sound

qemu `virt` carries `virtio-sound-device`. The transport is already written (blk.c's virtio-mmio
half); what is new is the device's own control/stream queues. This is the rung that proves rung
0's vtable was a vtable. **~3-4 days.**

### rung 5 — doom hears itself

doomgeneric asks for one `sound_module_t`: Init, GetSfxLumpNum, Update, UpdateSoundParams,
StartSound, StopSound, SoundIsPlaying, CacheSounds. `DG_sound_module` is the whole contract.
The work is a mixer, not plumbing: DMX lumps are 8-bit unsigned mono at 11025 Hz behind an
8-byte header, and eight channels want mixing with volume and separation into 16-bit stereo at
the device's rate. ⚠ `i_sdlsound.c` is 1076 lines and that number will mislead you — most of it
is SDL_mixer, libsamplerate and caching that a 200-line mixer does not need.

⚠ **it rides the C face**, like src/inle/doom.c's framebuffer: doom is linked into the image and has
no love heap in hand at `I_UpdateSound`. **~2 days on top of any one device rung.**

*gate:* the honest headless one — `-audiodev none` and assert the ring index advances, since a
gate cannot listen. Hearing it is a human's job, once.

## what is cheaper than it looks

* **backpressure is not new work.** The one thing that makes audio hard in a naive stack — what
  to do when the ring is full — is the port vtable's answer already, and the scheduler already
  parks and wakes on it.
* **the frame loop is a generous refill clock.** doom's `Update()` is called every frame and
  inle renders at ~260 fps, so a polled top-up has enormous margin. If the frame rate ever falls
  below the buffer duration the honest fix is a **bigger ring, not an interrupt**.
* **two of the four devices are already-paid transports.** PCI config space and virtio-mmio both
  exist.

## the expensive things nobody budgets

* **music is a synthesizer, and that is the whole cost.** `mus2mid.c` is vendored already, so
  MUS→MIDI is free — and then you owe a synth. Chocolate's answer is an OPL3 emulator of ~3-4k
  lines that doomgeneric does not ship. **Ship SFX and leave music silent**; revisit it as its
  own arc or not at all.
* **resampling policy.** 11025 → 48000 is not an integer ratio. Nearest-neighbour is audibly
  gritty on doom's samples and is what "it works" will sound like; linear is cheap and fine.
  Decide it once, in the mixer, not per device.
* **latency has no gate.** Ring depth trades underrun against lag and no test can hold it. Pick
  a depth, write down why, and expect to change it by ear.
* **capture is a different device.** The vtable has `readn` and `hda-duplex` exists, but nothing
  here needs a microphone and designing for one now would be inventing requirements.

## open

* **which name** — `horn` reads well beside quay and berth, but this is the one decision that is
  cheap now and expensive later.
* **where the rate/channels/format live.** They ride the open here. The alternative is a control
  door beside the port; that is what a second device with different constraints would want, and
  we do not have one yet.
* **whether the mixer is love or C.** doom needs the C face regardless. A love-side mixer would
  be the nicer artifact and would make `horn` useful to anything else in the tree; it is also
  the part where a per-sample loop in love has to be measured before it is believed.

## what landed (2026-09-06)

**rung 0 is the shape, and it is `src/host/horn.c`.** `(horn rate chans)` answers a heap port
wearing `ai_horn_vt`, which io.c takes for a bio (bio_of and ai_io_fd know two doors now), so the
write run buffers, a refused write keeps its residue and the writer parks on the 1 ms poll every
heap port has. `(horn-lag p)` reads frames queued and unplayed. the device under the door is
picked per seat: inle takes the C face; linux and freebsd open a card; `HORN=none` is a sink that
keeps time and discards, and `HORN=<path>` names a device. a mono port is doubled to stereo on the
way down, so every device is stereo s16. test/horn.l is the gate, on the fast corpus and the
kernel corpus both (it sets HORN itself).

**⚠ the laptop rung is HDA, not AC'97.** no laptop of the last fifteen years has an AC'97
controller; the dev box carries two Ryzen HDA functions (class 04.03), and qemu offers
`intel-hda` beside AC97. so rung 3 became `src/inle/hda.c`: PCI class walk, BAR0, CORB/RIRB (the
immediate registers are optional silicon and qemu has none), a codec walk that routes every wired
output pin back to a DAC through selectors and mixers, one output stream over a 128K ring under
a 32-entry BDL, the play head off the DMA position buffer (LPIB until it writes one). polled;
k_horn_poll rides the idle wait and silences what has played, so a writer that stops leaves
silence. the two snoop quirks the linux driver carries (intel TCSEL/NOSNOOP, the ATI SB450 bit)
are in, because a laptop with them unset plays garbage. the PM capability is walked to D0.
qemu's codec speaks 16k..96k; the laptop's may not speak 11025, so the mixer resamples.

**rung 2 is smaller than feared:** write(2) on a pcm node IS `WRITEI_FRAMES` (pcm_native.c's
file write op), so the handshake is one `HW_PARAMS` ioctl and a `PREPARE`, then the fd port's
own write path. the buffer is 4096..32768 frames and the kernel picks the least, ~85 ms at 48k.
device order is card order and nothing wiser -- this box's first node is its HDMI port, so
`HORN=/dev/snd/pcmC1D0p` names the speakers.

**rung 1 is freebsd only.** netbsd's `/dev/dsp` is libossaudio, a userspace shim over
`AUDIO_SETINFO`; the OSS ioctls are not kernel ioctls there, so that seat answers 'enodev until
someone writes the native handshake. the freebsd lane is written and not yet run on the box.

**rung 5 is `src/inle/doomsnd.c`**, ~150 lines: eight channels of DMX lumps, linear resampling to
48k, doom's own pan law, clipped into s16 stereo, topped up to a 100 ms lead every frame. music
is a silent door. `DOOM=1` builds it with `-DFEATURE_SOUND`.

**dropped:** AC'97 (qemu-only hardware), virtio-sound (no seat needs a64 audio yet), NetBSD OSS
(not native), the position buffer's per-controller quirks (LPIB fallback covers the ones seen).

**open, still:** hearing it on the laptop. the codec walk is generic and unmutes every amp on the
path at 0 dB; a codec that needs vendor coefficient verbs to reach its speaker amp (some Realtek
and Cirrus parts) will play through the headphone jack and not the speakers. that is a bug
report with a codec id in it, when it comes.

## the hosted door (2026-09-06, later the same day)

**doom runs on the host in an X window, off the same C.** src/inle/doom.c's doors went
seat-aware: under inle they are the kernel's (framebuffer, scancode tap, clock), on the host a
frame flag, a 64-deep key queue and ai_clock, driven a tick at a time by four nifs
(`doom-start` / `doom-tick` / `doom-frame` / `doom-key`). src/apps/doom/doom.l is the window: it
speaks lux's X wire -- src/apps/lux/wire.l is the `xwire` module now, every name exported, and
lux's own files `(use 'xwire)` -- creates one 640x400 window at the root's depth, pushes each
frame as four PutImage bands (256000 bytes apiece, under the 65535-word ceiling with no
BIG-REQUESTS to negotiate), polls the socket with `cue?` between ticks and respells KeyPress/
KeyRelease keysyms into doomkeys.h's codes. `love doom [-iwad F] [-display :N] [-frames N]` is
the verb (`make host DOOM=1` puts the game in the binary); the mixer reaches the host's card
through love.h's seat-neutral `ai_horn_*` face, so `HORN=/dev/snd/pcmC1D0p love doom` has sound
and `HORN=none` is silent. `make test_doomx` is the gate: an Xvfb, 120 frames, the count read
back. the title screen was checked by eye off an xwd of the Xvfb.

**still to do on this door:** the key path was not driven by a gate (no xdotool on the box;
test/host/luxui-probe.l's XTEST FakeInput is the way to add one); mouse; a window that closes
should end the process the ICCCM way, which it does through WM_DELETE_WINDOW but not on a
`kill` of the server.

**next, as asked:** `wget` in kore -- and since nothing worth fetching speaks plain http any
more, a TLS 1.3 client over the chacha/poly/sha256 the tree already carries; then `love doom`
laying `~/.love/love-<ver>/` through `love seed`, fetching doomgeneric and the shareware IWAD
there, building with DOOM=1 and running that binary.

## wget, and the TLS under it (2026-09-06, evening)

`kore wget [-q] [-O FILE] URL` (src/apps/kore/wget.l): a GET with Connection: close, eight
redirects, chunked bodies unchunked, exit codes wget's own. https rides **src/apps/tls/client.l,
a TLS 1.3 client** over the ciphers the tree already had: x25519 on the bignums (RFC 7748's
ladder by `%` and `//`), HKDF-SHA256 over the sha256 nif, chacha20-poly1305 records off
chacha.l and poly1305.l. one suite, one group, one version; ⚠ the peer is NOT verified -- the
certificate rides the transcript and is believed, and wget says so once per fetch. the RFC
vectors (7748 6.1, 4231 case 1) and an aead round trip are in test/host/wget.l beside a
kiosko-served http pull; test_wgetnet (opt-in) pulls a live front page. the two downloads
`love doom` wants both answer through it: the shareware IWAD (Daivuk/PureDOOM's raw file,
byte-identical to dl/doom1.wad) and the doomgeneric tarball off codeload.

⚠ two reader lessons, paid twice each: a multi-parameter lambda is `(\ a b body)`, never
`(\ (a b) body)` (that destructures one list); and an over-closed inner letrec reads as
";; missing <name>" at LOAD, not at the call -- bisect by loading the file's bindings one at
a time (cut at every `   (` line).
