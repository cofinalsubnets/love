/* src/apps/droid/bridge.c -- the native activity an apk's love runs behind. built with
   `mooncc -t a64 -shared` against the phone's own libraries, it owns what only the app
   process may: the window, the input queue, logcat. love is the static binary shipped as
   lib/arm64-v8a/liblove.so, started as a child with LOVE_FACE naming a unix socket here.
   the wire, little-endian:
     love -> bridge  'F' u16 w u16 h u16 y u16 n, then n*w words 0x00rrggbb: rows y.. of a
                     w by h frame, scaled to what the window shows
                     'I' u8 on: the soft keyboard up, then toggled at each touch, or down
     bridge -> love  12-byte records (u8 kind, u8 a, u16 0, i32 b, i32 c):
                     'S' the window's visible part, b by c pixels
                     'K' key a=down, b=android keycode, c=the character it types or 0
                     'T' touch a=action (0 down 1 up 2 move), b c in frame pixels
   sound is a second socket: love's horn (HORN=sock:PATH) says the rate as a u32, then
   s16 stereo frames, which a thread of their own plays through AAudio. the mic is a
   third (HORN_IN=sock:PATH): the rate word's top byte asks the channels, and an AAudio
   input stream's s16 frames go back. assets/perms names the permissions to ask for at
   start (RECORD_AUDIO for the mic), NUL-separated; the input stream waits on the grant.
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
int AInputEvent_getType(void const *); int AInputEvent_getDeviceId(void const *); int AKeyEvent_getMetaState(void const *); int AKeyEvent_getAction(void const *); int AKeyEvent_getKeyCode(void const *);
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
int pthread_detach(long);
int AAudio_createStreamBuilder(void **); int AAudioStreamBuilder_delete(void *);
void AAudioStreamBuilder_setSampleRate(void *, int); void AAudioStreamBuilder_setChannelCount(void *, int);
void AAudioStreamBuilder_setFormat(void *, int); void AAudioStreamBuilder_setPerformanceMode(void *, int);
int AAudioStreamBuilder_openStream(void *, void **);
int AAudioStream_requestStart(void *); int AAudioStream_write(void *, void const *, int, long); int AAudioStream_close(void *);
void AAudioStreamBuilder_setDirection(void *, int); int AAudioStream_read(void *, void *, int, long);
void *dlsym(void *, char const *); int usleep(unsigned); ssize_t send(int, void const *, size_t, int);
struct pollfd { int fd; short events, revents; }; int poll(struct pollfd *, unsigned long, int);

enum { LISTEN = 1, CONN, LOG, INPUT, HORN, EAR };
enum { O_WRONLY = 1, O_CREAT = 0100, O_TRUNC = 01000, O_CLOEXEC = 02000000 };

typedef struct {
  ANativeActivity *a; void *looper, *win, *queue;
  int ww, wh, fw, fh, lsock, csock, logfd, pid, quit, hsock, esock, vh, typing, shown;
  void *env, *kcm, *kload, *kget;         /* the loop thread's JNIEnv, KeyCharacterMap's class and methods */
  long th; long mu[8];                    /* pthread_t, pthread_mutex_t (zero is unlocked) */
  uint32_t *fb; size_t fbsz; int gh;      /* a frame as love sent it, the window's buffer height */
  char dir[512], data[512], sock[600], horn[600], ear[600], line[2048]; int nline;
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

static int vis(br *b) { return b->vh > 0 && b->vh < b->wh ? b->vh : b->wh; }

/* the frame swizzled onto the window's visible part (its top vh rows, the rest black),
   which the window scales; under the lock */
static void paint(br *b) {
  int w = b->fw, ht = b->fh;
  if (b->win && b->fb && w) {
    int vh = vis(b), gh = vh ? (int) ((long) ht * b->wh / vh) : ht;
    if (gh != b->gh) ANativeWindow_setBuffersGeometry(b->win, w, gh, 1), b->gh = gh;
    ANativeWindow_Buffer o;
    if (!ANativeWindow_lock(b->win, &o, 0)) {
      for (int y = 0; y < o.height; y++) {
        uint32_t const *s = b->fb + (size_t) y * (size_t) w; uint32_t *d = (uint32_t *) o.bits + (size_t) y * (size_t) o.stride;
        for (int x = 0; x < o.width; x++) {
          uint32_t v = y < ht && x < w ? s[x] : 0;
          d[x] = 0xff000000u | (v & 0xff00) | (v >> 16 & 0xff) | (v & 0xff) << 16;
        }
      }
      ANativeWindow_unlockAndPost(b->win);
    }
  }
}

