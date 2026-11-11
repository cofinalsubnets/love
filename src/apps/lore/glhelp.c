// glhelp -- lore's frames on the system's gpu, a process apart: its gles 3 found through
// dlopen (no gl headers, no -lEGL), so it builds with any cc and links the system's libc alone.
// gpu.l builds it, by mooncc (-shared with a _start, -l:libc.so.6) or by the system's cc, and
// speaks to it a line at a time, the bulk in a tmpfs file both hold.
//   glhelp FILE       FILE the shared bytes; answers "ready RENDERER" or "err WHY"
// then a line each, answered "ok" or "err WHY":
//   tex ID W H L OFF  L levels, each half the last, of 32-bit 0x00rrggbb texels from OFF, rows
//                     top first; a texel below 0 is a hole
//   buf ID NV NT OFF  NV vertices of 8 floats (x y z, u v in texels, r g b; 1.0 the texel as it
//                     is) from OFF, then NT triangles of 4 ints (three vertices and a texture,
//                     below 0 none)
//   drop ID           a buf forgotten
//   under CW CH OFF   for the next frame alone, a smaller frame laid first: CW x CH colours
//                     (32-bit 0x00rrggbb) from OFF, then as many depths (floats, ndc z, 2 none),
//                     rows top first, each pixel the one over it where it drew
//   frame W H OFF CLEAR FR FG FB NEAR FAR TONE FLAGS M0 .. M15 ID ..
//                     the bufs drawn through clip = M * [x y z 1] (row-major), linear fog to
//                     FR FG FB from NEAR to FAR in view depth, exposure TONE (0 none), FLAGS
//                     facets's 8 alone (cull: anticlockwise in gl's y-up faces the eye); W x H
//                     0x00rrggbb pixels to OFF, rows top first, CLEAR where nothing drew, or
//                     with CLEAR below 0 0xff000000 there
//   quit
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int32_t EGLint;
typedef unsigned GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef char GLchar;

enum {
 EGL_PLATFORM_SURFACELESS_MESA = 0x31DD, EGL_SURFACE_TYPE = 0x3033, EGL_PBUFFER_BIT = 1,
 EGL_RENDERABLE_TYPE = 0x3040, EGL_OPENGL_ES3_BIT = 0x40, EGL_NONE = 0x3038,
 EGL_OPENGL_ES_API = 0x30A0, EGL_CONTEXT_MAJOR_VERSION = 0x3098,
 GL_FRAMEBUFFER = 0x8D40, GL_RENDERBUFFER = 0x8D41, GL_RGBA8 = 0x8058, GL_DEPTH_COMPONENT24 = 0x81A6,
 GL_COLOR_ATTACHMENT0 = 0x8CE0, GL_DEPTH_ATTACHMENT = 0x8D00, GL_FRAMEBUFFER_COMPLETE = 0x8CD5,
 GL_VERTEX_SHADER = 0x8B31, GL_FRAGMENT_SHADER = 0x8B30, GL_COMPILE_STATUS = 0x8B81,
 GL_LINK_STATUS = 0x8B82, GL_ARRAY_BUFFER = 0x8892, GL_ELEMENT_ARRAY_BUFFER = 0x8893,
 GL_STATIC_DRAW = 0x88E4, GL_FLOAT = 0x1406, GL_UNSIGNED_INT = 0x1405, GL_TRIANGLES = 4,
 GL_COLOR_BUFFER_BIT = 0x4000, GL_DEPTH_BUFFER_BIT = 0x100, GL_DEPTH_TEST = 0x0B71, GL_LESS = 0x201,
 GL_RGBA = 0x1908, GL_UNSIGNED_BYTE = 0x1401, GL_TEXTURE_2D = 0x0DE1, GL_TEXTURE0 = 0x84C0,
 GL_TEXTURE_MIN_FILTER = 0x2801, GL_TEXTURE_MAG_FILTER = 0x2800, GL_TEXTURE_WRAP_S = 0x2802,
 GL_TEXTURE_WRAP_T = 0x2803, GL_TEXTURE_MAX_LEVEL = 0x813D, GL_NEAREST = 0x2600,
 GL_NEAREST_MIPMAP_NEAREST = 0x2700, GL_REPEAT = 0x2901, GL_RENDERER = 0x1F01,
 GL_CULL_FACE = 0x0B44, GL_BACK = 0x0405, GL_CW = 0x0900, GL_R32F = 0x822E, GL_RED = 0x1903,
 GL_TEXTURE1 = 0x84C1,
 GL_PACK_ALIGNMENT = 0x0D05, GL_UNPACK_ALIGNMENT = 0x0CF5 };

