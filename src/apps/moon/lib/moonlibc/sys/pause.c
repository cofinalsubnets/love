#include "../impl.h"
#include <poll.h>

/* no fds and no end: only a signal wakes it, and the answer is always EINTR's -1 */
int pause(void) { return poll(0, 0, -1); }
