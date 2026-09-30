// FIXME this file is too short
// src/love/cb.c -- quay's screen nifs, wired up for this seat and nothing more.
// the bodies are generic and live with the engine (src/love/quay/nif.c over quay.c);
// what is host here is only the registration -- the love_nifs section glob is the
// host's trick, and another seat wires the same bodies its own way (the kernel a
// defs[] row, the playdate its own table). the quay sources ride along by unity
// include, the painter and its two fonts with them: every seat that links this file
// (the host, and each kernel through $(host_c)) has them once.
#include "love.h"
#include "quay/quay.c"
#include "quay/png.c"
#include "quay/paint.c"
#include "quay/cga_8x8.c"
#include "quay/cleat_8x16.c"
#include "quay/nif.c"

LvNif("screen", nif_screen, NULL);
LvNif("scribe", nif_scribe, NULL);
LvNif("glass", nif_glass, NULL);
LvNif("gaze", nif_gaze, NULL);
LvNif("reply", nif_reply, NULL);
LvNif("wet", nif_damage, NULL);
LvNif("facerow", nif_facerow, NULL);
LvNif("tilepx", nif_tilepx, NULL);
LvNif("dye", nif_dye, NULL);
LvNif("regrid", nif_regrid, NULL);
LvNif("peer", nif_peer, NULL);
LvNif("mouse", nif_mouse, NULL);
LvNif("pasted", nif_pasted, NULL);
LvNif("select", nif_select, NULL);
LvNif("copied", nif_copied, NULL);
LvNif("picture", nif_picture, NULL);