#define EGLFNS(X) \
 X(EGLDisplay, eglGetPlatformDisplay, (GLenum, void *, const intptr_t *)) \
 X(unsigned, eglInitialize, (EGLDisplay, EGLint *, EGLint *)) \
 X(unsigned, eglChooseConfig, (EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *)) \
 X(unsigned, eglBindAPI, (GLenum)) \
 X(EGLContext, eglCreateContext, (EGLDisplay, EGLConfig, EGLContext, const EGLint *)) \
 X(unsigned, eglMakeCurrent, (EGLDisplay, EGLSurface, EGLSurface, EGLContext)) \
 X(void *, eglGetProcAddress, (const char *))
#define GLFNS(X) \
 X(void, glGenFramebuffers, (GLsizei, GLuint *)) X(void, glBindFramebuffer, (GLenum, GLuint)) \
 X(void, glDeleteFramebuffers, (GLsizei, const GLuint *)) \
 X(void, glGenRenderbuffers, (GLsizei, GLuint *)) X(void, glBindRenderbuffer, (GLenum, GLuint)) \
 X(void, glDeleteRenderbuffers, (GLsizei, const GLuint *)) \
 X(void, glRenderbufferStorage, (GLenum, GLenum, GLsizei, GLsizei)) \
 X(void, glFramebufferRenderbuffer, (GLenum, GLenum, GLenum, GLuint)) \
 X(GLenum, glCheckFramebufferStatus, (GLenum)) \
 X(GLuint, glCreateShader, (GLenum)) \
 X(void, glShaderSource, (GLuint, GLsizei, const GLchar *const *, const GLint *)) \
 X(void, glCompileShader, (GLuint)) X(void, glGetShaderiv, (GLuint, GLenum, GLint *)) \
 X(void, glGetShaderInfoLog, (GLuint, GLsizei, GLsizei *, GLchar *)) \
 X(GLuint, glCreateProgram, (void)) X(void, glAttachShader, (GLuint, GLuint)) \
 X(void, glLinkProgram, (GLuint)) X(void, glGetProgramiv, (GLuint, GLenum, GLint *)) \
 X(void, glUseProgram, (GLuint)) \
 X(void, glGenBuffers, (GLsizei, GLuint *)) X(void, glBindBuffer, (GLenum, GLuint)) \
 X(void, glDeleteBuffers, (GLsizei, const GLuint *)) \
 X(void, glBufferData, (GLenum, intptr_t, const void *, GLenum)) \
 X(void, glGenVertexArrays, (GLsizei, GLuint *)) X(void, glBindVertexArray, (GLuint)) \
 X(void, glDeleteVertexArrays, (GLsizei, const GLuint *)) \
 X(void, glVertexAttribPointer, (GLuint, GLint, GLenum, unsigned char, GLsizei, const void *)) \
 X(void, glEnableVertexAttribArray, (GLuint)) \
 X(void, glGenTextures, (GLsizei, GLuint *)) X(void, glBindTexture, (GLenum, GLuint)) \
 X(void, glDeleteTextures, (GLsizei, const GLuint *)) X(void, glActiveTexture, (GLenum)) \
 X(void, glTexImage2D, (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *)) \
 X(void, glTexParameteri, (GLenum, GLenum, GLint)) \
 X(GLint, glGetUniformLocation, (GLuint, const GLchar *)) \
 X(void, glUniform1f, (GLint, GLfloat)) X(void, glUniform1i, (GLint, GLint)) \
 X(void, glUniform2f, (GLint, GLfloat, GLfloat)) X(void, glUniform3f, (GLint, GLfloat, GLfloat, GLfloat)) \
 X(void, glUniformMatrix4fv, (GLint, GLsizei, unsigned char, const GLfloat *)) \
 X(void, glPixelStorei, (GLenum, GLint)) X(void, glEnable, (GLenum)) X(void, glDepthFunc, (GLenum)) \
 X(void, glDisable, (GLenum)) X(void, glCullFace, (GLenum)) X(void, glFrontFace, (GLenum)) \
 X(void, glDrawArrays, (GLenum, GLint, GLsizei)) X(void, glUniform2i, (GLint, GLint, GLint)) \
 X(void, glViewport, (GLint, GLint, GLsizei, GLsizei)) \
 X(void, glClearColor, (GLfloat, GLfloat, GLfloat, GLfloat)) X(void, glClear, (GLbitfield)) \
 X(void, glDrawElements, (GLenum, GLsizei, GLenum, const void *)) \
 X(void, glReadPixels, (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *)) \
 X(const unsigned char *, glGetString, (GLenum))

