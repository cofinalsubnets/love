// kmain.c's faces to the seam files (sys.c, x64/proc.c, efi.c, the arch files): stdint and
// stdbool alone, since sys.c and proc.c build on moonlibc's impl.h, not love.h. k.h includes
// it, so kmain's definitions are checked against it
#pragma once
#include <stdint.h>
#include <stdbool.h>

// the higher-half direct map: physical P at khhdm + P; 0 = identity-mapped
extern uintptr_t khhdm;

// the kernel heap (kmallocw*, kfree) and libc's (k_grab, k_drop)
void *kmallocw(uintptr_t n), *kmallocwa(uintptr_t n, uintptr_t a), *k_grab(uintptr_t n);
void kfree(void *p), k_drop(void *p);
uintptr_t k_clock_ms(void);            // ms since the epoch, the kernel's one scale

// input: kq takes one byte; the rest are the wasm host's and the boards' feeds
void kq(uint8_t b);
void k_kb_poll(void);
void k_pointer(uint32_t how, uint32_t b, uint32_t y, uint32_t x);
void k_paste_in(uint8_t const *s, long n), k_paste_end(void);
void k_scan_put(uint8_t b);
bool k_scan_armed(void);

// the ramfs path faces, each 0 or a negative errno; readlink answers a count
struct k_st { uintptr_t size, ms, mode; };
int k_fs_open(char const *p, uintptr_t pn, char m),
    k_fs_stat(char const *p, uintptr_t pn, struct k_st *st, bool follow),
    k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode),
    k_fs_rmdir(char const *p, uintptr_t pn),
    k_fs_unlink(char const *p, uintptr_t pn),
    k_fs_rename(char const *o, uintptr_t on, char const *n, uintptr_t nn),
    k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn),
    k_fs_chdir(char const *p, uintptr_t pn),
    k_fs_getcwd(char *b, uintptr_t n),
    k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode),
    k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms);
intptr_t k_fs_readlink(char const *p, uintptr_t pn, char *b, uintptr_t n);
void k_fs_cwd_swap(char *cwd, uintptr_t *n);

// the fd faces, g-free: which task runs never crosses this seam
long k_fd_pipe(int fds[2]),
     k_fd_dup(int src, int at),
     k_fd_dup3(int src, int dst),
     k_fd_stat(int fd, struct k_st *st),
     k_fd_dents(int fd, void *buf, long cap),
     k_fs_opendir(char const *p, uintptr_t pn),
     k_fd_chdir(int fd),
     k_fd_write(int fd, void const *b, long n),
     k_fd_read(int fd, void *b, long n),
     k_fd_close(int fd),
     k_fd_lseek(int fd, long off, int whence),
     k_fd_truncate(int fd, long n);
bool k_fd_blocks(int fd);
int k_fd_term(int fd, int set, int *raw, uintptr_t *rows, uintptr_t *cols);
bool ready(int fd, int events);        // love's seat contract (fd.c), as love.h has it

// processes (sys.c): a syscall from one, and its seat words
long k_proc_call(long pid, long n, long a, long b, long c, long d, long e, long f);
void **k_proc_seat(long pid);
