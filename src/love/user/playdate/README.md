# love on the playdate: lore's stones

lore's stones walked on the device: the d-pad walks and turns, the crank looks up
and down, A or B kneels and chooses, and the song plays through horn.c. stones.l
is the glue; main.c is the love frontend (the console is a quay cb, 50x30 cells
of the 8x8 CGA font, laid over the dithered 1-bit frame). the image is baked on
qemu's M7 by src/inle/mps2 (`imgpds`) and rides the pdx.

    make -C src/love/user/playdate        # out/playdate/love.pdx (device + simulator)
    make -C src/love/user/playdate sim    # run it in the Playdate Simulator

**nothing foreign compiles or links the device half.** mooncc `-t thumb2sp`
builds every object, pdglue.c included -- it owns pd_api.h and flattens the SDK
to a word-only seam, and it stands in for the SDK's setup.c (the entry and the
malloc trio) -- and our own linker binds them: `-Ttext 0` because link_map.ld
names no address at all, `--emit-relocs` so the ABS32 sites survive for the
loader to slide, `-nostdlib` because six moonlibc members and rt.c beside them
are the whole runtime this seat wants. The STM32F746's FPU is single-precision,
so f64 arithmetic softens to the `__aeabi_*` calls rt.c answers, gated bit-exact
by `make test_thumb2sp`; `la` rides pooled ABS32 words, which is what makes the
relocation table complete (a MOVW/MOVT pair is an absolute no loader slides by
adding to a word). PLAYDATE_SDK_PATH is wanted for the C_API headers and for
pdc, which bundles the .pdx. The simulator pdex.so stays a host gcc shared
object -- there setup.c is the SDK's again -- so `make sim` needs no cross tools.

based on Panic's "Hello World" C API example by Dave Hayden.
