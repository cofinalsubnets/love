// FIXME this file is too short
// cb.c -- quay's screen nifs registered for the host; the bodies are quay/nif.c's, and the
// quay sources ride along by unity include, so each link of this file has them once
#include "love.h"
#include "quay/quay.c"
#include "quay/png.c"
#include "quay/paint.c"
#include "quay/cga_8x8.c"
#include "quay/cleat_8x16.c"
#include "quay/nif.c"

LvNif("screen", nif_screen, "quay");
LvNif("scribe", nif_scribe, "quay");
LvNif("glass", nif_glass, "quay");
LvNif("gaze", nif_gaze, "quay");
LvNif("reply", nif_reply, "quay");
LvNif("clipped", nif_clipped, "quay");
LvNif("wet", nif_damage, "quay");
LvNif("fontrow", nif_fontrow, "quay");
LvNif("tilepx", nif_tilepx, "quay");
LvNif("dye", nif_dye, "quay");
LvNif("regrid", nif_regrid, "quay");
LvNif("peer", nif_peer, "quay");
LvNif("mouse", nif_mouse, "quay");
LvNif("pasted", nif_pasted, "quay");
LvNif("select", nif_select, "quay");
LvNif("copied", nif_copied, "quay");
LvNif("picture", nif_picture, "quay");
LvNif("limned", nif_limned, "quay");
