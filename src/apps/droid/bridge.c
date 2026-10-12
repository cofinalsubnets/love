/* src/apps/droid/bridge.c -- the native activity an apk's love runs behind. built with
   `mooncc -t a64 -shared` against the phone's own libraries, it owns what only the app
   process may: the window, the input queue, logcat. love is the static binary shipped as
   lib/arm64-v8a/liblove.so, started as a child with LOVE_FACE naming a unix socket here.
   the wire, little-endian:
     love -> bridge  'F' u16 w u16 h, then w*h words 0x00rrggbb: a frame, scaled to the window
     bridge -> love  12-byte records (u8 kind, u8 a, u16 0, i32 b, i32 c):
                     'S' the window, b by c pixels   'K' key a=down, b=android keycode
                     'T' touch a=action (0 down 1 up 2 move), b c in frame pixels
   assets/argv holds love's arguments, NUL-separated; assets/app is laid in the data
   directory before each start, which is love's cwd and HOME. */

typedef unsigned long size_t; typedef long ssize_t; typedef int pid_t; typedef unsigned uint32_t;

typedef struct ANativeActivityCallbacks {
  void (*onStart)(void *); void (*onResume)(void *); void *(*onSaveInstanceState)(void *, size_t *);
  void (*onPause)(void *); void (*onStop)(void *); void (*onDestroy)(void *);
  void (*onWindowFocusChanged)(void *, int);
  void (*onNativeWindowCreated)(void *, void *); void (*onNativeWindowResized)(void *, void *);
  void (*onNativeWindowRedrawNeeded)(void *, void *); void (*onNativeWindowDestroyed)(void *, void *);
  void (*onInputQueueCreated)(void *, void *); void (*onInputQueueDestroyed)(void *, void *);
  void (*onContentRectChanged)(void *, void const *); void (*onConfigurationChanged)(void *);
  void (*onLowMemory)(void *);
} ANativeActivityCallbacks;
typedef struct { ANativeActivityCallbacks *callbacks; void *vm, *env, *clazz;
  char const *internalDataPath, *externalDataPath; int sdkVersion; void *instance, *assetManager;
  char const *obbPath; } ANativeActivity;
typedef struct { int width, height, stride, format; void *bits; unsigned reserved[6]; } ANativeWindow_Buffer;
typedef struct { char const *dli_fname; void *dli_fbase; char const *dli_sname; void *dli_saddr; } Dl_info;
struct sockaddr_un { unsigned short family; char path[108]; };

int __android_log_write(int, char const *, char const *);
int ANativeWindow_setBuffersGeometry(void *, int, int, int);
int ANativeWindow_getWidth(void *); int ANativeWindow_getHeight(void *);
int ANativeWindow_lock(void *, ANativeWindow_Buffer *, void *);
int ANativeWindow_unlockAndPost(void *);
void ANativeActivity_finish(void *);
void *ALooper_prepare(int); int ALooper_addFd(void *, int, int, int, void *, void *);
int ALooper_removeFd(void *, int); int ALooper_pollOnce(int, int *, int *, void **); void ALooper_wake(void *);
void AInputQueue_attachLooper(void *, void *, int, void *, void *); void AInputQueue_detachLooper(void *);
int AInputQueue_getEvent(void *, void **); int AInputQueue_preDispatchEvent(void *, void *);
void AInputQueue_finishEvent(void *, void *, int);
int AInputEvent_getType(void const *); int AKeyEvent_getAction(void const *); int AKeyEvent_getKeyCode(void const *);
int AMotionEvent_getAction(void const *); float AMotionEvent_getX(void const *, size_t); float AMotionEvent_getY(void const *, size_t);
void *AAssetManager_open(void *, char const *, int); void const *AAsset_getBuffer(void *);
long AAsset_getLength(void *); void AAsset_close(void *);
void *AAssetManager_openDir(void *, char const *); char const *AAssetDir_getNextFileName(void *); void AAssetDir_close(void *);
int dladdr(void const *, Dl_info *);
pid_t fork(void); int execve(char const *, char *const[], char *const[]); int pipe2(int[2], int);
int dup2(int, int); int close(int); ssize_t read(int, void *, size_t); ssize_t write(int, void const *, size_t);
void _exit(int); pid_t waitpid(pid_t, int *, int); int kill(pid_t, int); int chdir(char const *);
int open(char const *, int, ...); int unlink(char const *);
int socket(int, int, int); int bind(int, void const *, unsigned); int listen(int, int); int accept4(int, void *, void *, int);
void *mmap(void *, size_t, int, int, int, long); int munmap(void *, size_t);
int pthread_create(void *, void const *, void *(*)(void *), void *); int pthread_join(long, void **);
int pthread_mutex_lock(void *); int pthread_mutex_unlock(void *);
int snprintf(char *, size_t, char const *, ...);

