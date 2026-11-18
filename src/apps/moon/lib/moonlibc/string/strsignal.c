#include "../impl.h"

/* glibc's texts, by linux's numbers (every kernel's here); 32 and 33 are nptl's, so the
 * real-time ones count from 34 */
static char const *const sigtx[32] = {
  0, "Hangup", "Interrupt", "Quit", "Illegal instruction", "Trace/breakpoint trap", "Aborted",
  "Bus error", "Floating point exception", "Killed", "User defined signal 1", "Segmentation fault",
  "User defined signal 2", "Broken pipe", "Alarm clock", "Terminated", "Stack fault", "Child exited",
  "Continued", "Stopped (signal)", "Stopped", "Stopped (tty input)", "Stopped (tty output)",
  "Urgent I/O condition", "CPU time limit exceeded", "File size limit exceeded",
  "Virtual timer expired", "Profiling timer expired", "Window changed", "I/O possible",
  "Power failure", "Bad system call" };
char *strsignal(int s) {
  static char b[32];
  if (s >= 1 && s <= 31) return (char *) sigtx[s];
  if (s >= 34 && s <= 64) snprintf(b, sizeof b, "Real-time signal %d", s - 34);
  else snprintf(b, sizeof b, "Unknown signal %d", s);
  return b; }