#define DECL(r, n, a) static r (*n) a;
EGLFNS(DECL)
GLFNS(DECL)

// a texture: its gl name and size; a buf: its vertices and, per texture, a run of indices
struct run { int tex; GLsizei at, n; };
struct tex { int id; GLuint gl; int w, h; };
struct buf { int id; GLuint vao, vb, ib; int nrun; struct run *runs; };
struct helper {
 int fd; size_t sz; unsigned char *map;
 struct tex *texs; int ntex, ctex;
 struct buf *bufs; int nbuf, cbuf;
 GLuint prog, fb, rb, db; int fw, fh;
 GLint u_m, u_tx, u_ts, u_has, u_fog, u_fz, u_tone;
 GLuint uprog, uc, ud; int uw, uh, upend;   // the smaller frame laid first
 GLint uu_cs, uu_fs;
 char line[1 << 16], one[1 << 16]; size_t got; };

static void *need(void *h, const char *n) {
 void *p = h ? dlsym(h, n) : NULL;
 if (!p && eglGetProcAddress) p = eglGetProcAddress(n);
 return p; }

// the shared file, mapped whole again once it has grown
static unsigned char *bytes(struct helper *H, size_t off, size_t n) {
 struct stat st;
 if (fstat(H->fd, &st) < 0) return NULL;
 if ((size_t) st.st_size != H->sz) {
  if (H->map) munmap(H->map, H->sz);
  H->sz = (size_t) st.st_size;
  H->map = H->sz ? mmap(NULL, H->sz, PROT_READ | PROT_WRITE, MAP_SHARED, H->fd, 0) : NULL;
  if (H->map == MAP_FAILED) H->map = NULL, H->sz = 0; }
 return H->map && off <= H->sz && n <= H->sz - off ? H->map + off : NULL; }

static GLuint shader(GLenum k, const char *src) {
 GLuint s = glCreateShader(k); GLint ok = 0;
 glShaderSource(s, 1, &src, NULL); glCompileShader(s); glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
 if (!ok) { char log[512]; glGetShaderInfoLog(s, sizeof log, NULL, log); dprintf(1, "err shader %s\n", log); return 0; }
 return s; }

// rows run top first: y flips in clip. the colour is the vertex's times 255 times the texel,
// fogged by view depth, then exposed; written b g r so the bytes read back are 0x00rrggbb
static char const vsrc[] =
 "#version 300 es\n"
 "layout(location=0) in vec3 p; layout(location=1) in vec2 t; layout(location=2) in vec3 c;\n"
 "uniform mat4 m; out vec2 uv; out vec3 col; out float w;\n"
 "void main(){ vec4 q = m * vec4(p, 1.0); uv = t; col = c; w = q.w; gl_Position = vec4(q.x, -q.y, q.z, q.w); }\n";