enum { LISTEN = 1, CONN, LOG, INPUT };
enum { O_WRONLY = 1, O_CREAT = 0100, O_TRUNC = 01000, O_CLOEXEC = 02000000 };

typedef struct {
  ANativeActivity *a; void *looper, *win, *queue;
  int ww, wh, fw, fh, lsock, csock, logfd, pid, quit;
  long th; long mu[8];                    /* pthread_t, pthread_mutex_t (zero is unlocked) */
  uint32_t *fb; size_t fbsz;              /* a frame as love sent it */
  char dir[512], data[512], sock[600], line[2048]; int nline;
} br;

#define LOG(s) __android_log_write(4, "love", s)

static int readall(int fd, void *p, size_t n) {
  char *c = p;
  while (n) { ssize_t k = read(fd, c, n); if (k <= 0) return -1; c += k; n -= (size_t) k; }
  return 0;
}
static void put(br *b, int kind, int a, int x, int y) {
  unsigned char r[12] = {(unsigned char) kind, (unsigned char) a};
  int v[2] = {x, y}; char const *s = (char const *) v;
  for (int i = 0; i < 8; i++) r[4 + i] = (unsigned char) s[i];
  pthread_mutex_lock(b->mu);
  if (b->csock >= 0) write(b->csock, r, 12);
  pthread_mutex_unlock(b->mu);
}

/* the frame: read whole, then swizzled onto the window, which scales it */
static int frame(br *b) {
  unsigned char h[4];
  if (readall(b->csock, h, 4)) return -1;
  int w = h[0] | h[1] << 8, ht = h[2] | h[3] << 8;
  size_t n = (size_t) w * (size_t) ht * 4;
  if (n > b->fbsz) {
    if (b->fb) munmap(b->fb, b->fbsz);
    b->fb = mmap(0, n, 3, 0x22, -1, 0); b->fbsz = n;
    if (b->fb == (void *) -1) { b->fb = 0; b->fbsz = 0; return -1; }
  }
  if (readall(b->csock, b->fb, n)) return -1;
  pthread_mutex_lock(b->mu);
  if (b->win) {
    if (w != b->fw || ht != b->fh) ANativeWindow_setBuffersGeometry(b->win, w, ht, 1), b->fw = w, b->fh = ht;
    ANativeWindow_Buffer o;
    if (!ANativeWindow_lock(b->win, &o, 0)) {
      for (int y = 0; y < ht && y < o.height; y++) {
        uint32_t const *s = b->fb + (size_t) y * (size_t) w; uint32_t *d = (uint32_t *) o.bits + (size_t) y * (size_t) o.stride;
        for (int x = 0; x < w && x < o.width; x++) { uint32_t v = s[x]; d[x] = 0xff000000u | (v & 0xff00) | (v >> 16 & 0xff) | (v & 0xff) << 16; }
      }
      ANativeWindow_unlockAndPost(b->win);
    }
  }
  pthread_mutex_unlock(b->mu);
  return 0;
}

