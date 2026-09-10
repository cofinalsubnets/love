// FIXME this file is too short
// i/cb.c -- quay's screen nifs, wired up for this seat and nothing more.
// the bodies are generic and live with the engine (l/quay/nif.c over quay.c);
// what is host here is only the registration -- the love_nifs section glob is the
// host's trick, and another seat wires the same bodies its own way (the kernel a
// defs[] row, the playdate its own table). the quay sources ride along by unity
// include: they are not otherwise linked into the host binary.
#include "love.h"
#include "../l/quay/quay.c"
#include "../l/quay/nif.c"

AiNif("screen", nif_screen, NULL);
AiNif("scribe", nif_scribe, NULL);
AiNif("glass", nif_glass, NULL);
AiNif("gaze", nif_gaze, NULL);
AiNif("reply", nif_reply, NULL);
AiNif("unfold", nif_unfold, NULL);
AiNif("wet", nif_damage, NULL);