static char const fsrc[] =
 "#version 300 es\n"
 "precision highp float; in vec2 uv; in vec3 col; in float w;\n"
 "uniform sampler2D tx; uniform vec2 ts; uniform int has; uniform vec3 fog; uniform vec2 fz; uniform float tone;\n"
 "out vec4 o;\n"
 "void main(){ vec3 c = col * 255.0;\n"
 " if (has != 0) { vec4 k = texture(tx, uv / ts); if (k.a < 0.5) discard; c *= k.rgb; }\n"
 " if (fz.y > 0.0) c += (fog - c) * clamp((w - fz.x) * fz.y, 0.0, 1.0);\n"
 " if (tone > 0.0) c = 255.0 * (1.0 - exp(-tone * c / 255.0));\n"
 " c = clamp(c / 255.0, 0.0, 1.0); o = vec4(c.b, c.g, c.r, 0.0); }\n";

// the smaller frame: one triangle over the whole frame, each pixel its own of the smaller's,
// as facets picks it, its colour and its depth; where the smaller drew nothing, nothing
static char const uvsrc[] =
 "#version 300 es\n"
 "void main(){ vec2 p = vec2(gl_VertexID == 1 ? 3.0 : -1.0, gl_VertexID == 2 ? 3.0 : -1.0); gl_Position = vec4(p, 0.0, 1.0); }\n";
static char const ufsrc[] =
 "#version 300 es\n"
 "precision highp float; uniform highp sampler2D cc; uniform highp sampler2D cd; uniform ivec2 cs; uniform ivec2 fs;\n"
 "out vec4 o;\n"
 "void main(){ ivec2 p = ivec2(gl_FragCoord.xy), q = ivec2(p.x * cs.x / fs.x, p.y * cs.y / fs.y);\n"
 " float d = texelFetch(cd, q, 0).r; if (d >= 2.0) discard;\n"
 " vec4 k = texelFetch(cc, q, 0); o = vec4(k.b, k.g, k.r, 0.0); gl_FragDepth = clamp(d * 0.5 + 0.5, 0.0, 1.0); }\n";

static GLuint program(GLuint vs, GLuint fs) {
 GLuint p = glCreateProgram(); GLint ok = 0;
 glAttachShader(p, vs); glAttachShader(p, fs); glLinkProgram(p); glGetProgramiv(p, GL_LINK_STATUS, &ok);
 return ok ? p : 0; }