/* rows of a frame, kept whole here */
static int frame(br *b) {
  unsigned char h[8];
  if (readall(b->csock, h, 8)) return -1;
  int w = h[0] | h[1] << 8, ht = h[2] | h[3] << 8, y0 = h[4] | h[5] << 8, n = h[6] | h[7] << 8;
  size_t sz = (size_t) w * (size_t) ht * 4;
  if (y0 + n > ht) return -1;
  if (w != b->fw || ht != b->fh || !b->fb) {   /* a new size: a fresh black frame, the window's paint held off */
    pthread_mutex_lock(b->mu);
    if (sz > b->fbsz) {
      if (b->fb) munmap(b->fb, b->fbsz);
      b->fb = mmap(0, sz, 3, 0x22, -1, 0); b->fbsz = sz;
      if (b->fb == (void *) -1) b->fb = 0, b->fbsz = 0;
    }
    if (b->fb) for (size_t i = 0; i < (size_t) w * (size_t) ht; i++) b->fb[i] = 0;
    b->fw = b->fb ? w : 0; b->fh = ht; b->gh = 0;
    pthread_mutex_unlock(b->mu);
    if (!b->fb) return -1;
  }
  if (readall(b->csock, b->fb + (size_t) y0 * (size_t) w, (size_t) n * (size_t) w * 4)) return -1;
  pthread_mutex_lock(b->mu);
  paint(b);
  pthread_mutex_unlock(b->mu);
  return 0;
}

/* the soft keyboard, through the InputMethodManager: android 12 ignores NativeActivity's own
   ask, its view being no text editor, but takes a toggle; down is a hide from the window */
static void keyboard(br *b, void *e, int on) {
  if (!e) return;
  void *const *t = *(void *const **) e;
  void *(*cls)(void *, void *) = t[31]; void *(*mid)(void *, void *, char const *, char const *) = t[33];
  void *(*callo)(void *, void *, void *, ...) = t[34]; void (*callv)(void *, void *, void *, ...) = t[61];
  int (*callz)(void *, void *, void *, ...) = t[37];
  void *(*str)(void *, char const *) = t[167]; void (*clear)(void *) = t[17];
  int (*push)(void *, int) = t[19]; void *(*pop)(void *, void *) = t[20];
  if (push(e, 16)) { clear(e); return; }
  void *ac = b->a->clazz;
  void *imm = callo(e, ac, mid(e, cls(e, ac), "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;"), str(e, "input_method"));
  if (imm && on) callv(e, imm, mid(e, cls(e, imm), "toggleSoftInput", "(II)V"), 2, 0);
  else if (imm) {
    void *w = callo(e, ac, mid(e, cls(e, ac), "getWindow", "()Landroid/view/Window;"));
    void *v = w ? callo(e, w, mid(e, cls(e, w), "getDecorView", "()Landroid/view/View;")) : 0;
    void *tok = v ? callo(e, v, mid(e, cls(e, v), "getWindowToken", "()Landroid/os/IBinder;")) : 0;
    if (tok) callz(e, imm, mid(e, cls(e, imm), "hideSoftInputFromWindow", "(Landroid/os/IBinder;I)Z"), tok, 0);
  }
  clear(e); pop(e, 0);
}

/* the part the soft keyboard leaves, asked of the decor view's insets (ime, 8) while love
   types: a whole screen's window is not resized for it. a change goes to love as its size */
