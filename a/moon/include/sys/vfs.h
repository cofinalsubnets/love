#ifndef _AI_SYS_VFS_H
#define _AI_SYS_VFS_H
/* linux's statfs, which is the only one of the three kernels whose answer has this
 * shape at all -- the BSDs carry mount names and a version word inside theirs. every
 * field is a machine word on the 64-bit ports, so one struct serves x64, a64 and rv64.
 * off the syscall map elsewhere: a BSD asks and hears ENOSYS. */
struct statfs {
  long f_type, f_bsize;
  unsigned long f_blocks, f_bfree, f_bavail, f_files, f_ffree;
  int f_fsid[2];
  long f_namelen, f_frsize, f_flags, f_spare[4]; };
int statfs(char const*, struct statfs*);
int fstatfs(int, struct statfs*);
#endif