static int setup(struct helper *H) {
 void *egl = dlopen("libEGL.so.1", RTLD_NOW), *gl = dlopen("libGLESv2.so.2", RTLD_NOW);
 if (!egl || !gl) { dprintf(1, "err no gles: %s\n", dlerror()); return 0; }
#define LOADE(r, n, a) if (!(n = (r (*) a) need(egl, #n))) { dprintf(1, "err no %s\n", #n); return 0; }
#define LOADG(r, n, a) if (!(n = (r (*) a) need(gl, #n))) { dprintf(1, "err no %s\n", #n); return 0; }
 EGLFNS(LOADE)
 GLFNS(LOADG)
 EGLDisplay d = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, NULL, NULL);
 EGLint ma, mi, n = 0;
 if (!d || !eglInitialize(d, &ma, &mi)) { dprintf(1, "err no egl display\n"); return 0; }
 EGLint ca[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_NONE };
 EGLConfig cf = NULL;
 eglChooseConfig(d, ca, &cf, 1, &n);
 eglBindAPI(EGL_OPENGL_ES_API);
 EGLint xa[] = { EGL_CONTEXT_MAJOR_VERSION, 3, EGL_NONE };
 EGLContext c = eglCreateContext(d, n ? cf : NULL, NULL, xa);
 if (!c || !eglMakeCurrent(d, NULL, NULL, c)) { dprintf(1, "err no gles 3 context\n"); return 0; }
 GLuint vs = shader(GL_VERTEX_SHADER, vsrc), fs = shader(GL_FRAGMENT_SHADER, fsrc);
 if (!vs || !fs) return 0;
 GLuint uvs = shader(GL_VERTEX_SHADER, uvsrc), ufs = shader(GL_FRAGMENT_SHADER, ufsrc);
 if (!uvs || !ufs) return 0;
 if (!(H->prog = program(vs, fs)) || !(H->uprog = program(uvs, ufs))) { dprintf(1, "err link\n"); return 0; }
 glUseProgram(H->uprog);
 glUniform1i(glGetUniformLocation(H->uprog, "cc"), 0); glUniform1i(glGetUniformLocation(H->uprog, "cd"), 1);
 H->uu_cs = glGetUniformLocation(H->uprog, "cs"); H->uu_fs = glGetUniformLocation(H->uprog, "fs");
 glUseProgram(H->prog);
 H->u_m = glGetUniformLocation(H->prog, "m"); H->u_tx = glGetUniformLocation(H->prog, "tx");
 H->u_ts = glGetUniformLocation(H->prog, "ts"); H->u_has = glGetUniformLocation(H->prog, "has");
 H->u_fog = glGetUniformLocation(H->prog, "fog"); H->u_fz = glGetUniformLocation(H->prog, "fz");
 H->u_tone = glGetUniformLocation(H->prog, "tone");
 glUniform1i(H->u_tx, 0);
 glPixelStorei(GL_PACK_ALIGNMENT, 4); glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
 glEnable(GL_DEPTH_TEST); glDepthFunc(GL_LESS);
 dprintf(1, "ready %s\n", glGetString(GL_RENDERER));
 return 1; }

static struct tex *tex_of(struct helper *H, int id) {
 for (int i = 0; i < H->ntex; i++) if (H->texs[i].id == id) return H->texs + i;
 return NULL; }
static struct buf *buf_of(struct helper *H, int id) {
 for (int i = 0; i < H->nbuf; i++) if (H->bufs[i].id == id) return H->bufs + i;
 return NULL; }

static void *grow(void *p, int *cap, int n, size_t each) {
 if (n < *cap) return p;
 int c = *cap ? 2 * *cap : 16;
 void *q = realloc(p, (size_t) c * each);
 if (q) *cap = c;
 return q; }

// texels 0x00rrggbb, a hole below 0 -> rgba bytes, its alpha 0
static void texels(unsigned char *o, unsigned char const *p, size_t n) {
 for (size_t i = 0; i < n; i++) {
  int32_t v; memcpy(&v, p + 4 * i, 4);
  o[4*i] = (unsigned char) (v >> 16), o[4*i+1] = (unsigned char) (v >> 8), o[4*i+2] = (unsigned char) v,
  o[4*i+3] = v < 0 ? 0 : 255; } }

static void cmd_tex(struct helper *H, int id, int w, int h, int L, size_t off) {
 if (w < 1 || h < 1 || L < 1 || L > 16) { dprintf(1, "err tex size\n"); return; }
 size_t n = 0;
 for (int l = 0, lw = w, lh = h; l < L; l++, lw = lw > 1 ? lw / 2 : 1, lh = lh > 1 ? lh / 2 : 1) n += (size_t) lw * lh;
 unsigned char const *p = bytes(H, off, 4 * n);
 unsigned char *rgba = p ? malloc(4 * (size_t) w * h) : NULL;
 if (!rgba) { dprintf(1, "err tex bytes\n"); return; }
 struct tex *t = tex_of(H, id);
 if (!t) {
  H->texs = grow(H->texs, &H->ctex, H->ntex, sizeof *H->texs);
  t = H->texs + H->ntex++; t->id = id; glGenTextures(1, &t->gl); }
 t->w = w, t->h = h;
 glBindTexture(GL_TEXTURE_2D, t->gl);
 for (int l = 0, lw = w, lh = h; l < L; l++, p += 4 * (size_t) lw * lh, lw = lw > 1 ? lw / 2 : 1, lh = lh > 1 ? lh / 2 : 1) {
  texels(rgba, p, (size_t) lw * lh);
  glTexImage2D(GL_TEXTURE_2D, l, GL_RGBA8, lw, lh, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba); }
 free(rgba);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, L - 1);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, L > 1 ? GL_NEAREST_MIPMAP_NEAREST : GL_NEAREST);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
 dprintf(1, "ok\n"); }

