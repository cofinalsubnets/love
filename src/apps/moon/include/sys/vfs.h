#pragma once
/* linux's statfs, a machine word a field on 64-bit; the bsds answer ENOSYS */
#ifdef __mips__   /* mips's statfs64, in its own order */
struct statfs {
  unsigned long f_type, f_bsize, f_frsize;
  unsigned long long f_blocks, f_bfree, f_files, f_ffree, f_bavail;
  int f_fsid[2];
  unsigned long f_namelen, f_flags, f_spare[5]; };
#else
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
#endif
int statfs(char const*, struct statfs*), fstatfs(int, struct statfs*);
