/* src/apps/macos/horn.c -- the horn's listener on macos. love's horn (HORN=sock:PATH) says
   the rate as a little-endian u32, then s16 stereo frames, and an AudioQueue plays them.
   one horn at a time, each until love closes it; then the next is taken. built by mooncc
   as dyld's mach-o against the framework:
     love cc -framework AudioToolbox src/apps/macos/horn.c -o horn
     ./horn /tmp/love-horn.sock &   HORN=sock:/tmp/love-horn.sock love lore ..
   the queue calls back on a thread of its own: each call reads a buffer's worth from the
   socket, silence filling what love has not said, and the end of the stream wakes the main
   thread through a pipe to dispose of the queue. */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

typedef struct { double rate; unsigned fmt, flags, bpp, fpp, bpf, ch, bits, res; } asbd;
typedef struct { unsigned cap; void *data; unsigned size; } aqbuf;   /* the head AudioQueueBuffer opens with */
typedef void (*aqcb)(void *, void *, aqbuf *);
int AudioQueueNewOutput(asbd const *, aqcb, void *, void *, void *, unsigned, void **);
int AudioQueueAllocateBuffer(void *, unsigned, aqbuf **);
int AudioQueueEnqueueBuffer(void *, aqbuf *, unsigned, void const *);
int AudioQueueStart(void *, void const *);
int AudioQueueDispose(void *, unsigned char);

enum { NBUF = 3, BUFB = 4096 * 4 };    /* three buffers of 4096 frames: ~250 ms at 48k */
struct horn { int fd, done[2], over; };

/* a buffer's worth off the socket, or what came before love hung up, the rest silence */
static void fill(void *u, void *q, aqbuf *b) {
  struct horn *h = u;
  unsigned got = 0;
  while (!h->over && got < b->cap) {
    long k = read(h->fd, (char *) b->data + got, b->cap - got);
    if (k <= 0) { h->over = 1; write(h->done[1], "x", 1); break; }
    got += (unsigned) k; }
  memset((char *) b->data + got, 0, b->cap - got);
  b->size = b->cap;
  if (!h->over) AudioQueueEnqueueBuffer(q, b, 0, 0); }

static void play(int fd) {
  unsigned char r[4];
  struct horn h = { fd, {-1, -1}, 0 };
  void *q = 0;
  if (read(fd, r, 4) != 4 || pipe(h.done)) { close(fd); return; }
  asbd f = { r[0] | r[1] << 8 | r[2] << 16, 0x6c70636d, 12, 4, 1, 4, 2, 16, 0 };   /* lpcm, signed packed */
  if (AudioQueueNewOutput(&f, fill, &h, 0, 0, 0, &q)) fprintf(stderr, "horn: no output queue\n");
  else {
    for (int i = 0; i < NBUF && !h.over; i++) {
      aqbuf *b;
      if (!AudioQueueAllocateBuffer(q, BUFB, &b)) fill(&h, q, b); }
    char c;
    if (h.over || !AudioQueueStart(q, 0)) read(h.done[0], &c, 1);   /* until love hangs up */
    AudioQueueDispose(q, 1); }
  close(h.done[0]), close(h.done[1]), close(fd); }

int main(int argc, char **argv) {
  if (argc != 2) { fprintf(stderr, "usage: horn SOCKET\n"); return 2; }
  struct sockaddr_un a;
  memset(&a, 0, sizeof a);
  a.sun_family = AF_UNIX;
  if (strlen(argv[1]) >= sizeof a.sun_path) { fprintf(stderr, "horn: path too long\n"); return 2; }
  strcpy(a.sun_path, argv[1]);
  unlink(argv[1]);
  int s = socket(AF_UNIX, SOCK_STREAM, 0);
  if (s < 0 || bind(s, (struct sockaddr *) &a, sizeof a) || listen(s, 4)) { perror("horn"); return 1; }
  for (int fd; (fd = accept(s, 0, 0)) >= 0; ) play(fd);
  perror("horn");
  return 1; }