static void buf_free(struct buf *b) {
 glDeleteVertexArrays(1, &b->vao); glDeleteBuffers(1, &b->vb); glDeleteBuffers(1, &b->ib);
 free(b->runs); b->runs = NULL; b->nrun = 0; }

static int bytex(void const *a, void const *b) {
 int32_t x, y; memcpy(&x, (char const*) a + 12, 4); memcpy(&y, (char const*) b + 12, 4);
 return (x > y) - (x < y); }

// the triangles sorted by texture, each texture's a run of the index buffer
static void cmd_buf(struct helper *H, int id, int nv, int nt, size_t off) {
 if (nv < 0 || nt < 0) { dprintf(1, "err buf size\n"); return; }
 unsigned char const *p = bytes(H, off, 32 * (size_t) nv + 16 * (size_t) nt);
 int32_t *tr = p ? malloc(16 * (size_t) nt + 1) : NULL;
 uint32_t *ix = tr ? malloc(12 * (size_t) nt + 1) : NULL;
 struct run *runs = ix ? malloc(sizeof *runs * ((size_t) nt + 1)) : NULL;
 if (!runs) { free(tr); free(ix); dprintf(1, "err buf bytes\n"); return; }
 memcpy(tr, p + 32 * (size_t) nv, 16 * (size_t) nt);
 qsort(tr, (size_t) nt, 16, bytex);
 int nrun = 0;
 for (int i = 0; i < nt; i++) {
  int32_t *t = tr + 4 * i;
  if (t[0] < 0 || t[0] >= nv || t[1] < 0 || t[1] >= nv || t[2] < 0 || t[2] >= nv) {
   free(tr); free(ix); free(runs); dprintf(1, "err buf vertex past the end\n"); return; }
  if (!nrun || runs[nrun - 1].tex != t[3]) runs[nrun++] = (struct run) { t[3], 3 * i, 0 };
  runs[nrun - 1].n += 3;
  ix[3*i] = (uint32_t) t[0], ix[3*i+1] = (uint32_t) t[1], ix[3*i+2] = (uint32_t) t[2]; }
 struct buf *b = buf_of(H, id);
 if (b) buf_free(b);
 else { H->bufs = grow(H->bufs, &H->cbuf, H->nbuf, sizeof *H->bufs); b = H->bufs + H->nbuf++; b->id = id; }
 glGenVertexArrays(1, &b->vao); glBindVertexArray(b->vao);
 glGenBuffers(1, &b->vb); glBindBuffer(GL_ARRAY_BUFFER, b->vb);
 glBufferData(GL_ARRAY_BUFFER, 32 * (intptr_t) nv, p, GL_STATIC_DRAW);
 glVertexAttribPointer(0, 3, GL_FLOAT, 0, 32, (void*) 0); glEnableVertexAttribArray(0);
 glVertexAttribPointer(1, 2, GL_FLOAT, 0, 32, (void*) 12); glEnableVertexAttribArray(1);
 glVertexAttribPointer(2, 3, GL_FLOAT, 0, 32, (void*) 20); glEnableVertexAttribArray(2);
 glGenBuffers(1, &b->ib); glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, b->ib);
 glBufferData(GL_ELEMENT_ARRAY_BUFFER, 12 * (intptr_t) nt, ix, GL_STATIC_DRAW);
 glBindVertexArray(0);
 free(tr); free(ix);
 b->runs = runs, b->nrun = nrun;
 dprintf(1, "ok\n"); }

