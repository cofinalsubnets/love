#pragma once
/* linux's statfs, a machine word a field on 64-bit; the bsds answer ENOSYS */
#ifdef __ILP32__  /* i386 and arm: statfs64's record */
struct statfs {
  long f_type, f_bsize;
  unsigned long long f_blocks, f_bfree, f_bavail, f_files, f_ffree;
#else
struct statfs {
  long f_type, f_bsize;
  unsigned long f_blocks, f_bfree, f_bavail, f_files, f_ffree;
#endif
  int f_fsid[2];
  long f_namelen, f_frsize, f_flags, f_spare[4]; };
int statfs(char const*, struct statfs*);
int fstatfs(int, struct statfs*);
