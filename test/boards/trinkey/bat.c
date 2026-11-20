// the trinkey's second stage: ../battery1.h without lm and the runtime it calls, laid at sram's
// base and carried there over the usb console once the first stage runs
#include "../battery1.h"

int battery(void) { return run(); }