static void cmd_under(struct helper *H, int cw, int ch, size_t off) {
 if (cw < 1 || ch < 1) { dprintf(1, "err under size\n"); return; }
 size_t n = (size_t) cw * ch;
 unsigned char const *p = bytes(H, off, 8 * n);
 unsigned char *rgba = p ? malloc(4 * n) : NULL;
 if (!rgba) { dprintf(1, "err under bytes\n"); return; }
 if (!H->uc) {
  GLuint t[2]; glGenTextures(2, t); H->uc = t[0], H->ud = t[1];
  for (int i = 0; i < 2; i++) {
   glBindTexture(GL_TEXTURE_2D, t[i]);
   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); } }
 texels(rgba, p, n);
 glBindTexture(GL_TEXTURE_2D, H->uc); glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, cw, ch, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
 glBindTexture(GL_TEXTURE_2D, H->ud); glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, cw, ch, 0, GL_RED, GL_FLOAT, p + 4 * n);
 free(rgba);
 H->uw = cw, H->uh = ch, H->upend = 1;
 dprintf(1, "ok\n"); }

static void cmd_drop(struct helper *H, int id) {
 struct buf *b = buf_of(H, id);
 if (b) buf_free(b), *b = H->bufs[--H->nbuf];
 dprintf(1, "ok\n"); }

static int target(struct helper *H, int w, int h) {
 if (w == H->fw && h == H->fh) return 1;
 if (H->fb) glDeleteFramebuffers(1, &H->fb), glDeleteRenderbuffers(1, &H->rb), glDeleteRenderbuffers(1, &H->db);
 glGenFramebuffers(1, &H->fb); glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
 glGenRenderbuffers(1, &H->rb); glBindRenderbuffer(GL_RENDERBUFFER, H->rb);
 glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, w, h);
 glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, H->rb);
 glGenRenderbuffers(1, &H->db); glBindRenderbuffer(GL_RENDERBUFFER, H->db);
 glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
 glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, H->db);
 if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->fw = H->fh = 0; return 0; }
 H->fw = w, H->fh = h;
 return 1; }

// the words of a line, numbers all
static int words(char *s, double *v, int max) {
 int n = 0;
 while (*s && n < max) {
  while (*s == ' ') s++;
  if (!*s) break;
  char *e; v[n++] = strtod(s, &e);
  if (e == s) return -1;
  s = e; }
 return n; }

static void cmd_frame(struct helper *H, char *args) {
 enum { lead = 27 };   // w h off clear fr fg fb near far tone flags, then the 16 of m
 double v[lead + 4096];
 int n = words(args, v, lead + 4096);
 if (n < lead) { dprintf(1, "err frame args\n"); return; }
 int w = (int) v[0], h = (int) v[1];
 unsigned char *out = w > 0 && h > 0 ? bytes(H, (size_t) v[2], 4 * (size_t) w * h) : NULL;
 if (!out || !target(H, w, h)) { dprintf(1, "err frame target\n"); return; }
 int32_t clear = (int32_t) v[3];
 glViewport(0, 0, w, h);
 if (clear < 0) glClearColor(0, 0, 0, 1);
 else glClearColor((float) (clear & 255) / 255, (float) (clear >> 8 & 255) / 255, (float) (clear >> 16 & 255) / 255, 0);
 glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
 glDisable(GL_CULL_FACE);
 if (H->upend) {
  glUseProgram(H->uprog);
  glUniform2i(H->uu_cs, H->uw, H->uh); glUniform2i(H->uu_fs, w, h);
  glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, H->ud);
  glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, H->uc);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  H->upend = 0; }
 // y flips in clip, so what faces the eye winds clockwise here
 if ((int) v[10] & 8) glEnable(GL_CULL_FACE), glCullFace(GL_BACK), glFrontFace(GL_CW);
 glUseProgram(H->prog);
 float m[16];
 for (int i = 0; i < 16; i++) m[i] = (float) v[11 + i];
 glUniformMatrix4fv(H->u_m, 1, 1, m);   // row-major, so transposed
 glUniform3f(H->u_fog, (float) v[4], (float) v[5], (float) v[6]);
 glUniform2f(H->u_fz, (float) v[7], v[8] > v[7] ? (float) (1 / (v[8] - v[7])) : 0);
 glUniform1f(H->u_tone, (float) v[9]);
 glActiveTexture(GL_TEXTURE0);
 for (int k = lead; k < n; k++) {
  struct buf *b = buf_of(H, (int) v[k]);
  if (!b) continue;
  glBindVertexArray(b->vao);
  for (int r = 0; r < b->nrun; r++) {
   struct tex *t = b->runs[r].tex >= 0 ? tex_of(H, b->runs[r].tex) : NULL;
   glUniform1i(H->u_has, t != NULL);
   if (t) glBindTexture(GL_TEXTURE_2D, t->gl), glUniform2f(H->u_ts, (float) t->w, (float) t->h);
   glDrawElements(GL_TRIANGLES, b->runs[r].n, GL_UNSIGNED_INT, (void*) (4 * (uintptr_t) b->runs[r].at)); } }
 glBindVertexArray(0);
 glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, out);
 dprintf(1, "ok\n"); }