static void input(br *b) {
  void *e;
  while (b->queue && AInputQueue_getEvent(b->queue, &e) >= 0) {
    if (AInputQueue_preDispatchEvent(b->queue, e)) continue;
    int handled = 1;
    if (AInputEvent_getType(e) == 1) {
      int k = AKeyEvent_getKeyCode(e);
      put(b, 'K', AKeyEvent_getAction(e) == 0, k, 0);
      handled = k != 4;                   /* back still backs out */
    } else {
      int ac = AMotionEvent_getAction(e) & 0xff, fw = b->fw ? b->fw : b->ww, fh = b->fh ? b->fh : b->wh;
      int t = ac == 0 || ac == 5 ? 0 : ac == 1 || ac == 6 || ac == 3 ? 1 : 2;
      if (b->ww && b->wh)
        put(b, 'T', t, (int) (AMotionEvent_getX(e, 0) * (float) fw / (float) b->ww),
                       (int) (AMotionEvent_getY(e, 0) * (float) fh / (float) b->wh));
    }
    AInputQueue_finishEvent(b->queue, e, handled);
  }
}

/* love's stdout and stderr, a line at a time, to logcat */
static int logs(br *b) {
  ssize_t k = read(b->logfd, b->line + b->nline, sizeof b->line - 1 - (size_t) b->nline);
  if (k <= 0) return -1;
  b->nline += (int) k;
  int s = 0;
  for (int i = 0; i < b->nline; i++)
    if (b->line[i] == '\n') { b->line[i] = 0; LOG(b->line + s); s = i + 1; }
  if (s == 0 && b->nline == (int) sizeof b->line - 1) b->line[b->nline] = 0, LOG(b->line), s = b->nline;
  for (int i = s; i < b->nline; i++) b->line[i - s] = b->line[i];
  b->nline -= s;
  return 0;
}

static void *loop(void *p) {
  br *b = p;
  b->looper = ALooper_prepare(1);
  ALooper_addFd(b->looper, b->lsock, LISTEN, 1, 0, 0);
  ALooper_addFd(b->looper, b->logfd, LOG, 1, 0, 0);
  if (b->queue) AInputQueue_attachLooper(b->queue, b->looper, INPUT, 0, 0);
  while (!b->quit) {
    int fd, ev; void *d;
    int id = ALooper_pollOnce(-1, &fd, &ev, &d);
    if (id == LISTEN) {
      int c = accept4(b->lsock, 0, 0, O_CLOEXEC);
      if (c >= 0 && b->csock < 0) {
        b->csock = c; ALooper_addFd(b->looper, c, CONN, 1, 0, 0);
        if (b->ww) put(b, 'S', 0, b->ww, b->wh);
      } else if (c >= 0) close(c);
    } else if (id == CONN) {
      unsigned char k;
      if (readall(b->csock, &k, 1) || k != 'F' || frame(b)) {
        ALooper_removeFd(b->looper, b->csock);
        pthread_mutex_lock(b->mu); close(b->csock); b->csock = -1; pthread_mutex_unlock(b->mu);
        ANativeActivity_finish(b->a);
      }
    } else if (id == LOG) {
      if (logs(b)) ALooper_removeFd(b->looper, b->logfd);
    } else if (id == INPUT) input(b);
  }
  return 0;
}

static void spawn(br *b) {
  char *av[32], exe[600], *ev[4], home[600], tmp[600], face[640];
  void *as = AAssetManager_open(b->a->assetManager, "argv", 3);
  char const *s = as ? AAsset_getBuffer(as) : 0; long n = as ? AAsset_getLength(as) : 0;
  snprintf(exe, sizeof exe, "%s/liblove.so", b->dir);
  int k = 0; av[k++] = "love";
  for (long i = 0; i < n && k < 31; ) { av[k++] = (char *) s + i; while (i < n && s[i]) i++; i++; }
  av[k] = 0;
  snprintf(home, sizeof home, "HOME=%s", b->data); snprintf(tmp, sizeof tmp, "TMPDIR=%s", b->data);
  snprintf(face, sizeof face, "LOVE_FACE=%s", b->sock);
  ev[0] = home; ev[1] = tmp; ev[2] = face; ev[3] = 0;
  int p[2]; pipe2(p, O_CLOEXEC);
  b->pid = fork();
  if (!b->pid) { dup2(p[1], 1); dup2(p[1], 2); chdir(b->data); execve(exe, av, ev); _exit(127); }
  close(p[1]); b->logfd = p[0];
  if (as) AAsset_close(as);
}

