// host/lux.c -- lux's socket nif. Host-only (links main.c), auto-globbed
// + auto-registered via AI_NIF; no ai.c/ai.h/main.c edit (the app pattern, like
// host/net.c which this mirrors). One nif:
//   (connectu path) -- connect to a unix-domain stream socket and wrap the fd
//   as a port | nil. The load-bearing case is an X display socket
//   (/tmp/.X11-unix/X<n>): real X servers listen only there, so lux's wire
//   codec (doc/proto/x11.l lineage) needs this one door the TCP nifs can't open.
// Once the fd is a port, read/write ride the existing fgetc/fputc machinery
// (cooperative on a not-ready fd), same as every net.c port.
#include "ai.h"
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>

// CLOSE-ON-EXEC for the same reason as net.c: a run/exec/spawn child must
// never inherit the display connection.
#define cloexec(fd) do { if ((fd) >= 0) fcntl((fd), F_SETFD, FD_CLOEXEC); } while (0)

ai_noinline static int call_connectu(struct ai_str *pv) {
 struct sockaddr_un a;
 if (pv->len == 0 || pv->len >= sizeof a.sun_path) return -1;
 memset(&a, 0, sizeof a);
 a.sun_family = AF_UNIX;
 memcpy(a.sun_path, pv->bytes, pv->len);
 int fd = socket(AF_UNIX, SOCK_STREAM, 0);
 if (fd < 0) return -1;
 if (connect(fd, (struct sockaddr*) &a, sizeof a)) { close(fd); return -1; }
 cloexec(fd);
 return fd; }

static lvm(lvm_connectu) {
 if (!ai_strp(Sp[0])) goto fail;
 int fd = call_connectu((struct ai_str*) Sp[0]);
 if (fd < 0) goto fail;
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }
 g = r;
 Unpack(g);
 // stack: [port, path, ...] -> [port, ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

static union u const nif_connectu[] = {{lvm_connectu}, {lvm_ret0}};
AI_NIF("connectu", nif_connectu);