// a line from fd 0, its newline gone; 0 at the end
static char *next_line(struct helper *H) {
 for (;;) {
  char *nl = memchr(H->line, '\n', H->got);
  if (nl) {
   *nl = 0;
   size_t k = (size_t) (nl - H->line) + 1;
   memcpy(H->one, H->line, k);
   memmove(H->line, H->line + k, H->got - k), H->got -= k;
   return H->one; }
  if (H->got == sizeof H->line) H->got = 0;   // a line past the buffer is dropped
  ssize_t r = read(0, H->line + H->got, sizeof H->line - H->got);
  if (r <= 0) return NULL;
  H->got += (size_t) r; } }

int glhelp_main(int argc, char **argv) {
 struct helper *H = calloc(1, sizeof *H);
 if (!H) { dprintf(1, "err no memory\n"); return 2; }
 if (argc < 2) { dprintf(1, "err usage: glhelp FILE\n"); return 2; }
 H->fd = open(argv[1], O_RDWR | O_CLOEXEC);
 if (H->fd < 0) { dprintf(1, "err cannot open %s\n", argv[1]); return 2; }
 if (!setup(H)) return 3;
 for (char *l; (l = next_line(H)); ) {
  int id, a, b, c; long off;
  if (!strncmp(l, "tex ", 4) && sscanf(l + 4, "%d %d %d %d %ld", &id, &a, &b, &c, &off) == 5) cmd_tex(H, id, a, b, c, (size_t) off);
  else if (!strncmp(l, "buf ", 4) && sscanf(l + 4, "%d %d %d %ld", &id, &a, &b, &off) == 4) cmd_buf(H, id, a, b, (size_t) off);
  else if (!strncmp(l, "drop ", 5) && sscanf(l + 5, "%d", &id) == 1) cmd_drop(H, id);
  else if (!strncmp(l, "under ", 6) && sscanf(l + 6, "%d %d %ld", &a, &b, &off) == 3) cmd_under(H, a, b, (size_t) off);
  else if (!strncmp(l, "frame ", 6)) cmd_frame(H, l + 6);
  else if (!strcmp(l, "quit")) break;
  else dprintf(1, "err what: %s\n", l); }
 return 0; }

// built by mooncc, the loader runs the object itself: its entry hands argc and argv on
#ifdef __mooncc__
#if defined(__x86_64__)
__asm__(".globl _start\n_start:\n xor %ebp,%ebp\n mov (%rsp),%rdi\n lea 8(%rsp),%rsi\n and $-16,%rsp\n"
        " call glhelp_main\n mov %eax,%edi\n call exit\n hlt\n");
#elif defined(__aarch64__)
__asm__(".globl _start\n_start:\n mov x29, #0\n ldr x0, [sp]\n add x1, sp, #8\n bl glhelp_main\n bl exit\n");
#endif
#else
int main(int argc, char **argv) { return glhelp_main(argc, argv); }
#endif