/* assets/app into the data directory, fresh each start */
static void lay(br *b) {
  void *d = AAssetManager_openDir(b->a->assetManager, "app");
  char const *f; char src[600], dst[600];
  while (d && (f = AAssetDir_getNextFileName(d))) {
    snprintf(src, sizeof src, "app/%s", f); snprintf(dst, sizeof dst, "%s/%s", b->data, f);
    void *a = AAssetManager_open(b->a->assetManager, src, 3);
    if (!a) continue;
    int fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd >= 0) write(fd, AAsset_getBuffer(a), (size_t) AAsset_getLength(a)), close(fd);
    AAsset_close(a);
  }
  if (d) AAssetDir_close(d);
}

static br *me(void *a) { return ((ANativeActivity *) a)->instance; }
static void created(void *a, void *w) {
  br *b = me(a);
  ANativeWindow_setBuffersGeometry(w, 0, 0, 1);
  pthread_mutex_lock(b->mu);
  b->win = w; b->ww = ANativeWindow_getWidth(w); b->wh = ANativeWindow_getHeight(w); b->fw = b->fh = 0;
  pthread_mutex_unlock(b->mu);
  put(b, 'S', 0, b->ww, b->wh);
}
static void gone(void *a, void *w) {
  br *b = me(a);
  pthread_mutex_lock(b->mu); b->win = 0; pthread_mutex_unlock(b->mu);
}
static void qin(void *a, void *q) {
  br *b = me(a); b->queue = q;
  if (b->looper) AInputQueue_attachLooper(q, b->looper, INPUT, 0, 0);
}
static void qout(void *a, void *q) {
  br *b = me(a); AInputQueue_detachLooper(q); b->queue = 0;
}
static void destroy(void *a) {
  br *b = me(a);
  if (b->pid > 0) kill(b->pid, 15), waitpid(b->pid, 0, 0);
  b->quit = 1; ALooper_wake(b->looper); pthread_join(b->th, 0);
  if (b->csock >= 0) close(b->csock);
  close(b->lsock); close(b->logfd); unlink(b->sock);
  if (b->fb) munmap(b->fb, b->fbsz);
  munmap(b, sizeof *b);
}

void ANativeActivity_onCreate(ANativeActivity *a, void *saved, size_t n) {
  br *b = mmap(0, sizeof *b, 3, 0x22, -1, 0);
  Dl_info d; dladdr((void *) ANativeActivity_onCreate, &d);
  snprintf(b->dir, sizeof b->dir, "%s", d.dli_fname);
  for (int i = 0; b->dir[i]; i++) if (b->dir[i] == '/') n = (size_t) i;
  b->dir[n] = 0;
  snprintf(b->data, sizeof b->data, "%s", a->internalDataPath);
  snprintf(b->sock, sizeof b->sock, "%s/face", b->data);
  b->a = a; b->csock = -1; a->instance = b;
  a->callbacks->onNativeWindowCreated = created; a->callbacks->onNativeWindowDestroyed = gone;
  a->callbacks->onInputQueueCreated = qin; a->callbacks->onInputQueueDestroyed = qout;
  a->callbacks->onDestroy = destroy;
  struct sockaddr_un u = {1}; snprintf(u.path, sizeof u.path, "%s", b->sock);
  unlink(b->sock);
  b->lsock = socket(1, 1 | O_CLOEXEC, 0);
  bind(b->lsock, &u, sizeof u); listen(b->lsock, 1);
  lay(b); spawn(b);
  pthread_create(&b->th, 0, loop, b);
}
