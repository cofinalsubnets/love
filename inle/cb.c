// FIXME this file is too short
// inle/cb.c -- quay's screen nifs, wired up for this seat and nothing more.
// the bodies are generic and live with the engine (love/quay/nif.c over quay.c);
// what is host here is only the registration -- the love_nifs section glob is the
// host's trick, and another seat wires the same bodies its own way (the kernel a
// defs[] row, the playdate its own table). the quay sources ride along by unity
// include: they are not otherwise linked into the host binary.
#include "love.h"
#include "../love/quay/quay.c"
#include "../love/quay/nif.c"

LvNif("screen", nif_screen, NULL);
LvNif("scribe", nif_scribe, NULL);
LvNif("glass", nif_glass, NULL);
LvNif("gaze", nif_gaze, NULL);
LvNif("reply", nif_reply, NULL);
LvNif("unfold", nif_unfold, NULL);
LvNif("wet", nif_damage, NULL);