static void insets(br *b) {
  void *e = b->env; if (!e || !b->ww) return;
  void *const *t = *(void *const **) e;
  void *(*cls)(void *, void *) = t[31]; void *(*mid)(void *, void *, char const *, char const *) = t[33];
  void *(*callo)(void *, void *, void *, ...) = t[34]; void *(*fid)(void *, void *, char const *, char const *) = t[94];
  int (*geti)(void *, void *, void *) = t[100]; void (*clear)(void *) = t[17];
  int (*push)(void *, int) = t[19]; void *(*pop)(void *, void *) = t[20];
  if (push(e, 16)) { clear(e); return; }
  void *ac = b->a->clazz, *w = callo(e, ac, mid(e, cls(e, ac), "getWindow", "()Landroid/view/Window;"));
  void *v = w ? callo(e, w, mid(e, cls(e, w), "getDecorView", "()Landroid/view/View;")) : 0;
  void *wi = v ? callo(e, v, mid(e, cls(e, v), "getRootWindowInsets", "()Landroid/view/WindowInsets;")) : 0;
  void *in = wi ? callo(e, wi, mid(e, cls(e, wi), "getInsets", "(I)Landroid/graphics/Insets;"), 8) : 0;
  int bot = in ? geti(e, in, fid(e, cls(e, in), "bottom", "I")) : -1;
  clear(e); pop(e, 0);
  if (bot >= 0) b->shown = bot > 0;
  if (bot < 0 || bot >= b->wh || b->wh - bot == vis(b)) return;
  pthread_mutex_lock(b->mu); b->vh = b->wh - bot; paint(b); pthread_mutex_unlock(b->mu);
  put(b, 'S', 0, b->ww, vis(b));
}

/* what a key types: KeyCharacterMap.load(device).get(code, meta), through JNIEnv's table */
static int typed(br *b, void const *ev) {
  void *e = b->env; if (!e) return 0;
  void *const *t = *(void *const **) e;
  void (*clear)(void *) = t[17]; void (*dell)(void *, void *) = t[23];
  if (!b->kcm) {
    void *(*find)(void *, char const *) = t[6]; void *(*glob)(void *, void *) = t[21];
    void *(*mid)(void *, void *, char const *, char const *) = t[33], *(*smid)(void *, void *, char const *, char const *) = t[113];
    void *c = find(e, "android/view/KeyCharacterMap");
    if (!c) { clear(e); return 0; }
    b->kcm = glob(e, c); dell(e, c);
    b->kload = smid(e, b->kcm, "load", "(I)Landroid/view/KeyCharacterMap;");
    b->kget = mid(e, b->kcm, "get", "(II)I");
    clear(e);
  }
  if (!b->kload || !b->kget) return 0;
  void *(*cso)(void *, void *, void *, ...) = t[114]; int (*ci)(void *, void *, void *, ...) = t[49];
  void *m = cso(e, b->kcm, b->kload, AInputEvent_getDeviceId(ev));
  int u = m ? ci(e, m, b->kget, AKeyEvent_getKeyCode(ev), AKeyEvent_getMetaState(ev)) : 0;
  if (m) dell(e, m);
  clear(e);
  return u < 0 ? 0 : u;                   /* a dead key's accent is no character yet */
}

