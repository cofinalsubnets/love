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

LvNif("screen", nif_screen, NULL);
LvNif("scribe", nif_scribe, NULL);
LvNif("glass", nif_glass, NULL);
LvNif("gaze", nif_gaze, NULL);
LvNif("reply", nif_reply, NULL);
LvNif("wet", nif_damage, NULL);
LvNif("fontrow", nif_fontrow, NULL);
LvNif("tilepx", nif_tilepx, NULL);
LvNif("dye", nif_dye, NULL);
LvNif("regrid", nif_regrid, NULL);
LvNif("peer", nif_peer, NULL);
LvNif("mouse", nif_mouse, NULL);
LvNif("pasted", nif_pasted, NULL);
LvNif("select", nif_select, NULL);
LvNif("copied", nif_copied, NULL);
LvNif("picture", nif_picture, NULL);
LvNif("limned", nif_limned, NULL);
