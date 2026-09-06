#include "../impl.h"

/* sync(2) answers nothing and cannot fail: the kernel schedules the writeback and
 * returns. the syscall's own result is discarded for that reason and not by
 * oversight -- there is no errno lane to carry. */
void sync(void) { (void) sc0(NR_sync); }