static void input(br *b) {
  void *e;
  while (b->queue && AInputQueue_getEvent(b->queue, &e) >= 0) {
    if (AInputQueue_preDispatchEvent(b->queue, e)) continue;
    int handled = 1;
    if (AInputEvent_getType(e) == 1) {
      int k = AKeyEvent_getKeyCode(e), down = AKeyEvent_getAction(e) == 0;
      put(b, 'K', down, k, down ? typed(b, e) : 0);
      handled = k != 4;                   /* back still backs out */
    } else {
      int ac = AMotionEvent_getAction(e) & 0xff, vh = vis(b);
      int t = ac == 0 || ac == 5 ? 0 : ac == 1 || ac == 6 || ac == 3 ? 1 : 2;
      if (t == 0 && b->typing && !b->shown) keyboard(b, b->env, 1);
      if (b->ww && vh && b->fw)
        put(b, 'T', t, (int) (AMotionEvent_getX(e, 0) * (float) b->fw / (float) b->ww),
                       (int) (AMotionEvent_getY(e, 0) * (float) b->fh / (float) vh));
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

/* one horn: the rate, then frames into an AAudio stream until love closes it */
static void *play(void *p) {
  int fd = (int) (long) p; unsigned char r[4]; void *bd = 0, *st = 0; short buf[2048];
  if (!readall(fd, r, 4) && !AAudio_createStreamBuilder(&bd)) {
    AAudioStreamBuilder_setSampleRate(bd, r[0] | r[1] << 8 | r[2] << 16);
    AAudioStreamBuilder_setChannelCount(bd, 2); AAudioStreamBuilder_setFormat(bd, 1);   /* i16 */
    AAudioStreamBuilder_setPerformanceMode(bd, 12);                                     /* low latency */
    if (!AAudioStreamBuilder_openStream(bd, &st) && !AAudioStream_requestStart(st)) {
      ssize_t k, have = 0;
      while ((k = read(fd, (char *) buf + have, sizeof buf - (size_t) have)) > 0) {
        have += k;
        int fr = (int) (have / 4);
        if (fr) AAudioStream_write(st, buf, fr, 1000000000L);
        for (ssize_t i = fr * 4; i < have; i++) ((char *) buf)[i - fr * 4] = ((char *) buf)[i];
        have -= fr * 4;
      }
    }
  }
  if (st) AAudioStream_close(st);
  if (bd) AAudioStreamBuilder_delete(bd);
  close(fd);
  return 0;
}

/* one ear: the rate and channels, then an AAudio input stream's frames until love hangs
   up -- its socket readable, since love says nothing after the rate. a stream refused,
   as before RECORD_AUDIO is granted, is asked again each half second */
static int hung(int fd) { struct pollfd q = {fd, 1, 0}; return poll(&q, 1, 0) != 0; }
static void *hear(void *p) {
  int fd = (int) (long) p; unsigned char r[4]; void *bd = 0, *st = 0; short buf[2048];
  void (*preset)(void *, int) = (void (*)(void *, int)) dlsym(0, "AAudioStreamBuilder_setInputPreset");
  int rate = 0, ch = 1;
  if (!readall(fd, r, 4)) rate = r[0] | r[1] << 8 | r[2] << 16, ch = r[3] == 2 ? 2 : 1;
  while (rate && !st && !hung(fd)) {
    if (!AAudio_createStreamBuilder(&bd)) {
      AAudioStreamBuilder_setDirection(bd, 1);                                  /* input */
      AAudioStreamBuilder_setSampleRate(bd, rate); AAudioStreamBuilder_setChannelCount(bd, ch);
      AAudioStreamBuilder_setFormat(bd, 1); AAudioStreamBuilder_setPerformanceMode(bd, 12);
      if (preset) preset(bd, 9);                                                /* unprocessed: no gain riding */
      if (AAudioStreamBuilder_openStream(bd, &st) || AAudioStream_requestStart(st)) { if (st) AAudioStream_close(st); st = 0; }
      AAudioStreamBuilder_delete(bd);
    }
    if (!st) usleep(500000);
  }
  for (int n; st && (n = AAudioStream_read(st, buf, (int) (sizeof buf / 2) / ch, 100000000L)) >= 0; )
    if (n ? send(fd, buf, (size_t) n * 2 * (size_t) ch, 0x4000) < 0 : hung(fd)) break;   /* MSG_NOSIGNAL */
  if (st) AAudioStream_close(st);
  close(fd);
  return 0;
}

static void *loop(void *p) {
  br *b = p;
  void *const *vt = *(void *const **) b->a->vm;
  int (*attach)(void *, void **, void *) = vt[4]; int (*detach)(void *) = vt[5];
  if (attach(b->a->vm, &b->env, 0)) b->env = 0;
  b->looper = ALooper_prepare(1);
  ALooper_addFd(b->looper, b->lsock, LISTEN, 1, 0, 0);
  ALooper_addFd(b->looper, b->logfd, LOG, 1, 0, 0);
  ALooper_addFd(b->looper, b->hsock, HORN, 1, 0, 0);
  ALooper_addFd(b->looper, b->esock, EAR, 1, 0, 0);
  if (b->queue) AInputQueue_attachLooper(b->queue, b->looper, INPUT, 0, 0);
  while (!b->quit) {
    int fd, ev; void *d;
    int id = ALooper_pollOnce(b->typing ? 200 : -1, &fd, &ev, &d);
    if (b->typing) insets(b);
    if (id == LISTEN) {
      int c = accept4(b->lsock, 0, 0, O_CLOEXEC);
      if (c >= 0 && b->csock < 0) {
        b->csock = c; ALooper_addFd(b->looper, c, CONN, 1, 0, 0);
        if (b->ww) put(b, 'S', 0, b->ww, vis(b));
      } else if (c >= 0) close(c);
    } else if (id == CONN) {
      unsigned char k, on;
      int bad = readall(b->csock, &k, 1);
      if (!bad && k == 'I') {
        bad = readall(b->csock, &on, 1);
        if (!bad) keyboard(b, b->env, b->typing = on);
      } else if (!bad) bad = k != 'F' || frame(b);
      if (bad) {
        ALooper_removeFd(b->looper, b->csock);
        pthread_mutex_lock(b->mu); close(b->csock); b->csock = -1; pthread_mutex_unlock(b->mu);
        ANativeActivity_finish(b->a);
      }
    } else if (id == HORN) {
      long t; int c = accept4(b->hsock, 0, 0, O_CLOEXEC);
      if (c >= 0 && !pthread_create(&t, 0, play, (void *) (long) c)) pthread_detach(t);
      else if (c >= 0) close(c);
    } else if (id == EAR) {
      long t; int c = accept4(b->esock, 0, 0, O_CLOEXEC);
      if (c >= 0 && !pthread_create(&t, 0, hear, (void *) (long) c)) pthread_detach(t);
      else if (c >= 0) close(c);
    } else if (id == LOG) {
      if (logs(b)) ALooper_removeFd(b->looper, b->logfd);
    } else if (id == INPUT) input(b);
  }
  if (b->env) {
    void (*delg)(void *, void *) = (*(void *const **) b->env)[22];
    if (b->kcm) delg(b->env, b->kcm);
    detach(b->a->vm);
  }
  return 0;
}

static void spawn(br *b) {
  char *av[32], exe[600], *ev[6], home[600], tmp[600], face[640], horn[640], ear[640];
  void *as = AAssetManager_open(b->a->assetManager, "argv", 3);
  char const *s = as ? AAsset_getBuffer(as) : 0; long n = as ? AAsset_getLength(as) : 0;
  snprintf(exe, sizeof exe, "%s/liblove.so", b->dir);
  int k = 0; av[k++] = "love";
  for (long i = 0; i < n && k < 31; ) { av[k++] = (char *) s + i; while (i < n && s[i]) i++; i++; }
  av[k] = 0;
  snprintf(home, sizeof home, "HOME=%s", b->data); snprintf(tmp, sizeof tmp, "TMPDIR=%s", b->data);
  snprintf(face, sizeof face, "LOVE_FACE=%s", b->sock); snprintf(horn, sizeof horn, "HORN=sock:%s", b->horn);
  snprintf(ear, sizeof ear, "HORN_IN=sock:%s", b->ear);
  ev[0] = home; ev[1] = tmp; ev[2] = face; ev[3] = horn; ev[4] = ear; ev[5] = 0;
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

/* assets/perms, asked of the user where not granted yet: checkSelfPermission each, then
   one requestPermissions with the rest, through JNIEnv's table */
static void perms(ANativeActivity *a) {
  void *as = AAssetManager_open(a->assetManager, "perms", 3);
  if (!as) return;
  char const *s = AAsset_getBuffer(as), *want[8]; long n = AAsset_getLength(as); int k = 0;
  void *e = a->env; void *const *t = *(void *const **) e;
  void *(*find)(void *, char const *) = t[6]; void (*clear)(void *) = t[17];
  int (*push)(void *, int) = t[19]; void *(*pop)(void *, void *) = t[20];
  void *(*cls)(void *, void *) = t[31]; void *(*mid)(void *, void *, char const *, char const *) = t[33];
  int (*calli)(void *, void *, void *, ...) = t[49]; void (*callv)(void *, void *, void *, ...) = t[61];
  void *(*str)(void *, char const *) = t[167];
  void *(*arr)(void *, int, void *, void *) = t[172]; void (*seta)(void *, void *, int, void *) = t[174];
  if (!push(e, 16)) {
    void *ac = a->clazz, *ck = mid(e, cls(e, ac), "checkSelfPermission", "(Ljava/lang/String;)I");
    if (!ck) clear(e);                    /* a failed lookup leaves NoSuchMethodError pending */
    for (long i = 0; s && ck && i < n && k < 8; i++) {
      char const *p = s + i;
      while (i < n && s[i]) i++;
      if (*p && calli(e, ac, ck, str(e, p))) want[k++] = p;
    }
    void *sc = k ? find(e, "java/lang/String") : 0, *v = sc ? arr(e, k, sc, 0) : 0;
    if (k && !sc) clear(e);
    for (int i = 0; v && i < k; i++) seta(e, v, i, str(e, want[i]));
    void *rq = v ? mid(e, cls(e, ac), "requestPermissions", "([Ljava/lang/String;I)V") : 0;
    if (rq) callv(e, ac, rq, v, 1); else clear(e);
    clear(e); pop(e, 0);
  } else clear(e);
  AAsset_close(as);
}

/* the whole screen: getWindow().getDecorView().setSystemUiVisibility(immersive sticky,
   the bars hidden, laid out under them), through JNIEnv's table -- the spec fixes the slots */
static void immersive(ANativeActivity *a) {
  void *e = a->env; void *const *t = *(void *const **) e;
  void *(*cls)(void *, void *) = t[31];
  void *(*mid)(void *, void *, char const *, char const *) = t[33];
  void *(*callo)(void *, void *, void *, ...) = t[34];
  void (*callv)(void *, void *, void *, ...) = t[61];
  void (*clear)(void *) = t[17];
  void *w = callo(e, a->clazz, mid(e, cls(e, a->clazz), "getWindow", "()Landroid/view/Window;"));
  void *v = w ? callo(e, w, mid(e, cls(e, w), "getDecorView", "()Landroid/view/View;")) : 0;
  if (v) callv(e, v, mid(e, cls(e, v), "setSystemUiVisibility", "(I)V"), 0x1000 | 0x400 | 0x200 | 0x100 | 0x4 | 0x2);
  clear(e);
}
static void focus(void *a, int has) {
  br *b = me(a);
  if (has) immersive(a);
  if (has && b->typing && !b->shown) keyboard(b, ((ANativeActivity *) a)->env, 1);   /* an ask before focus is lost */
}
static void created(void *a, void *w) {
  br *b = me(a);
  ANativeWindow_setBuffersGeometry(w, 0, 0, 1);
  pthread_mutex_lock(b->mu);
  b->win = w; b->ww = ANativeWindow_getWidth(w); b->wh = ANativeWindow_getHeight(w); b->gh = 0;
  paint(b);
  pthread_mutex_unlock(b->mu);
  put(b, 'S', 0, b->ww, vis(b));
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
  close(b->lsock); close(b->hsock); close(b->esock); close(b->logfd); unlink(b->sock); unlink(b->horn); unlink(b->ear);
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
  snprintf(b->horn, sizeof b->horn, "%s/horn", b->data);
  snprintf(b->ear, sizeof b->ear, "%s/ear", b->data);
  b->a = a; b->csock = -1; a->instance = b;
  a->callbacks->onNativeWindowCreated = created; a->callbacks->onNativeWindowDestroyed = gone;
  a->callbacks->onInputQueueCreated = qin; a->callbacks->onInputQueueDestroyed = qout;
  a->callbacks->onDestroy = destroy; a->callbacks->onWindowFocusChanged = focus;
  immersive(a);
  struct sockaddr_un u = {1}; snprintf(u.path, sizeof u.path, "%s", b->sock);
  unlink(b->sock);
  b->lsock = socket(1, 1 | O_CLOEXEC, 0);
  bind(b->lsock, &u, sizeof u); listen(b->lsock, 1);
  struct sockaddr_un hu = {1}; snprintf(hu.path, sizeof hu.path, "%s", b->horn);
  unlink(b->horn);
  b->hsock = socket(1, 1 | O_CLOEXEC, 0);
  bind(b->hsock, &hu, sizeof hu); listen(b->hsock, 2);
  struct sockaddr_un eu = {1}; snprintf(eu.path, sizeof eu.path, "%s", b->ear);
  unlink(b->ear);
  b->esock = socket(1, 1 | O_CLOEXEC, 0);
  bind(b->esock, &eu, sizeof eu); listen(b->esock, 2);
  perms(a);
  lay(b); spawn(b);
  pthread_create(&b->th, 0, loop, b);
}
