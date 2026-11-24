// glhelp -- lore's frames on the system's gpu, a process apart: its gles 3 found through
// dlopen (no gl headers, no -lEGL), so it builds with any cc and links the system's libc alone.
// gpu.l builds it, by mooncc (-dynamic-linker, the system's libc) or by the system's cc, and
// speaks to it a line at a time, the bulk in a tmpfs file both hold. built with -D GLHELP_IN,
// glhelp_serve speaks the same in an app's own process, on the window it holds (the droid bridge).
//   glhelp FILE       FILE the shared bytes; answers "ready RENDERER" or "err WHY"
// then a line each, answered "ok" or "err WHY":
//   tex ID W H L OFF  L levels, each half the last, of 32-bit 0x00rrggbb texels from OFF, rows
//                     top first; a texel below 0 is a hole
//   buf ID NV NT OFF [S]  NV vertices of S floats, 8 or 11 (x y z, u v in texels, r g b; 1.0 the
//                     texel as it is; then the sun's r g b, as much as it reaches) from OFF,
//                     then NT triangles of 4 ints (three vertices and facets's
//                     texture: -1 none, -2 a glow, -3 - t a glass of t, a pane's class or a
//                     lens as facets has them), drawn in their order
//   drop ID           a buf forgotten
//   place ID X Y Z ..  each buf ID drawn moved by X Y Z, kept until it is laid again
//   lamps ID NV OFF L0 .. L7
//                     buf ID's lamps: NV vertices of 24 floats from OFF, 8 slots of r g b, slot k
//                     the light lamp LK gives it at full strength
//   suns ID NV OFF     buf ID's sun: NV vertices of 3 floats from OFF, its colour that is the sun's
//   ks K ..           the lamps' strengths, each slot's light times its lamp's added to the colour
//   scene N OFF       the scene, kept: N bufs, each 9 floats from OFF: its id, the ball it lies
//                     in, x y z r, a light L and weight W, its colours times W times light L's
//                     strength, L below 0 as they are, its group G, and a mark M; a frame's id
//                     -9 - G draws those of G the frame sees there, nearest first, but one
//                     whose light is out or whose mark is down
//   vis N K OFF       kept: N marks, floats from OFF, mark M down where the M-th is 0 (one
//                     below 0 or past them never), then K lights' strengths
//   base OFF          for the next frame alone, its ground: W x H colours from OFF, rows top
//                     first, below 0 bare
//   under CW CH OFF   for the next frame alone, a smaller frame laid first: CW x CH colours
//                     (32-bit 0x00rrggbb) from OFF, then as many depths (floats, ndc z, 2 none),
//                     rows top first, each pixel the one over it where it drew
//   sun SW SH OFF BIAS L0 .. L15
//                     the sun's view, kept: its depths, SW x SH floats from OFF rows top first,
//                     2 none, and its matrix, row-major, the depths asked less BIAS
//   cloud N OFF       the sky's cloud map, kept: N by N floats from OFF, rows first
//   air W H OFF       the sky's air table, kept: W by H colours of three floats, rows first
//   skyp K ..         the next frames' sky asked a pixel at a time, as sky.l's sky-colour-at
//                     asks it: sky-gpu's numbers, then the view's right, up and ahead, its focal
//                     length in pixels, the radians between pixels, its width and height
//   sky ID TONE [EX EY EZ]
//                     the next frame's sky: buf ID drawn last, only where the frame is bare,
//                     exposed by TONE, onto a glow kept there or through a glass's tint; its
//                     u an edge, as facets's flag 256 takes it; its places from the eye at E.
//                     ID -1 asks it a pixel at a time, by skyp's numbers and the cloud map
//   spots W H NS OFF  the next frame's spots, W by H, as show takes them: NS pixels' indices
//                     then their words, floats at OFF, laid in its sky in the sky's stead
//   glow RX RY RZ UX UY UZ ZN ZF LEAD SOFT
//                     the next frame's glows as facets has them: a buf all glow turned to face
//                     the eye, each vertex u along R and v along U; a glow seen as much as what is
//                     behind it lies past it less LEAD, over SOFT, ZN ZF the view's near and far
//   frame W H OFF CLEAR FR FG FB NEAR FAR TONE FLAGS M0 .. M15 ID ..
//                     the bufs drawn through clip = M * [x y z 1] (row-major), linear fog to
//                     FR FG FB from NEAR to FAR in view depth, exposure TONE (0 none), FLAGS
//                     facets's 8 and 128 (cull: anticlockwise in gl's y-up faces the eye; seen,
//                     the lenses' nearest depths asked first), and 256, the sun's view asked
//                     as facets asks it; W x H
//                     of facets's words to OFF, rows top first, each 8 bytes. an ID -9 - G is scene group G.
//                     CLEAR is the ground, or with CLEAR below 0 bare
//   quit
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int32_t EGLint;
typedef unsigned GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef char GLchar;

enum {
 EGL_PLATFORM_SURFACELESS_MESA = 0x31DD, EGL_PLATFORM_X11_KHR = 0x31D5, EGL_SURFACE_TYPE = 0x3033, EGL_PBUFFER_BIT = 1, EGL_WINDOW_BIT = 4,
 EGL_RENDERABLE_TYPE = 0x3040, EGL_OPENGL_ES3_BIT = 0x40, EGL_NONE = 0x3038,
 EGL_RED_SIZE = 0x3024, EGL_GREEN_SIZE = 0x3023, EGL_BLUE_SIZE = 0x3022,
 EGL_OPENGL_ES_API = 0x30A0, EGL_WIDTH = 0x3057, EGL_HEIGHT = 0x3056, EGL_CONTEXT_MAJOR_VERSION = 0x3098,
 GL_FRAMEBUFFER = 0x8D40, GL_RENDERBUFFER = 0x8D41, GL_RGBA8 = 0x8058, GL_DEPTH_COMPONENT24 = 0x81A6,
 GL_COLOR_ATTACHMENT0 = 0x8CE0, GL_DEPTH_ATTACHMENT = 0x8D00, GL_FRAMEBUFFER_COMPLETE = 0x8CD5,
 GL_VERTEX_SHADER = 0x8B31, GL_FRAGMENT_SHADER = 0x8B30, GL_COMPILE_STATUS = 0x8B81,
 GL_LINK_STATUS = 0x8B82, GL_ARRAY_BUFFER = 0x8892, GL_ELEMENT_ARRAY_BUFFER = 0x8893,
 GL_STATIC_DRAW = 0x88E4, GL_FLOAT = 0x1406, GL_UNSIGNED_INT = 0x1405, GL_TRIANGLES = 4,
 GL_COLOR_BUFFER_BIT = 0x4000, GL_DEPTH_BUFFER_BIT = 0x100, GL_DEPTH_TEST = 0x0B71, GL_LESS = 0x201, GL_ALWAYS = 0x207,
 GL_RGBA = 0x1908, GL_UNSIGNED_BYTE = 0x1401, GL_TEXTURE_2D = 0x0DE1, GL_TEXTURE0 = 0x84C0,
 GL_TEXTURE_MIN_FILTER = 0x2801, GL_TEXTURE_MAG_FILTER = 0x2800, GL_TEXTURE_WRAP_S = 0x2802,
 GL_TEXTURE_WRAP_T = 0x2803, GL_TEXTURE_MAX_LEVEL = 0x813D, GL_NEAREST = 0x2600,
 GL_NEAREST_MIPMAP_NEAREST = 0x2700, GL_REPEAT = 0x2901, GL_RENDERER = 0x1F01,
 GL_CULL_FACE = 0x0B44, GL_BACK = 0x0405, GL_CW = 0x0900, GL_R32F = 0x822E, GL_RED = 0x1903,
 GL_TEXTURE6 = 0x84C6, GL_TEXTURE7 = 0x84C7, GL_TEXTURE8 = 0x84C8, GL_TEXTURE9 = 0x84C9, GL_RGB32F = 0x8815, GL_RGB = 0x1907, GL_READ_FRAMEBUFFER = 0x8CA8, GL_DRAW_FRAMEBUFFER = 0x8CA9,
 GL_TEXTURE1 = 0x84C1, GL_TEXTURE3 = 0x84C3, GL_TEXTURE4 = 0x84C4, GL_TEXTURE5 = 0x84C5, GL_RGBA32F = 0x8814, GL_TEXTURE2 = 0x84C2, GL_DEPTH_COMPONENT32F = 0x8CAC, GL_DEPTH_COMPONENT = 0x1902, GL_BLEND = 0x0BE2, GL_ONE = 1, GL_ZERO = 0, GL_DST_ALPHA = 0x0304 , GL_SRC_COLOR = 0x0300, GL_SRC_ALPHA = 0x0302,
 GL_SRC1_COLOR = 0x88F9, GL_SRC1_ALPHA = 0x8589, GL_COLOR = 0x1800, GL_FUNC_ADD = 0x8006, GL_MAX = 0x8008,
 GL_PACK_ALIGNMENT = 0x0D05, GL_UNPACK_ALIGNMENT = 0x0CF5, GL_CLAMP_TO_EDGE = 0x812F, GL_LINEAR = 0x2601, GL_SCISSOR_TEST = 0x0C11, GL_ANY_SAMPLES_PASSED = 0x8C2F, GL_QUERY_RESULT = 0x8866, GL_POINTS = 0 };

#define EGLFNS(X) \
 X(unsigned, eglInitialize, (EGLDisplay, EGLint *, EGLint *)) \
 X(unsigned, eglChooseConfig, (EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *)) \
 X(unsigned, eglBindAPI, (GLenum)) \
 X(EGLContext, eglCreateContext, (EGLDisplay, EGLConfig, EGLContext, const EGLint *)) \
 X(unsigned, eglMakeCurrent, (EGLDisplay, EGLSurface, EGLSurface, EGLContext)) \
 X(EGLDisplay, eglGetDisplay, (void *)) \
 X(EGLSurface, eglCreatePbufferSurface, (EGLDisplay, EGLConfig, const EGLint *)) \
 X(EGLSurface, eglCreateWindowSurface, (EGLDisplay, EGLConfig, void *, const EGLint *)) \
 X(unsigned, eglSwapBuffers, (EGLDisplay, EGLSurface)) X(unsigned, eglSwapInterval, (EGLDisplay, EGLint)) \
 X(unsigned, eglDestroySurface, (EGLDisplay, EGLSurface)) X(unsigned, eglTerminate, (EGLDisplay)) \
 X(unsigned, eglQuerySurface, (EGLDisplay, EGLSurface, EGLint, EGLint *)) X(unsigned, eglDestroyContext, (EGLDisplay, EGLContext)) \
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
 X(void, glBufferSubData, (GLenum, intptr_t, intptr_t, const void *)) \
 X(void, glGenVertexArrays, (GLsizei, GLuint *)) X(void, glBindVertexArray, (GLuint)) \
 X(void, glDeleteVertexArrays, (GLsizei, const GLuint *)) \
 X(void, glVertexAttribPointer, (GLuint, GLint, GLenum, unsigned char, GLsizei, const void *)) \
 X(void, glEnableVertexAttribArray, (GLuint)) \
 X(void, glDisableVertexAttribArray, (GLuint)) \
 X(void, glGenTextures, (GLsizei, GLuint *)) X(void, glBindTexture, (GLenum, GLuint)) \
 X(void, glDeleteTextures, (GLsizei, const GLuint *)) X(void, glActiveTexture, (GLenum)) \
 X(void, glTexImage2D, (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *)) \
 X(void, glTexParameteri, (GLenum, GLenum, GLint)) \
 X(GLint, glGetUniformLocation, (GLuint, const GLchar *)) \
 X(void, glUniform1f, (GLint, GLfloat)) X(void, glUniform1i, (GLint, GLint)) \
 X(void, glUniform1fv, (GLint, GLsizei, const GLfloat *)) X(void, glUniform1iv, (GLint, GLsizei, const GLint *)) \
 X(void, glUniform2f, (GLint, GLfloat, GLfloat)) X(void, glUniform3f, (GLint, GLfloat, GLfloat, GLfloat)) \
 X(void, glUniform4f, (GLint, GLfloat, GLfloat, GLfloat, GLfloat)) X(void, glScissor, (GLint, GLint, GLsizei, GLsizei)) \
 X(void, glUniformMatrix4fv, (GLint, GLsizei, unsigned char, const GLfloat *)) \
 X(void, glPixelStorei, (GLenum, GLint)) X(void, glEnable, (GLenum)) X(void, glDepthFunc, (GLenum)) \
 X(void, glDisable, (GLenum)) X(void, glCullFace, (GLenum)) X(void, glFrontFace, (GLenum)) \
 X(void, glDrawArrays, (GLenum, GLint, GLsizei)) X(void, glUniform2i, (GLint, GLint, GLint)) \
 X(void, glBlendFuncSeparate, (GLenum, GLenum, GLenum, GLenum)) X(void, glDepthMask, (unsigned char)) \
 X(void, glFramebufferTexture2D, (GLenum, GLenum, GLenum, GLuint, GLint)) \
 X(void, glCopyTexSubImage2D, (GLenum, GLint, GLint, GLint, GLint, GLint, GLsizei, GLsizei)) \
 X(void, glBlitFramebuffer, (GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLbitfield, GLenum)) \
 X(void, glClearBufferfv, (GLenum, GLint, const GLfloat *)) X(void, glBlendEquationSeparate, (GLenum, GLenum)) \
 X(void, glColorMask, (unsigned char, unsigned char, unsigned char, unsigned char)) \
 X(void, glViewport, (GLint, GLint, GLsizei, GLsizei)) \
 X(void, glClearColor, (GLfloat, GLfloat, GLfloat, GLfloat)) X(void, glClear, (GLbitfield)) \
 X(void, glDrawElements, (GLenum, GLsizei, GLenum, const void *)) \
 X(void, glReadPixels, (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *)) \
 X(void, glGenQueries, (GLsizei, GLuint *)) X(void, glBeginQuery, (GLenum, GLuint)) X(void, glEndQuery, (GLenum)) \
 X(void, glGetQueryObjectuiv, (GLuint, GLenum, GLuint *)) \
 X(const unsigned char *, glGetString, (GLenum))

#define DECL(r, n, a) static r (*n) a;
EGLFNS(DECL)
GLFNS(DECL)
static EGLDisplay (*eglGetPlatformDisplay) (GLenum, void *, const intptr_t *);   // egl 1.5: not before android 10
// ..a 32-bit libc's off_t is its own width, not our headers': its 64-bit names take a long long
static long long (*seek64) (int, long long, int);
static void *(*map64) (void *, size_t, int, int, int, long long);

// a texture: its gl name and size; a buf: its vertices and, per texture, a run of indices
struct run { int tex; GLsizei at, n; };
struct tex { int id; GLuint gl; int w, h; };
struct buf { int id, nv, S, glow; GLuint vao, vb, ib, lb, sb; int nrun; struct run *runs; int li[8]; float off[3]; };   // glow: its runs all glow; lb its lamps', sb its sun's; off where it is moved
struct seen { float w, k; int id; };
struct helper {
 int fd; size_t sz; unsigned char *map;
 struct tex *texs; int ntex, ctex;
 struct buf *bufs; int nbuf, cbuf;
 GLuint prog, fb, rb, db, gb, gr; int fw, fh, dual, fglass;   // gb gr: glass's on what is bare, in floats where they blend
 unsigned char *gx;   // ..read back; rb and gr textures, which the sky asks
 GLuint mk; int sky, spend; float stone, soff[3]; GLint u_fg;   // the sky drawn under the bare, over a copy of the frame's marks
 GLuint lf, lz; GLint u_cls;   // seen: the lenses' nearest depths
 GLuint zf, zt; GLint u_bb, u_br, u_bu, u_gz; float eye[10]; int epend;   // the glows' eye, and the depths they fade by
 GLuint sm; GLint u_lm, u_sun, u_bias, u_ss; float lm[16], bias; int sw, sh;   // the sun's view
 GLint u_m, u_tx, u_ts, u_has, u_fog, u_fz, u_tone, u_mode, u_vp, u_off, u_li, u_ks;
 GLuint uprog, uc, ud, bc; int uw, uh, upend, bpend;   // the smaller frame laid first, the ground
 GLint uu_cs, uu_fs, uu_base;
 EGLDisplay d; EGLConfig cf; EGLContext c; EGLSurface ws; void *xd;   // ws: the window shown on, by xd's display
 int in, out, zk, vw, vh;   // the lines' fds; the window's pixels a picture's pixel is, and its size
 void *(*hook) (void *, int, int, int); void *ctx, *nw; EGLSurface ps;   // in an app's own process: its window (hook's), nw the one
                                                               // ws is on; ps the pbuffer current without one
 GLuint dprog; GLint ud_m, ud_off, ud_vp;   // the lenses' depths
 GLuint sprog, stex, kprog, kq; GLint us_r, us_wh, us_swz, us_zk;
 GLuint kt[2]; int kv[2], ks;   // the frames kept unread, none of it the cpu's: a copy each, the next drawn over neither
 GLuint pprog, pva, pvb, ot, ofb; GLint up_sz; int ow, oh;   // spots, laid on ot
 int opend; GLint u_sp; int sW, sH;   // ..laid there for the next frame's sky, where it goes under glass too
 float *scn; int nscn, cscn; int *ids; int cids; struct seen *sn; int csn;   // the scene, 8 floats a buf; a frame's ids, the scene's laid in
 float *mul; int cmul; float kb[1024]; GLint u_sh;   // ..each id's colour times, from the lights' strengths
 float *vis; int nvis, cvis;   // ..and the marks
 GLuint cmt, amt, fva, fvb; float kp[64]; int nkp; GLint u_kp, u_skm, u_csh;   // the sky a pixel at a time: its map, a triangle over all, its numbers
 char line[1 << 16], one[1 << 16]; size_t got; };

static void *need(void *h, const char *n) {
 void *p = h ? dlsym(h, n) : NULL;
 if (!p && eglGetProcAddress) p = eglGetProcAddress(n);
 return p; }

// the shared file, mapped whole again once it has grown
static unsigned char *bytes(struct helper *H, size_t off, size_t n) {
 // ..its size by lseek: a struct stat laid by our headers is not the system libc's
 long long const e = seek64(H->fd, 0, SEEK_END);
 if (e < 0) return NULL;
 if ((size_t) e != H->sz) {
  if (H->map) munmap(H->map, H->sz);
  H->sz = (size_t) e;
  H->map = H->sz ? map64(NULL, H->sz, PROT_READ | PROT_WRITE, MAP_SHARED, H->fd, 0) : NULL;
  if (H->map == MAP_FAILED) H->map = NULL, H->sz = 0; }
 return H->map && off <= H->sz && n <= H->sz - off ? H->map + off : NULL; }

static GLuint shader(int o, GLenum k, const char *src) {
 GLuint s = glCreateShader(k); GLint ok = 0;
 glShaderSource(s, 1, &src, NULL); glCompileShader(s); glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
 if (!ok) { char log[512]; glGetShaderInfoLog(s, sizeof log, NULL, log); dprintf(o, "err shader %s\n", log); return 0; }
 return s; }

// rows run top first: y flips in clip. the colour is the vertex's times 255 times the texel,
// fogged by view depth, then exposed; written b g r so the bytes read back are 0x00rrggbb
static char const vsrc[] =
 "#version 300 es\n"
 "layout(location=0) in vec3 p; layout(location=1) in vec2 t; layout(location=2) in vec3 c; layout(location=3) in vec3 sc;\n"
 "layout(location=4) in vec3 l0; layout(location=5) in vec3 l1; layout(location=6) in vec3 l2; layout(location=7) in vec3 l3;\n"
 "layout(location=8) in vec3 l4; layout(location=9) in vec3 l5; layout(location=10) in vec3 l6; layout(location=11) in vec3 l7; layout(location=12) in vec3 sd;\n"
 "uniform int li[8]; uniform float ks[128]; uniform float sh;\n"
 "uniform mat4 m; uniform mat4 lm; uniform vec2 vp; uniform int bb; uniform vec3 br; uniform vec3 bu; uniform vec3 off;\n"
 "uniform highp sampler2D cm; uniform highp float kp[51]; uniform float csh;\n"
 "float cl(vec2 x) { vec2 i = floor(x), u = x - i; ivec2 a = ivec2(mod(i, 128.0)), b = ivec2(mod(i + 1.0, 128.0));\n"
 "  float q0 = texelFetch(cm, a, 0).r, q1 = texelFetch(cm, ivec2(b.x, a.y), 0).r, q2 = texelFetch(cm, ivec2(a.x, b.y), 0).r, q3 = texelFetch(cm, b, 0).r;\n"
 "  float lo = q0 + u.x * (q1 - q0), hi = q2 + u.x * (q3 - q2); return lo + u.y * (hi - lo); }\n"
 "float dlow(float y) { return y < 0.05 ? 0.025 + 0.025 * exp((min(y, 0.05) - 0.05) / 0.025) : y; }\n"
 "float thk(vec2 u, vec3 W) { float a = cl(u * 16.0 + vec2(kp[3], kp[4])), b = cl(u * 37.0 + vec2(kp[5], kp[6])), s = cl(u * 3.0 + vec2(kp[7], kp[8]));\n"
 "  return 0.7 * (0.5 + W.x * (a - 0.5)) + 0.3 * (0.5 + W.y * (b - 0.5)) + 0.18 * W.z * (s - 0.5); }\n"
 // ..how much of the sun's light the clouds let by at plan x, over what its light was made with
 "float shade(vec2 x) { vec3 s = vec3(kp[9], kp[10], kp[11]); float g = clamp(0.5 + (thk((x + s.xz * 1800.0 / dlow(s.y)) / 400.0, vec3(1.0)) - kp[2]) / 0.08, 0.0, 1.0);\n"
 "  return (1.0 - 0.75 * g - 0.2 * g * g * g * g) * csh; }\n"
 "invariant gl_Position; out vec2 uv; out vec3 col; out vec3 scol; out vec3 lp; out float w;\n"
 "void main(){ vec3 P = (bb != 0 ? p + t.x * br + t.y * bu : p) + off;\n"
 " vec4 q = m * vec4(P, 1.0); uv = t; scol = sc;\n"
 " col = sh * (c + ks[li[0]] * l0 + ks[li[1]] * l1 + ks[li[2]] * l2 + ks[li[3]] * l3 + ks[li[4]] * l4 + ks[li[5]] * l5 + ks[li[6]] * l6 + ks[li[7]] * l7);\n"
 " if (csh > 0.0 && sd.r + sd.g + sd.b > 0.0) col = max(vec3(0.0), col + sh * sd * (shade(P.xz) - 1.0));\n"
 " lp = (lm * vec4(P, 1.0)).xyz; w = q.w; q.y = -q.y;\n"
 " if (q.w > 0.0) { vec2 s = floor((q.xy / q.w * 0.5 + 0.5) * vp * 16.0 + 0.5) / 16.0; q.xy = (s / vp * 2.0 - 1.0) * q.w; }\n"
 " gl_Position = q; }\n";
// mode 0 opaque, 1 a glow (added), 2 a glass on what is there (times its tint, its colour
// added where something drew), 3 the same glass on what is bare (the tint kept, the sheen),
// 4 its mark on what is bare, half an alpha, 6 and 7 a glass's tint alone, before 2 and 3 where
// the driver blends with one colour, 5 the sky under what is bare, its u an edge as
// facets's 256 takes it, asking a copy of the marks: 254 its alpha where it was bare alone,
// 253 onto a glow or through a glass; a spot laid for it there in its stead
static char const fsrc[] =
 "#version 300 es\n"
 "#extension GL_EXT_blend_func_extended : enable\n"
 "precision highp float; precision highp int; in vec2 uv; in vec3 col; in vec3 scol; in vec3 lp; in float w;\n"
 "uniform sampler2D tx; uniform vec2 ts; uniform int has; uniform vec3 fog; uniform vec2 fz; uniform float tone; uniform int mode;\n"
 "uniform highp sampler2D fbt; uniform highp sampler2D gbt; uniform int fg;\n"
 "uniform highp sampler2D lz; uniform int cls; uniform highp sampler2D sm; uniform int sun; uniform float bias; uniform ivec2 ss;\n"
 "uniform highp sampler2D dz; uniform vec4 gz; uniform highp sampler2D ov5; uniform int sp;\n"
 "uniform highp sampler2D cm; uniform highp sampler2D am; uniform float kp[51]; uniform int skm;\n"
 // ..the sky down ray d, sky.l's sky-colour-at step for step: the cloud map bilinear and
 // wrapping, the deck where d crosses it, two layers and a swell, the light on them
 "float cl(vec2 x) { vec2 i = floor(x), u = x - i; ivec2 a = ivec2(mod(i, 128.0)), b = ivec2(mod(i + 1.0, 128.0));\n"
 "  float q0 = texelFetch(cm, a, 0).r, q1 = texelFetch(cm, ivec2(b.x, a.y), 0).r, q2 = texelFetch(cm, ivec2(a.x, b.y), 0).r, q3 = texelFetch(cm, b, 0).r;\n"
 "  float lo = q0 + u.x * (q1 - q0), hi = q2 + u.x * (q3 - q2); return lo + u.y * (hi - lo); }\n"
 "float dlow(float y) { return y < 0.05 ? 0.025 + 0.025 * exp((min(y, 0.05) - 0.05) / 0.025) : y; }\n"
 "vec2 deck(vec3 d) { float t = 1800.0 / dlow(d.y); return vec2(kp[0] + d.x * t, kp[1] + d.z * t) / 400.0; }\n"
 "float thk(vec2 u, vec3 W) { float a = cl(u * 16.0 + vec2(kp[3], kp[4])), b = cl(u * 37.0 + vec2(kp[5], kp[6])), s = cl(u * 3.0 + vec2(kp[7], kp[8]));\n"
 "  return 0.7 * (0.5 + W.x * (a - 0.5)) + 0.3 * (0.5 + W.y * (b - 0.5)) + 0.18 * W.z * (s - 0.5); }\n"
 "float mean(vec3 c) { return (c.r + c.g + c.b) / 3.0; }\n"
 "vec3 dyed(vec3 c) { vec3 d = vec3(kp[27], kp[28], kp[29]); return kp[26] > 0.5 ? mean(c) * d / mean(d) : c; }\n"
 "vec3 smogby(vec3 c, float f) { float k = kp[25], l = mean(c); if (k == 0.0) return c;\n"
 "  vec3 t = mix(vec3(kp[30], kp[31], kp[32]), vec3(kp[33], kp[34], kp[35]), clamp(1.6 * l, 0.0, 1.0)); return mix(c, t * l, k * f); }\n"
 "float clouded(float c) { return kp[23] == 3.0 ? max(c, 0.93) : c; }\n"
 "vec3 air(vec3 d, vec3 s) { ivec2 z = textureSize(am, 0); float q = length(d.xz) * length(s.xz), c = q > 1e-9 ? dot(d.xz, s.xz) / q : 1.0;\n"
 "  vec2 p = clamp(vec2(sqrt(max((1.0 - c) / 2.0, 0.0)), sqrt(max(d.y, 0.0))), 0.0, 1.0) * vec2(z - 1); ivec2 i = min(ivec2(p), z - 2); vec2 u = p - vec2(i);\n"
 "  return mix(mix(texelFetch(am, i, 0).rgb, texelFetch(am, i + ivec2(1, 0), 0).rgb, u.x), mix(texelFetch(am, i + ivec2(0, 1), 0).rgb, texelFetch(am, i + ivec2(1, 1), 0).rgb, u.x), u.y); }\n"
 "float mar(vec3 d, vec3 s, vec3 W, float n, float w) { return w * clamp((thk(deck(normalize(d + n * s)), W) - kp[2]) * 5.0, 0.0, 1.0); }\n"
 "vec3 skyc(vec3 d) {\n"
 "  float dy = d.y, up = clamp(dy, 0.0, 1.0), fp = kp[47] * 1800.0 / (dlow(dy) * 400.0);\n"
 "  vec3 q = vec3(2.0, 4.6, 0.4) * fp, W = 1.0 / (1.0 + q * q);\n"
 "  float sd = 0.2 * sqrt(0.49 * (1.0 - W.x * W.x) + 0.09 * (1.0 - W.y * W.y) + 0.0324 * (1.0 - W.z * W.z));\n"
 "  vec3 dark = vec3(0.012, 0.016, 0.04) + 0.06 * (1.0 - up) * vec3(0.6, 0.45, 0.3);\n"
 "  float hk = clamp(1.0 - dy / 0.06, 0.0, 1.0); vec3 s = vec3(kp[9], kp[10], kp[11]);\n"
 "  float th = thk(deck(d), W), od = mar(d, s, W, 0.012, 0.6) + mar(d, s, W, 0.03, 0.8) + mar(d, s, W, 0.06, 1.0) + mar(d, s, W, 0.11, 1.2), mu = dot(d, s), day = kp[12], tw = kp[13], oc = kp[18], sm = kp[25], ed = kp[2];\n"
 "  vec3 sunc = vec3(kp[15], kp[16], kp[17]), amb = vec3(kp[19], kp[20], kp[21]);\n"
 "  float disc = clamp((mu - 0.9995) * 4000.0, 0.0, 1.0) * clamp(0.5 + 300.0 * dy, 0.0, 1.0);\n"
 "  vec3 sky0 = (1.0 - day) * dyed(dark) + mix(dyed(air(d, s)), air(d, s), kp[36] > 0.5 ? 1.0 : 0.6 * tw) + 3.0 * disc * kp[14] * sqrt(sunc);\n"
 "  float core = clamp((th - ed) * 5.0, 0.0, 1.0), own = od + 0.6 * core, li = 0.65 * exp(-0.9 * own) + 0.35 * exp(-0.25 * own) + 0.9 * (1.0 - core) * exp((mu - 1.0) * 9.0);\n"
 "  float body = (kp[24] == 1.0 ? 0.8 : 1.0) * (1.0 - 0.45 * sm)\n"
 "   * (1.0 - 0.6 * sm * clamp((th - 0.3) * 2.2, 0.0, 1.0) + 0.5 * sm * clamp((0.4 - th) * 3.0, 0.0, 1.0));\n"
 "  vec3 cd = dyed(body * ((0.95 - 0.35 * core - 0.2 * oc * core) * amb + li * clamp((s.y + 0.005) / 0.05, 0.0, 1.0) * (1.0 - 0.6 * oc) * (0.75 + 0.3 * s.y) * sunc\n"
 "   + tw * (0.3 + 0.7 * li) * vec3(0.5, 0.22, 0.14) + 0.8 * (1.0 - day) * vec3(0.06, 0.05, 0.045)));\n"
 "  float sg = kp[26] > 0.5 ? clamp(1.0 - 1.6 * dy, 0.0, 1.0) : 1.0, hz = clamp(1.2 * kp[22], 0.0, 1.0);\n"
 "  float x = max(0.0, th - ed); cd += kp[14] * (3.0 * disc * exp(-18.0 * x) + clamp((s.y + 0.005) / 0.05, 0.0, 1.0) * 0.6 * exp(-8.0 * x) * exp((mu - 1.0) * 120.0)) * sqrt(sunc);\n"
 "  float g = clamp(0.5 + (th - ed) / sqrt(0.0016 + 2.0 * sd * sd), 0.0, 1.0);\n"
 "  return smogby(mix(sky0, cd, clouded(g + 0.85 * hk * (hz - g))), sg); }\n"
 "float lit(int i, int j, float z) { return i < 0 || j < 0 || i >= ss.x || j >= ss.y || z <= texelFetch(sm, ivec2(i, j), 0).r ? 1.0 : 0.0; }\n"
 "float vis() { float sx = (lp.x * 0.5 + 0.5) * float(ss.x) - 0.5, sy = (0.5 - lp.y * 0.5) * float(ss.y) - 0.5, fi = floor(sx), fj = floor(sy),\n"
 "  fx = sx - fi, fy = sy - fj, z = lp.z - bias; int i = int(fi), j = int(fj);\n"
 "  float t0 = lit(i, j, z) + (lit(i + 1, j, z) - lit(i, j, z)) * fx, t1 = lit(i, j + 1, z) + (lit(i + 1, j + 1, z) - lit(i, j + 1, z)) * fx;\n"
 "  return t0 + (t1 - t0) * fy; }\n"
 "#ifdef GL_EXT_blend_func_extended\n"
 "layout(location = 0, index = 0) out vec4 o; layout(location = 0, index = 1) out vec4 o1;\n"
 "#else\n"
 "out vec4 o; vec4 o1;\n"
 "#endif\n"
 "void main(){ vec3 C = col, S = scol; float E = uv.x;\n"
 " if (mode == 5 && skm != 0) { float U = (gl_FragCoord.x - 0.5 * kp[48]) / kp[46], V = (0.5 * kp[49] - gl_FragCoord.y) / kp[46];\n"
 "  C = skyc(normalize(vec3(kp[43], kp[44], kp[45]) + U * vec3(kp[37], kp[38], kp[39]) + V * vec3(kp[40], kp[41], kp[42]))), S = vec3(0.0); }\n"
 " vec3 c = (C + S * (sun != 0 ? vis() : mode == 5 ? clamp(0.5 + E, 0.0, 1.0) : 1.0)) * 255.0, t = vec3(1.0); bool gl = mode >= 2;\n"
 " if (cls != 0) { float d = texelFetch(lz, ivec2(gl_FragCoord.xy), 0).r, z = gl_FragCoord.z;\n"
 "  if (cls == 1 ? !(d < 1.0 && z > d) : !(d >= 1.0 || z < d)) discard; }\n"
 " if (has != 0) { vec4 k = texture(tx, uv / ts); if (k.a < 0.5) discard; if (gl) t = k.rgb; else c *= k.rgb; }\n"
 " if (fz.y > 0.0) { float f = clamp((w - fz.x) * fz.y, 0.0, 1.0); if (gl) c -= c * f, t += (1.0 - t) * f; else c += (fog - c) * f; }\n"
 " if (tone > 0.0) c = 255.0 * (1.0 - exp(-tone * c / 255.0));\n"
 " if (mode == 1 && gz.w > 0.0) { float d = texelFetch(dz, ivec2(gl_FragCoord.xy), 0).r * 2.0 - 1.0;\n"
 "  if (d > -1.0 && d < 1.0) c *= clamp((2.0 * gz.x * gz.y / (gz.y + gz.x - d * (gz.y - gz.x)) - w + gz.z) / gz.w, 0.0, 1.0); }\n"
 " if (mode == 5) { ivec2 p = ivec2(gl_FragCoord.xy); vec4 k = texelFetch(fbt, p, 0); float A = floor(k.a * 255.0 + 0.5);\n"
 "  if (A > 192.0) discard;\n"
 "  if (sp != 0) { vec4 s = texelFetch(ov5, p, 0); if (s.a > 0.5) c = floor(s.rgb * 255.0 + 0.5); }\n"
 "  vec3 g = floor(vec3(k.b, k.g, k.r) * 255.0 + 0.5); float a = 254.0 / 255.0;\n"
 "  if (g != vec3(0.0)) c += g, a = 253.0 / 255.0;\n"
 "  else if (A > 0.0) { vec4 f = texelFetch(gbt, p, 0); vec3 v; float sh;\n"
 "   if (fg != 0) v = clamp(floor(vec3(f.b, f.g, f.r) * 255.0 + 0.5), 0.0, 255.0), sh = floor(clamp(floor(f.a * 1020.0 + 0.5), 0.0, 255.0) / 4.0) * 4.0;\n"
 "   else v = floor(vec3(f.b, f.g, f.r) * 255.0 + 0.5), sh = floor(f.a * 255.0 + 0.5) * 4.0;\n"
 "   c = c * v / 255.0 + sh, a = 253.0 / 255.0; }\n"
 "  c = clamp(floor(c + 0.5), 0.0, 255.0) / 255.0; o = vec4(c.b, c.g, c.r, a); o1 = vec4(1.0); return; }\n"
 " c = clamp(c / 255.0, 0.0, 1.0); o1 = vec4(1.0);\n"
 " if (mode == 0) o = vec4(c.b, c.g, c.r, 1.0);\n"
 " else if (mode < 3) o = vec4(c.b, c.g, c.r, 0.0), o1 = vec4(t.b, t.g, t.r, 0.0);\n"
 " else if (mode == 3) o = vec4(0.0, 0.0, 0.0, (c.r + c.g + c.b) / 12.0), o1 = vec4(t.b, t.g, t.r, (t.r + t.g + t.b) / 3.0);\n"
 " else if (mode == 6) o = vec4(t.b, t.g, t.r, (t.r + t.g + t.b) / 3.0);\n"
 " else o = vec4(0.0, 0.0, 0.0, 0.5); }\n";

// the ground, or the smaller frame: one triangle over the whole frame, each pixel its own of
// the ground's, or of the smaller's as facets picks it, its colour and its depth; where the
// smaller drew nothing, nothing
static char const uvsrc[] =
 "#version 300 es\n"
 "void main(){ vec2 p = vec2(gl_VertexID == 1 ? 3.0 : -1.0, gl_VertexID == 2 ? 3.0 : -1.0); gl_Position = vec4(p, 0.0, 1.0); }\n";
static char const ufsrc[] =
 "#version 300 es\n"
 "precision highp float; precision highp int; uniform highp sampler2D cc; uniform highp sampler2D cd; uniform ivec2 cs; uniform ivec2 fs;\n"
 "out vec4 o;\n"
 "uniform int base;\n"
 "void main(){ ivec2 p = ivec2(gl_FragCoord.xy);\n"
 " if (base != 0) { vec4 k = texelFetch(cc, p, 0); o = k.a > 0.5 ? vec4(k.b, k.g, k.r, 1.0) : vec4(0.0); gl_FragDepth = 1.0; return; }\n"
 " ivec2 q = ivec2(p.x * cs.x / fs.x, p.y * cs.y / fs.y);\n"
 " float d = texelFetch(cd, q, 0).r; if (d >= 2.0) discard;\n"
 " vec4 k = texelFetch(cc, q, 0); o = vec4(k.b, k.g, k.r, 1.0); gl_FragDepth = clamp(d * 0.5 + 0.5, 0.0, 1.0); }\n";

// ..a picture shown on the window: r its rect in the window's pixels, top down, which it fills,
// its edges carried on past
// and swizzled, the frame's own, the spots laid over its sky
static char const sfsrc[] =
 "#version 300 es\n"
 "precision highp float; precision highp int; uniform sampler2D t; uniform sampler2D ov; uniform vec4 r; uniform vec2 wh; uniform int swz; uniform float zk; out vec4 o;\n"
 "void main(){ vec2 p = vec2(gl_FragCoord.x, wh.y - gl_FragCoord.y) / zk, ts = vec2(textureSize(t, 0)), uv = clamp((p - r.xy) / (r.zw - r.xy), 0.5 / ts, 1.0 - 0.5 / ts);\n"
 " vec4 k = texture(t, uv); o = vec4(swz != 0 ? k.bgr : k.rgb, 1.0);\n"
 " if (swz > 1 && abs(k.a * 255.0 - 254.0) < 0.5) { vec4 s = texture(ov, uv); if (s.a > 0.5) o = vec4(s.rgb, 1.0); } }\n";
// ..spots: a pixel's index and its word, laid on a texture of the frame's size
static char const pvsrc[] =
 "#version 300 es\n"
 "layout(location=0) in float i; layout(location=1) in float c; uniform ivec2 sz; flat out vec3 col;\n"
 "void main(){ int n = int(i), k = int(c); vec2 q = (vec2(float(n % sz.x), float(n / sz.x)) + 0.5) / vec2(sz);\n"
 " gl_Position = vec4(q * 2.0 - 1.0, 0.0, 1.0); gl_PointSize = 1.0;\n"
 " col = vec3(float(k >> 16 & 255), float(k >> 8 & 255), float(k & 255)) / 255.0; }\n";
static char const pfsrc[] =
 "#version 300 es\n"
 "precision highp float; precision highp int; flat in vec3 col; out vec4 o; void main(){ o = vec4(col, 1.0); }\n";
// ..a pixel of the frame that the cpu must finish: bare, or glass over the bare
// the lenses' depths: the frame's own vertex shader, its places the same to the bit, and no
// colour out; a shader of two colours onto a target of none hangs an intel gpu
static char const dfsrc[] = "#version 300 es\nprecision highp float; void main(){}\n";

static char const kfsrc[] =
 "#version 300 es\n"
 "precision highp float; precision highp int; uniform highp sampler2D t; out vec4 o;\n"
 "void main(){ if (texelFetch(t, ivec2(gl_FragCoord.xy), 0).a > 192.5 / 255.0) discard; o = vec4(0.0); }\n";

static GLuint program(GLuint vs, GLuint fs) {
 GLuint p = glCreateProgram(); GLint ok = 0;
 glAttachShader(p, vs); glAttachShader(p, fs); glLinkProgram(p); glGetProgramiv(p, GL_LINK_STATUS, &ok);
 return ok ? p : 0; }

static int setup(struct helper *H, int x) {
 // ..mesa's names, else android's
 void *egl = dlopen("libEGL.so.1", RTLD_NOW), *gl = dlopen("libGLESv2.so.2", RTLD_NOW);
 if (!egl) egl = dlopen("libEGL.so", RTLD_NOW);
 if (!gl) gl = dlopen("libGLESv2.so", RTLD_NOW);
 if (!egl || !gl) { dprintf(H->out, "err no gles: %s\n", dlerror()); return 0; }
 void *libc = dlopen(NULL, RTLD_NOW);   // the program and its libraries: bionic's RTLD_DEFAULT is not 0
 seek64 = (long long (*) (int, long long, int)) (libc ? dlsym(libc, "lseek64") : NULL);
 map64 = (void *(*) (void *, size_t, int, int, int, long long)) (libc ? dlsym(libc, "mmap64") : NULL);
 if (!seek64 || !map64) { dprintf(H->out, "err no lseek64\n"); return 0; }
#define LOADE(r, n, a) if (!(n = (r (*) a) need(egl, #n))) { dprintf(H->out, "err no %s\n", #n); return 0; }
#define LOADG(r, n, a) if (!(n = (r (*) a) need(gl, #n))) { dprintf(H->out, "err no %s\n", #n); return 0; }
 EGLFNS(LOADE)
 GLFNS(LOADG)
 eglGetPlatformDisplay = (EGLDisplay (*) (GLenum, void *, const intptr_t *)) need(egl, "eglGetPlatformDisplay");
 // ..for a window, the X server's display, through its own connection; else none
 void *xl = x ? dlopen("libX11.so.6", RTLD_NOW) : NULL;
 void *(*xopen) (char const *) = (void *(*) (char const *)) (xl ? dlsym(xl, "XOpenDisplay") : NULL);
 H->xd = xopen ? xopen(NULL) : NULL;
 EGLint ma, mi, n = 0;
 EGLDisplay d = H->xd && eglGetPlatformDisplay ? eglGetPlatformDisplay(EGL_PLATFORM_X11_KHR, H->xd, NULL) : NULL;
 if (d && !eglInitialize(d, &ma, &mi)) d = NULL, H->xd = NULL;
 if (!d) d = eglGetPlatformDisplay ? eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, NULL, NULL) : NULL;
 if (!d || !eglInitialize(d, &ma, &mi)) d = eglGetDisplay(NULL);
 if (!d || !eglInitialize(d, &ma, &mi)) { dprintf(H->out, "err no egl display\n"); return 0; }
 EGLint ca[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT | (H->xd || H->hook ? EGL_WINDOW_BIT : 0), EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
                 EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_NONE };
 EGLConfig cf = NULL;
 eglChooseConfig(d, ca, &cf, 1, &n);
 eglBindAPI(EGL_OPENGL_ES_API);
 EGLint xa[] = { EGL_CONTEXT_MAJOR_VERSION, 3, EGL_NONE };
 EGLContext c = eglCreateContext(d, n ? cf : NULL, NULL, xa);
 // ..no surface where the driver allows it, else a pixel's pbuffer
 EGLint pa[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
 EGLSurface ps = c && !eglMakeCurrent(d, NULL, NULL, c) ? eglCreatePbufferSurface(d, cf, pa) : NULL;
 if (!c || (ps && !eglMakeCurrent(d, ps, ps, c)) || (!ps && !eglMakeCurrent(d, NULL, NULL, c))) { dprintf(H->out, "err no gles 3 context\n"); return 0; }
 H->d = d, H->cf = cf, H->c = c, H->ps = ps;
 GLuint vs = shader(H->out, GL_VERTEX_SHADER, vsrc), fs = shader(H->out, GL_FRAGMENT_SHADER, fsrc);
 if (!vs || !fs) return 0;
 GLuint uvs = shader(H->out, GL_VERTEX_SHADER, uvsrc), ufs = shader(H->out, GL_FRAGMENT_SHADER, ufsrc);
 if (!uvs || !ufs) return 0;
 if (!(H->prog = program(vs, fs)) || !(H->uprog = program(uvs, ufs))) { dprintf(H->out, "err link\n"); return 0; }
 GLuint sfs = shader(H->out, GL_FRAGMENT_SHADER, sfsrc);
 if (!sfs || !(H->sprog = program(uvs, sfs))) { dprintf(H->out, "err link\n"); return 0; }
 glUseProgram(H->sprog);
 glUniform1i(glGetUniformLocation(H->sprog, "t"), 0);
 H->us_r = glGetUniformLocation(H->sprog, "r"); H->us_wh = glGetUniformLocation(H->sprog, "wh");
 H->us_swz = glGetUniformLocation(H->sprog, "swz"); H->us_zk = glGetUniformLocation(H->sprog, "zk");
 GLuint kfs = shader(H->out, GL_FRAGMENT_SHADER, kfsrc);
 if (!kfs || !(H->kprog = program(uvs, kfs))) { dprintf(H->out, "err link\n"); return 0; }
 glUseProgram(H->kprog); glUniform1i(glGetUniformLocation(H->kprog, "t"), 0);
 GLuint pvs = shader(H->out, GL_VERTEX_SHADER, pvsrc), pfs = shader(H->out, GL_FRAGMENT_SHADER, pfsrc);
 if (!pvs || !pfs || !(H->pprog = program(pvs, pfs))) { dprintf(H->out, "err link\n"); return 0; }
 glUseProgram(H->pprog); H->up_sz = glGetUniformLocation(H->pprog, "sz");
 glUseProgram(H->sprog); glUniform1i(glGetUniformLocation(H->sprog, "ov"), 1);
 GLuint dfs = shader(H->out, GL_FRAGMENT_SHADER, dfsrc);
 if (!dfs || !(H->dprog = program(vs, dfs))) { dprintf(H->out, "err link\n"); return 0; }
 glUseProgram(H->dprog);
 H->ud_m = glGetUniformLocation(H->dprog, "m"); H->ud_off = glGetUniformLocation(H->dprog, "off"); H->ud_vp = glGetUniformLocation(H->dprog, "vp");
 glGenQueries(1, &H->kq);
 glUseProgram(H->uprog);
 glUniform1i(glGetUniformLocation(H->uprog, "cc"), 0); glUniform1i(glGetUniformLocation(H->uprog, "cd"), 1);
 H->uu_cs = glGetUniformLocation(H->uprog, "cs"); H->uu_fs = glGetUniformLocation(H->uprog, "fs");
 H->uu_base = glGetUniformLocation(H->uprog, "base");
 glUseProgram(H->prog);
 H->u_m = glGetUniformLocation(H->prog, "m"); H->u_tx = glGetUniformLocation(H->prog, "tx");
 H->u_ts = glGetUniformLocation(H->prog, "ts"); H->u_has = glGetUniformLocation(H->prog, "has");
 H->u_fog = glGetUniformLocation(H->prog, "fog"); H->u_fz = glGetUniformLocation(H->prog, "fz");
 H->u_tone = glGetUniformLocation(H->prog, "tone"); H->u_mode = glGetUniformLocation(H->prog, "mode"); H->u_vp = glGetUniformLocation(H->prog, "vp");
 H->u_off = glGetUniformLocation(H->prog, "off");
 H->u_li = glGetUniformLocation(H->prog, "li"); H->u_ks = glGetUniformLocation(H->prog, "ks");
 H->u_sh = glGetUniformLocation(H->prog, "sh"); glUniform1f(H->u_sh, 1);
 char const *ex = (char const *) glGetString(0x1F03);   // GL_EXTENSIONS
 char const *du = getenv("LOVE_GPU_DUAL");   // 0 does without, as a driver with none must
 H->dual = ex && strstr(ex, "GL_EXT_blend_func_extended") != NULL && !(du && !strcmp(du, "0"));
 H->fglass = ex && strstr(ex, "GL_EXT_color_buffer_float") && strstr(ex, "GL_EXT_float_blend");
 glUniform1i(H->u_tx, 0); glUniform1i(glGetUniformLocation(H->prog, "lz"), 2);
 H->u_cls = glGetUniformLocation(H->prog, "cls");
 glUniform1i(glGetUniformLocation(H->prog, "sm"), 3);
 glUniform1i(glGetUniformLocation(H->prog, "fbt"), 4); glUniform1i(glGetUniformLocation(H->prog, "gbt"), 5);
 H->u_fg = glGetUniformLocation(H->prog, "fg");
 H->u_lm = glGetUniformLocation(H->prog, "lm"); H->u_sun = glGetUniformLocation(H->prog, "sun");
 H->u_bias = glGetUniformLocation(H->prog, "bias"); H->u_ss = glGetUniformLocation(H->prog, "ss");
 H->u_bb = glGetUniformLocation(H->prog, "bb"); H->u_br = glGetUniformLocation(H->prog, "br");
 H->u_bu = glGetUniformLocation(H->prog, "bu"); H->u_gz = glGetUniformLocation(H->prog, "gz");
 glUniform1i(glGetUniformLocation(H->prog, "dz"), 6);
 glUniform1i(glGetUniformLocation(H->prog, "ov5"), 7); H->u_sp = glGetUniformLocation(H->prog, "sp");
 glUniform1i(glGetUniformLocation(H->prog, "cm"), 8); glUniform1i(glGetUniformLocation(H->prog, "am"), 9);
 H->u_kp = glGetUniformLocation(H->prog, "kp"); H->u_skm = glGetUniformLocation(H->prog, "skm"); H->u_csh = glGetUniformLocation(H->prog, "csh");
 glPixelStorei(GL_PACK_ALIGNMENT, 4); glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
 glEnable(GL_DEPTH_TEST); glDepthFunc(GL_LESS);
 return 1; }

// ..a renderer in software, which a server without dri3 gives a window's display
static int soft(void) {
 char const *r = (char const *) glGetString(GL_RENDERER);
 return !r || strstr(r, "llvmpipe") || strstr(r, "softpipe") || strstr(r, "swrast"); }

static struct tex *tex_of(struct helper *H, int id) {
 for (int i = 0; i < H->ntex; i++) if (H->texs[i].id == id) return H->texs + i;
 return NULL; }
static struct buf *buf_of(struct helper *H, int id) {
 for (int i = 0; i < H->nbuf; i++) if (H->bufs[i].id == id) return H->bufs + i;
 return NULL; }

static void *grow(void *p, int *cap, int n, size_t each) {
 if (n < *cap) return p;
 int c = *cap ? 2 * *cap : 16;
 while (c <= n) c *= 2;
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
 if (w < 1 || h < 1 || L < 1 || L > 16) { dprintf(H->out, "err tex size\n"); return; }
 size_t n = 0;
 for (int l = 0, lw = w, lh = h; l < L; l++, lw = lw > 1 ? lw / 2 : 1, lh = lh > 1 ? lh / 2 : 1) n += (size_t) lw * lh;
 unsigned char const *p = bytes(H, off, 4 * n);
 unsigned char *rgba = p ? malloc(4 * (size_t) w * h) : NULL;
 if (!rgba) { dprintf(H->out, "err tex bytes\n"); return; }
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
 dprintf(H->out, "ok\n"); }

static void buf_free(struct buf *b) {
 glDeleteVertexArrays(1, &b->vao); glDeleteBuffers(1, &b->vb); glDeleteBuffers(1, &b->ib);
 if (b->lb) glDeleteBuffers(1, &b->lb);
 if (b->sb) glDeleteBuffers(1, &b->sb);
 b->lb = b->sb = 0; memset(b->li, 0, sizeof b->li);
 free(b->runs); b->runs = NULL; b->nrun = 0; }

static int bytex(void const *a, void const *b) {
 int32_t x, y; memcpy(&x, (char const*) a + 12, 4); memcpy(&y, (char const*) b + 12, 4);
 return (x > y) - (x < y); }

// the triangles in their order, as facets draws them, but for each stretch of opaque ones,
// sorted by texture; each texture's a run of the index buffer
static void cmd_buf(struct helper *H, int id, int nv, int nt, size_t off, int S) {
 if (nv < 0 || nt < 0 || (S != 8 && S != 11)) { dprintf(H->out, "err buf size\n"); return; }
 size_t const vb = 4 * (size_t) S * nv;
 unsigned char const *p = bytes(H, off, vb + 16 * (size_t) nt);
 int32_t *tr = p ? malloc(16 * (size_t) nt + 1) : NULL;
 uint32_t *ix = tr ? malloc(12 * (size_t) nt + 1) : NULL;
 struct run *runs = ix ? malloc(sizeof *runs * ((size_t) nt + 1)) : NULL;
 if (!runs) { free(tr); free(ix); dprintf(H->out, "err buf bytes\n"); return; }
 memcpy(tr, p + vb, 16 * (size_t) nt);
 for (int i = 0, j; i < nt; i = j + (j == i)) {
  for (j = i; j < nt && tr[4 * j + 3] >= -1; j++) ;
  if (j > i + 1) qsort(tr + 4 * i, (size_t) (j - i), 16, bytex); }
 int nrun = 0;
 for (int i = 0; i < nt; i++) {
  int32_t *t = tr + 4 * i;
  if (t[0] < 0 || t[0] >= nv || t[1] < 0 || t[1] >= nv || t[2] < 0 || t[2] >= nv) {
   free(tr); free(ix); free(runs); dprintf(H->out, "err buf vertex past the end\n"); return; }
  if (!nrun || runs[nrun - 1].tex != t[3]) runs[nrun++] = (struct run) { t[3], 3 * i, 0 };
  runs[nrun - 1].n += 3;
  ix[3*i] = (uint32_t) t[0], ix[3*i+1] = (uint32_t) t[1], ix[3*i+2] = (uint32_t) t[2]; }
 struct buf *b = buf_of(H, id);
 if (b) buf_free(b);
 else { H->bufs = grow(H->bufs, &H->cbuf, H->nbuf, sizeof *H->bufs); b = H->bufs + H->nbuf++; b->id = id; b->lb = b->sb = 0; memset(b->li, 0, sizeof b->li); }
 memset(b->off, 0, sizeof b->off);
 glGenVertexArrays(1, &b->vao); glBindVertexArray(b->vao);
 glGenBuffers(1, &b->vb); glBindBuffer(GL_ARRAY_BUFFER, b->vb);
 glBufferData(GL_ARRAY_BUFFER, (intptr_t) vb, p, GL_STATIC_DRAW);
 GLsizei const sb = 4 * S;
 glVertexAttribPointer(0, 3, GL_FLOAT, 0, sb, (void*) 0); glEnableVertexAttribArray(0);
 glVertexAttribPointer(1, 2, GL_FLOAT, 0, sb, (void*) 12); glEnableVertexAttribArray(1);
 glVertexAttribPointer(2, 3, GL_FLOAT, 0, sb, (void*) 20); glEnableVertexAttribArray(2);
 if (S == 11) glVertexAttribPointer(3, 3, GL_FLOAT, 0, sb, (void*) 32), glEnableVertexAttribArray(3);   // ..else the sun reaches nothing
 glGenBuffers(1, &b->ib); glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, b->ib);
 glBufferData(GL_ELEMENT_ARRAY_BUFFER, 12 * (intptr_t) nt, ix, GL_STATIC_DRAW);
 glBindVertexArray(0);
 free(tr); free(ix);
 b->runs = runs, b->nrun = nrun, b->nv = nv, b->S = S, b->glow = nrun > 0;
 for (int r = 0; r < nrun; r++) b->glow &= runs[r].tex == -2;
 dprintf(H->out, "ok\n"); }

// a buf's vertices laid again, its triangles kept: as many, as wide
static void cmd_verts(struct helper *H, int id, int nv, size_t off, int S) {
 struct buf *b = buf_of(H, id);
 if (!b || b->nv != nv || b->S != S) { dprintf(H->out, "err verts not that buf\n"); return; }
 unsigned char const *p = bytes(H, off, 4 * (size_t) S * nv);
 if (!p) { dprintf(H->out, "err verts bytes\n"); return; }
 glBindBuffer(GL_ARRAY_BUFFER, b->vb);
 glBufferSubData(GL_ARRAY_BUFFER, 0, 4 * (intptr_t) S * nv, p);
 glBindBuffer(GL_ARRAY_BUFFER, 0);
 dprintf(H->out, "ok\n"); }

// a buf's lamps: for each vertex 8 slots of light, slot k the colour lamp LK gives it at full
// strength; ks's strengths times them added to its colour as it is drawn. none past those
static void cmd_lamps(struct helper *H, int id, int nv, size_t off, int const *li) {
 struct buf *b = buf_of(H, id);
 if (!b || b->nv != nv) { dprintf(H->out, "err lamps not that buf\n"); return; }
 unsigned char const *p = bytes(H, off, 4 * 24 * (size_t) nv);
 if (!p) { dprintf(H->out, "err lamps bytes\n"); return; }
 for (int k = 0; k < 8; k++) if (li[k] < 0 || li[k] >= 128) { dprintf(H->out, "err lamps index\n"); return; }
 glBindVertexArray(b->vao);
 if (!b->lb) glGenBuffers(1, &b->lb);
 glBindBuffer(GL_ARRAY_BUFFER, b->lb);
 glBufferData(GL_ARRAY_BUFFER, 4 * 24 * (intptr_t) nv, p, GL_STATIC_DRAW);
 for (int k = 0; k < 8; k++) glVertexAttribPointer(4 + k, 3, GL_FLOAT, 0, 4 * 24, (void*) (uintptr_t) (12 * k)), glEnableVertexAttribArray(4 + k);
 glBindVertexArray(0); glBindBuffer(GL_ARRAY_BUFFER, 0);
 memcpy(b->li, li, sizeof b->li);
 dprintf(H->out, "ok\n"); }

// a buf's sun: the colour of each vertex that is the sun's own, which the clouds then take; none of 0
static void cmd_suns(struct helper *H, int id, int nv, size_t off) {
 struct buf *b = buf_of(H, id);
 if (b && !nv) { glBindVertexArray(b->vao); glDisableVertexAttribArray(12); glBindVertexArray(0); dprintf(H->out, "ok\n"); return; }
 if (!b || b->nv != nv) { dprintf(H->out, "err suns not that buf\n"); return; }
 unsigned char const *p = bytes(H, off, 12 * (size_t) nv);
 if (!p) { dprintf(H->out, "err suns bytes\n"); return; }
 glBindVertexArray(b->vao);
 if (!b->sb) glGenBuffers(1, &b->sb);
 glBindBuffer(GL_ARRAY_BUFFER, b->sb);
 glBufferData(GL_ARRAY_BUFFER, 12 * (intptr_t) nv, p, GL_STATIC_DRAW);
 glVertexAttribPointer(12, 3, GL_FLOAT, 0, 12, (void*) 0); glEnableVertexAttribArray(12);
 glBindVertexArray(0); glBindBuffer(GL_ARRAY_BUFFER, 0);
 dprintf(H->out, "ok\n"); }

// the lamps' strengths, n of them, kept until the next
static void cmd_ks(struct helper *H, char const *l) {
 float k[128] = {0}; int n = 0; char *e;
 for (double x = strtod(l, &e); e != l && n < 128; l = e, x = strtod(l, &e)) k[n++] = (float) x;
 glUseProgram(H->prog); glUniform1fv(H->u_ks, 128, k);
 dprintf(H->out, "ok\n"); }

static GLuint plain(GLenum f, GLenum ty, int w, int h) {
 GLuint t; glGenTextures(1, &t); glBindTexture(GL_TEXTURE_2D, t);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D, 0, (GLint) f, w, h, 0, GL_RGBA, ty, NULL);
 return t; }

// the window shown on: X's window xid, on the display opened for it
static void cmd_win(struct helper *H, unsigned long xid) {
 if (!H->xd) { dprintf(H->out, "err no window display\n"); return; }
 if (H->ws) eglMakeCurrent(H->d, NULL, NULL, H->c), eglDestroySurface(H->d, H->ws), H->ws = NULL;
 EGLSurface ws = eglCreateWindowSurface(H->d, H->cf, (void *) xid, NULL);
 if (!ws || !eglMakeCurrent(H->d, ws, ws, H->c)) { dprintf(H->out, "err no window surface\n"); return; }
 eglSwapInterval(H->d, 0);
 H->ws = ws;
 dprintf(H->out, "ok\n"); }

// ..texture t over the rect x0 y0 x1 y1 of the picture's window, top down, each of its pixels
// zk of the surface's; swizzled, the frame's own; padded, its edges run on over all the window
static void lay(struct helper *H, GLuint t, int swz, int pad, float x0, float y0, float x1, float y1) {
 int const k = H->zk;
 glBindTexture(GL_TEXTURE_2D, t);
 glUniform1i(H->us_swz, swz);
 glUniform4f(H->us_r, x0, y0, x1, y1); glUniform2f(H->us_wh, (float) H->vw, (float) H->vh); glUniform1f(H->us_zk, (float) k);
 glViewport(0, 0, H->vw, H->vh);
 if (pad) glScissor(0, H->vh - H->sH * k, H->sW * k, H->sH * k);
 else glScissor((GLint) x0 * k, H->vh - (GLint) y1 * k, (GLsizei) (x1 - x0) * k, (GLsizei) (y1 - y0) * k);
 glDrawArrays(GL_TRIANGLES, 0, 3); }

// ..words w by h at p, as the texture shown
static GLuint put(struct helper *H, unsigned char const *p, int w, int h) {
 unsigned char *rgba = malloc(4 * (size_t) w * h);
 if (!rgba) return 0;
 texels(rgba, p, (size_t) w * h);
 glBindTexture(GL_TEXTURE_2D, H->stex);
 glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
 free(rgba);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
 return H->stex; }

// ..ns spots, their indices then their words as floats at p, laid on the spots' texture
static int spots(struct helper *H, unsigned char const *p, int ns, int w, int h) {
 if (!H->ot || H->ow != w || H->oh != h) {
  if (H->ot) glDeleteTextures(1, &H->ot), glDeleteFramebuffers(1, &H->ofb);
  H->ot = plain(GL_RGBA8, GL_UNSIGNED_BYTE, w, h), H->ow = w, H->oh = h;
  glGenFramebuffers(1, &H->ofb); glBindFramebuffer(GL_FRAMEBUFFER, H->ofb);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, H->ot, 0);
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->ow = H->oh = 0; return 0; } }
 if (!H->pva) {
  glGenVertexArrays(1, &H->pva); glBindVertexArray(H->pva); glGenBuffers(1, &H->pvb);
  glBindBuffer(GL_ARRAY_BUFFER, H->pvb); }
 glBindVertexArray(H->pva); glBindBuffer(GL_ARRAY_BUFFER, H->pvb);
 glBufferData(GL_ARRAY_BUFFER, 8 * (intptr_t) ns, p, GL_STATIC_DRAW);
 glVertexAttribPointer(0, 1, GL_FLOAT, 0, 4, (void*) 0); glEnableVertexAttribArray(0);
 glVertexAttribPointer(1, 1, GL_FLOAT, 0, 4, (void*) (4 * (uintptr_t) ns)); glEnableVertexAttribArray(1);
 glBindFramebuffer(GL_FRAMEBUFFER, H->ofb); glViewport(0, 0, w, h);
 float const z[4] = { 0, 0, 0, 0 };
 glClearBufferfv(GL_COLOR, 0, z);
 glUseProgram(H->pprog); glUniform2i(H->up_sz, w, h);
 glDrawArrays(GL_POINTS, 0, ns);
 glBindVertexArray(0);
 return 1; }

// ..in an app's own process, the window the hook hands over for a picture's window W by H, held
// through the show: a surface on it, made again when it is another; 0 where there is none
static int onwin(struct helper *H, int W, int Hh) {
 void *w = H->hook(H->ctx, 0, W, Hh);
 if (w == H->nw && (H->ws || !w)) return H->ws != NULL;   // ..a surface not made yet is tried again
 eglMakeCurrent(H->d, H->ps, H->ps, H->c);
 if (H->ws) eglDestroySurface(H->d, H->ws), H->ws = NULL;
 H->nw = w;
 EGLSurface ws = w ? eglCreateWindowSurface(H->d, H->cf, w, NULL) : NULL;
 if (ws && !eglMakeCurrent(H->d, ws, ws, H->c)) eglDestroySurface(H->d, ws), ws = NULL;
 if (ws) eglSwapInterval(H->d, 0);
 H->ws = ws;
 return ws != NULL; }

// ..a picture w by h laid over the window W by H at [ax ay]: the words at off, or with kept
// above 0 the frame kept in slot kept - 1, ns spots over its sky, at off; then n rects x0 y0 x1 y1 of
// the window's own, their words after; and shown
static void cmd_show(struct helper *H, char *l) {
 int w, h, W, Hh, ax, ay, kept, ns, n, k = 0; long off;
 if (sscanf(l, "%d %d %d %d %d %d %ld %d %d %d%n", &w, &h, &W, &Hh, &ax, &ay, &off, &kept, &ns, &n, &k) != 10 || w < 1 || h < 1 || W < 1 || Hh < 1 || n < 0 || ns < 0) {
  dprintf(H->out, "err show size\n"); return; }
 if (!H->ws && !H->hook) { dprintf(H->out, "err no window\n"); return; }
 if (kept && !(kept <= 2 && H->kv[kept - 1] && w == H->fw && h == H->fh)) { dprintf(H->out, "err no frame kept\n"); return; }
 unsigned char const *sp = kept && ns ? bytes(H, (size_t) off, 8 * (size_t) ns) : NULL;
 if (kept && ns && !(sp && spots(H, sp, ns, w, h))) { dprintf(H->out, "err show spots\n"); return; }
 size_t at = (size_t) off + (kept ? 8 * (size_t) ns : 4 * (size_t) w * h);
 unsigned char const *p = kept ? NULL : bytes(H, (size_t) off, 4 * (size_t) w * h);
 if (!kept && !p) { dprintf(H->out, "err show bytes\n"); return; }
 if (!H->stex) glGenTextures(1, &H->stex);
 // ..the window's own pixels, each picture pixel zk of them; an app's hidden window shows nothing
 if (H->hook && !onwin(H, W, Hh)) { H->hook(H->ctx, 1, 0, 0); dprintf(H->out, "ok\n"); return; }
 EGLint sw = W, sh = Hh;
 if (H->hook) eglQuerySurface(H->d, H->ws, EGL_WIDTH, &sw), eglQuerySurface(H->d, H->ws, EGL_HEIGHT, &sh);
 H->vw = sw, H->vh = sh, H->sW = W, H->sH = Hh, H->zk = sw / W < sh / Hh ? sw / W : sh / Hh;
 if (H->zk < 1) H->zk = 1;
 glBindFramebuffer(GL_FRAMEBUFFER, 0);
 glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); glDisable(GL_BLEND);
 glUseProgram(H->sprog); glActiveTexture(GL_TEXTURE0);
 glClearColor(0.0f, 0.0f, 0.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT);
 glEnable(GL_SCISSOR_TEST);
 if (kept && ns) glActiveTexture(GL_TEXTURE1), glBindTexture(GL_TEXTURE_2D, H->ot), glActiveTexture(GL_TEXTURE0);
 GLuint t = kept ? H->kt[kept - 1] : put(H, p, w, h);
 if (t) lay(H, t, kept ? 1 + (ns > 0) : 0, 1, (float) ax, (float) ay, (float) (ax + W), (float) (ay + Hh));
 char *s = l + k;
 for (int i = 0, x0, y0, x1, y1, j; i < n; i++, s += j) {
  if (sscanf(s, "%d %d %d %d%n", &x0, &y0, &x1, &y1, &j) != 4 || x0 < 0 || y0 < 0 || x1 <= x0 || y1 <= y0 || x1 > W || y1 > Hh) break;
  size_t const m = 4 * (size_t) (x1 - x0) * (y1 - y0);
  unsigned char const *q = bytes(H, at, m);
  if (!q || !(t = put(H, q, x1 - x0, y1 - y0))) break;
  lay(H, t, 0, 0, (float) x0, (float) y0, (float) x1, (float) y1);
  at += m; }
 glDisable(GL_SCISSOR_TEST);
 eglSwapBuffers(H->d, H->ws);
 if (H->hook) H->hook(H->ctx, 1, 0, 0);
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb); glEnable(GL_DEPTH_TEST); glUseProgram(H->prog);
 dprintf(H->out, "ok\n"); }

static void cmd_under(struct helper *H, int cw, int ch, size_t off) {
 if (cw < 1 || ch < 1) { dprintf(H->out, "err under size\n"); return; }
 size_t n = (size_t) cw * ch;
 unsigned char const *p = bytes(H, off, 8 * n);
 unsigned char *rgba = p ? malloc(4 * n) : NULL;
 if (!rgba) { dprintf(H->out, "err under bytes\n"); return; }
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
 dprintf(H->out, "ok\n"); }

static void cmd_base(struct helper *H, int w, int h, size_t off) {
 size_t n = (size_t) w * h;
 unsigned char const *p = w > 0 && h > 0 ? bytes(H, off, 4 * n) : NULL;
 unsigned char *rgba = p ? malloc(4 * n) : NULL;
 if (!rgba) { dprintf(H->out, "err base bytes\n"); return; }
 if (!H->bc) {
  glGenTextures(1, &H->bc); glBindTexture(GL_TEXTURE_2D, H->bc);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); }
 texels(rgba, p, n);
 glBindTexture(GL_TEXTURE_2D, H->bc); glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
 free(rgba);
 H->bpend = 1;
 dprintf(H->out, "ok\n"); }

static int words(char *s, double *v, int max);

static void cmd_sun(struct helper *H, char *args) {
 double v[20];
 if (words(args, v, 20) != 20 || v[0] < 1 || v[1] < 1) { dprintf(H->out, "err sun args\n"); return; }
 int const w = (int) v[0], h = (int) v[1];
 unsigned char const *p = bytes(H, (size_t) v[2], 4 * (size_t) w * h);
 if (!p) { dprintf(H->out, "err sun bytes\n"); return; }
 if (!H->sm) {
  glGenTextures(1, &H->sm); glBindTexture(GL_TEXTURE_2D, H->sm);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); }
 glBindTexture(GL_TEXTURE_2D, H->sm); glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, w, h, 0, GL_RED, GL_FLOAT, p);
 H->sw = w, H->sh = h, H->bias = (float) v[3];
 for (int i = 0; i < 16; i++) H->lm[i] = (float) v[4 + i];
 dprintf(H->out, "ok\n"); }

// ..the cloud map, and the numbers the sky asked a pixel at a time takes
static void cmd_cloud(struct helper *H, int n, size_t off) {
 float const *p = n > 0 ? (float const*) bytes(H, off, 4 * (size_t) n * n) : NULL;
 if (!p) { dprintf(H->out, "err cloud bytes\n"); return; }
 if (!H->cmt) glGenTextures(1, &H->cmt);
 glActiveTexture(GL_TEXTURE8); glBindTexture(GL_TEXTURE_2D, H->cmt);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, n, n, 0, GL_RED, GL_FLOAT, p);
 glActiveTexture(GL_TEXTURE0);
 dprintf(H->out, "ok\n"); }
static void cmd_air(struct helper *H, int w, int h, size_t off) {
 float const *p = w > 1 && h > 1 ? (float const*) bytes(H, off, 12 * (size_t) w * h) : NULL;
 if (!p) { dprintf(H->out, "err air bytes\n"); return; }
 if (!H->amt) glGenTextures(1, &H->amt);
 glActiveTexture(GL_TEXTURE9); glBindTexture(GL_TEXTURE_2D, H->amt);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, w, h, 0, GL_RGB, GL_FLOAT, p);
 glActiveTexture(GL_TEXTURE0);
 dprintf(H->out, "ok\n"); }
static void cmd_skyp(struct helper *H, char *l) {
 double v[64];
 int const n = words(l, v, 64);
 if (n < 50) { dprintf(H->out, "err skyp args\n"); return; }
 for (int i = 0; i < n; i++) H->kp[i] = (float) v[i];
 H->nkp = n;
 dprintf(H->out, "ok\n"); }
static void cmd_sky(struct helper *H, int id, double tone, double const *e) {
 H->sky = id, H->stone = (float) tone, H->spend = 1;
 for (int k = 0; k < 3; k++) H->soff[k] = (float) e[k];
 dprintf(H->out, "ok\n"); }
// ..ns spots at off for the next frame w by h, laid in its sky as it is drawn
static void cmd_spots(struct helper *H, int w, int h, int ns, size_t off) {
 unsigned char const *sp = ns > 0 && w > 0 && h > 0 ? bytes(H, off, 8 * (size_t) ns) : NULL;
 H->opend = sp && spots(H, sp, ns, w, h);
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb); glUseProgram(H->prog);
 dprintf(H->out, H->opend ? "ok\n" : "err spots\n"); }

static int words(char *s, double *v, int max);
static void cmd_glow(struct helper *H, char *args) {
 double v[10];
 if (words(args, v, 10) != 10) { dprintf(H->out, "err glow args\n"); return; }
 for (int i = 0; i < 10; i++) H->eye[i] = (float) v[i];
 H->epend = v[7] > v[6] && v[9] > 0;
 dprintf(H->out, "ok\n"); }

static void cmd_drop(struct helper *H, int id) {
 struct buf *b = buf_of(H, id);
 if (b) buf_free(b), *b = H->bufs[--H->nbuf];
 dprintf(H->out, "ok\n"); }

// a texture drawn into and asked by texel, w by h of the format f
static int target(struct helper *H, int w, int h) {
 if (w == H->fw && h == H->fh) return 1;
 if (H->fb) glDeleteFramebuffers(1, &H->fb), glDeleteFramebuffers(1, &H->gb), glDeleteTextures(1, &H->rb),
            glDeleteRenderbuffers(1, &H->db), glDeleteTextures(1, &H->gr), glDeleteTextures(1, &H->mk), glDeleteTextures(2, H->kt);
 H->kv[0] = H->kv[1] = 0;
 glGenFramebuffers(1, &H->fb); glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
 H->rb = plain(GL_RGBA8, GL_UNSIGNED_BYTE, w, h);
 glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, H->rb, 0);
 glGenRenderbuffers(1, &H->db); glBindRenderbuffer(GL_RENDERBUFFER, H->db);
 glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
 glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, H->db);
 if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->fw = H->fh = 0; return 0; }
 // ..and glass's on what is bare, its own colours over the same depths
 glGenFramebuffers(1, &H->gb); glBindFramebuffer(GL_FRAMEBUFFER, H->gb);
 H->gr = plain(H->fglass ? GL_RGBA32F : GL_RGBA8, H->fglass ? GL_FLOAT : GL_UNSIGNED_BYTE, w, h);
 glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, H->gr, 0);
 glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, H->db);
 if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->fw = H->fh = 0; return 0; }
 H->mk = plain(GL_RGBA8, GL_UNSIGNED_BYTE, w, h);   // ..the marks the sky asks, copied
 H->kt[0] = plain(GL_RGBA8, GL_UNSIGNED_BYTE, w, h), H->kt[1] = plain(GL_RGBA8, GL_UNSIGNED_BYTE, w, h);
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
 // ..and the lenses' depths, a texture the frame asks
 if (H->lf) glDeleteFramebuffers(1, &H->lf), glDeleteTextures(1, &H->lz);
 glGenTextures(1, &H->lz); glBindTexture(GL_TEXTURE_2D, H->lz);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
 glGenFramebuffers(1, &H->lf); glBindFramebuffer(GL_FRAMEBUFFER, H->lf);
 glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, H->lz, 0);
 if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->fw = H->fh = 0; return 0; }
 // ..and a copy of the frame's depths after what is opaque, which the glows fade by
 if (H->zf) glDeleteFramebuffers(1, &H->zf), glDeleteTextures(1, &H->zt);
 glGenTextures(1, &H->zt); glBindTexture(GL_TEXTURE_2D, H->zt);
 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, w, h, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
 glGenFramebuffers(1, &H->zf); glBindFramebuffer(GL_FRAMEBUFFER, H->zf);
 glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, H->zt, 0);
 if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) { H->fw = H->fh = 0; return 0; }
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
 unsigned char *gx = realloc(H->gx, 16 * (size_t) w * h);
 if (!gx) { H->fw = H->fh = 0; return 0; }
 H->gx = gx, H->fw = w, H->fh = h;
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

// a channel as facets rounds it
static uint32_t ch(float c) { int k = (int) (c + 0.5f); return (uint32_t) (k < 0 ? 0 : k > 255 ? 255 : k); }

// facets's texture codes past 2^24: a pane's class, 1 drawn only behind the nearest lens, 2
// only before it; a lens a glass less 2^24
enum { lensed = 1 << 24 };
static int class(int t) { return t >= lensed - 1 ? (t + 1) / lensed : 0; }
static int code(int t) { return t <= -3 - lensed ? t + lensed : t >= lensed - 1 ? (t + 1) % lensed - 1 : t; }

// a run's state: opaque writes its depth, a glow or a glass leaves it and blends
static void mode(struct helper *H, int m) {
 glUniform1i(H->u_mode, m == 7 ? 6 : m);
 glDepthMask(m == 0);
 if (m == 0 || m == 5) glDisable(GL_BLEND);
 else glEnable(GL_BLEND);
 glColorMask(m != 4, m != 4, m != 4, 1);
 glBlendEquationSeparate(GL_FUNC_ADD, m == 4 ? GL_MAX : GL_FUNC_ADD);
 if (m == 1) glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ZERO, GL_ONE);
 else if (m == 2) glBlendFuncSeparate(GL_DST_ALPHA, H->dual ? GL_SRC1_COLOR : GL_ONE, GL_ZERO, GL_ONE);
 else if (m == 3) glBlendFuncSeparate(GL_ZERO, H->dual ? GL_SRC1_COLOR : GL_ONE, GL_ONE, H->dual ? GL_SRC1_ALPHA : GL_ONE);
 else if (m == 6) glBlendFuncSeparate(GL_ZERO, GL_SRC_COLOR, GL_ZERO, GL_ONE);
 else if (m == 7) glBlendFuncSeparate(GL_ZERO, GL_SRC_COLOR, GL_ZERO, GL_SRC_ALPHA);
 else if (m == 4) glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ONE); }
// a run of glass, m 2 or 3: in one draw, else a triangle at a time, its tint and then its colour
static void glass(struct helper *H, int m, int n, uintptr_t at) {
 if (H->dual) { mode(H, m); glDrawElements(GL_TRIANGLES, n, GL_UNSIGNED_INT, (void*) (4 * at)); return; }
 for (int i = 0; i + 3 <= n; i += 3)
  for (int k = 0; k < 2; k++) mode(H, k ? m : m + 4), glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_INT, (void*) (4 * (at + (uintptr_t) i))); }

enum { scene_id = -9, groups = 2 };
static void cmd_scene(struct helper *H, int n, size_t off) {
 float const *p = n >= 0 ? (float const*) bytes(H, off, 36 * (size_t) n) : NULL;
 if (!p) { dprintf(H->out, "err scene bytes\n"); return; }
 H->nscn = 0;
 float *q = grow(H->scn, &H->cscn, 9 * n, sizeof *q);
 if (!q) { dprintf(H->out, "err scene room\n"); return; }
 H->scn = q; memcpy(q, p, 36 * (size_t) n); H->nscn = n;
 dprintf(H->out, "ok\n"); }
static void cmd_place(struct helper *H, char *l) {
 double v[4 * 1024];
 int const n = words(l, v, 4 * 1024);
 if (n % 4) { dprintf(H->out, "err place args\n"); return; }
 for (int i = 0; i < n; i += 4) {
  struct buf *b = buf_of(H, (int) v[i]);
  if (b) for (int k = 0; k < 3; k++) b->off[k] = (float) v[i + 1 + k]; }
 dprintf(H->out, "ok\n"); }
static void cmd_vis(struct helper *H, int n, int k, size_t off) {
 float const *p = n >= 0 && k >= 0 && k <= 1024 ? (float const*) bytes(H, off, 4 * ((size_t) n + k)) : NULL;
 float *q = p ? grow(H->vis, &H->cvis, n, sizeof *q) : NULL;
 if (!q) { dprintf(H->out, "err vis bytes\n"); return; }
 H->vis = q; memcpy(q, p, 4 * (size_t) n); H->nvis = n;
 memcpy(H->kb, p + n, 4 * (size_t) k);
 dprintf(H->out, "ok\n"); }

// ..the scene's bufs of group g whose balls lie inside each plane of the clip box through m,
// by their depth along it, and what their colours are times
static int by_w(void const *a, void const *b) { float const x = ((struct seen const*) a)->w, y = ((struct seen const*) b)->w; return (x > y) - (x < y); }
static int scene_seen(struct helper *H, float const *m, int g, int *out, float *mul) {
 struct seen *q = grow(H->sn, &H->csn, H->nscn, sizeof *q);
 if (!q) return 0;
 H->sn = q;
 float pl[6][4];
 for (int j = 0; j < 3; j++) for (int s = 0; s < 2; s++) for (int i = 0; i < 4; i++) pl[2 * j + s][i] = m[12 + i] + (s ? -m[4 * j + i] : m[4 * j + i]);
 int n = 0;
 for (int i = 0; i < H->nscn; i++) {
  float const *b = H->scn + 9 * i;
  int const kl = (int) b[5], mk = (int) b[8];
  float const k = kl < 0 ? 1 : kl < 1024 ? b[6] * H->kb[kl] : 0;
  int in = (int) b[7] == g && k != 0 && !(0 <= mk && mk < H->nvis && H->vis[mk] == 0);
  for (int j = 0; in && j < 6; j++) {
   float const d = pl[j][0] * b[1] + pl[j][1] * b[2] + pl[j][2] * b[3] + pl[j][3];
   float const l = pl[j][0] * pl[j][0] + pl[j][1] * pl[j][1] + pl[j][2] * pl[j][2];
   in = d >= 0 || d * d <= b[4] * b[4] * l; }
  if (in) q[n].w = m[12] * b[1] + m[13] * b[2] + m[14] * b[3] + m[15], q[n].k = k, q[n++].id = (int) b[0]; }
 qsort(q, (size_t) n, sizeof *q, by_w);
 for (int i = 0; i < n; i++) out[i] = q[i].id, mul[i] = q[i].k;
 return n; }

static void cmd_frame(struct helper *H, char *args) {
 enum { lead = 27 };   // w h off clear fr fg fb near far tone flags, then the 16 of m
 double v[lead + 4096];
 int n = words(args, v, lead + 4096);
 if (n < lead) { dprintf(H->out, "err frame args\n"); return; }
 int w = (int) v[0], h = (int) v[1];
 unsigned char *out = w > 0 && h > 0 ? bytes(H, (size_t) v[2], 8 * (size_t) w * h) : NULL;
 if (!out || !target(H, w, h)) { dprintf(H->out, "err frame target\n"); return; }
 int32_t clear = (int32_t) v[3];
 float c0[4] = { 0, 0, 0, 0 }, g0[4] = { 1, 1, 1, 0 };
 if (clear >= 0) c0[0] = (float) (clear & 255) / 255, c0[1] = (float) (clear >> 8 & 255) / 255, c0[2] = (float) (clear >> 16 & 255) / 255, c0[3] = 1;
 glViewport(0, 0, w, h);
 glBindFramebuffer(GL_FRAMEBUFFER, H->gb); glClearBufferfv(GL_COLOR, 0, g0);
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb); glClearBufferfv(GL_COLOR, 0, c0);
 glDepthMask(1); glClear(GL_DEPTH_BUFFER_BIT);
 glDisable(GL_CULL_FACE); glDisable(GL_BLEND);
 // ..the ground, then the smaller frame over it
 if (H->bpend || H->upend) {
  glUseProgram(H->uprog); glUniform2i(H->uu_fs, w, h);
  if (H->bpend) {
   // ..the test on but always passing: after a pass with it off, adreno misses glass over the smaller frame
   glUniform1i(H->uu_base, 1); glDepthMask(0); glDepthFunc(GL_ALWAYS);
   glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, H->bc);
   glDrawArrays(GL_TRIANGLES, 0, 3);
   glDepthMask(1); glDepthFunc(GL_LESS); H->bpend = 0; }
  if (H->upend) {
   glUniform1i(H->uu_base, 0); glUniform2i(H->uu_cs, H->uw, H->uh);
   glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, H->ud);
   glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, H->uc);
   glDrawArrays(GL_TRIANGLES, 0, 3);
   H->upend = 0; } }
 // y flips in clip, so what faces the eye winds clockwise here
 if ((int) v[10] & 8) glEnable(GL_CULL_FACE), glCullFace(GL_BACK), glFrontFace(GL_CW);
 glUseProgram(H->prog);
 float m[16];
 for (int i = 0; i < 16; i++) m[i] = (float) v[11 + i];
 glUniformMatrix4fv(H->u_m, 1, 1, m);   // row-major, so transposed
 // ..the bufs to draw, the scene's laid where its id is
 int *ids = grow(H->ids, &H->cids, n - lead + groups * H->nscn, sizeof *ids), ni = 0;
 float *mul = grow(H->mul, &H->cmul, n - lead + groups * H->nscn, sizeof *mul);
 if (!ids || !mul) { dprintf(H->out, "err frame room\n"); return; }
 H->ids = ids, H->mul = mul;
 for (int k = lead; k < n; k++) {
  int const id = (int) v[k], g = scene_id - id;
  ni += 0 <= g && g < groups ? scene_seen(H, m, g, ids + ni, mul + ni) : (ids[ni] = id, mul[ni] = 1, 1); }
 glUniform3f(H->u_fog, (float) v[4], (float) v[5], (float) v[6]);
 glUniform2f(H->u_fz, (float) v[7], v[8] > v[7] ? (float) (1 / (v[8] - v[7])) : 0);
 glUniform1f(H->u_tone, (float) v[9]); glUniform2f(H->u_vp, (float) w, (float) h);
 int const sun = ((int) v[10] & 256) && H->sm;
 glUniform1i(H->u_sun, sun);
 if (sun) {
  glUniformMatrix4fv(H->u_lm, 1, 1, H->lm); glUniform1f(H->u_bias, H->bias); glUniform2i(H->u_ss, H->sw, H->sh);
  glActiveTexture(GL_TEXTURE3); glBindTexture(GL_TEXTURE_2D, H->sm); glActiveTexture(GL_TEXTURE0); }
 // ..seen: the lenses' nearest depths, each alone, before all; else none, as far as can be
 glBindFramebuffer(GL_FRAMEBUFFER, H->lf); glDepthMask(1); glClear(GL_DEPTH_BUFFER_BIT);
 if ((int) v[10] & 128) {
  mode(H, 0); glActiveTexture(GL_TEXTURE2); glBindTexture(GL_TEXTURE_2D, 0); glActiveTexture(GL_TEXTURE0);
  glUseProgram(H->dprog); glUniformMatrix4fv(H->ud_m, 1, 1, m); glUniform2f(H->ud_vp, (float) w, (float) h);
  for (int k = 0; k < ni; k++) {
   struct buf *b = buf_of(H, ids[k]);
   if (!b) continue;
   glBindVertexArray(b->vao);
   for (int r = 0; r < b->nrun; r++)
    if (b->runs[r].tex <= -3 - lensed) glUniform3f(H->ud_off, b->off[0], b->off[1], b->off[2]), glDrawElements(GL_TRIANGLES, b->runs[r].n, GL_UNSIGNED_INT, (void*) (4 * (uintptr_t) b->runs[r].at)); }
  glUseProgram(H->prog); }
 glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
 glActiveTexture(GL_TEXTURE2); glBindTexture(GL_TEXTURE_2D, H->lz);
 glActiveTexture(GL_TEXTURE0);
 // ..what is opaque first, then the glows and the glass in their order; between, when the
 // glows face the eye, a copy of the depths they fade by
 int const ey = H->epend;
 float const *e = H->eye;
 H->epend = 0;
 glUniform4f(H->u_gz, e[6], e[7], e[8], ey ? e[9] : 0);
 glUniform3f(H->u_br, e[0], e[1], e[2]); glUniform3f(H->u_bu, e[3], e[4], e[5]); glUniform1i(H->u_bb, 0);
 // ..the clouds' shadows, where the sky is asked a pixel at a time
 int const cs = H->spend && H->sky < 0 && H->cmt && H->nkp >= 51 && H->kp[50] > 0;
 glUniform1f(H->u_csh, cs ? 1 / H->kp[50] : 0);
 if (cs) glUniform1fv(H->u_kp, 51, H->kp), glActiveTexture(GL_TEXTURE8), glBindTexture(GL_TEXTURE_2D, H->cmt), glActiveTexture(GL_TEXTURE0);
 int glassy = 0;
 for (int pass = 0; pass < 2; pass++) {
  if (pass && ey) {
   glBindFramebuffer(GL_READ_FRAMEBUFFER, H->fb); glBindFramebuffer(GL_DRAW_FRAMEBUFFER, H->zf);
   glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
   glBindFramebuffer(GL_FRAMEBUFFER, H->fb);
   glActiveTexture(GL_TEXTURE6); glBindTexture(GL_TEXTURE_2D, H->zt); glActiveTexture(GL_TEXTURE0); }
  for (int k = 0; k < ni; k++) {
   struct buf *b = buf_of(H, ids[k]);
   if (!b) continue;
   glBindVertexArray(b->vao);
   glUniform1i(H->u_bb, ey && b->glow); glUniform1iv(H->u_li, 8, b->li); glUniform1f(H->u_sh, mul[k]); glUniform3f(H->u_off, b->off[0], b->off[1], b->off[2]);
   for (int r = 0; r < b->nrun; r++) {
    int const tx = code(b->runs[r].tex), m = tx >= -1 ? 0 : tx == -2 ? 1 : 2;
    if ((m != 0) != pass) continue;
    glUniform1i(H->u_cls, class(b->runs[r].tex));
    struct tex *t = tx >= 0 ? tex_of(H, tx) : tx <= -3 ? tex_of(H, -3 - tx) : NULL;
    glUniform1i(H->u_has, t != NULL);
    if (t) glBindTexture(GL_TEXTURE_2D, t->gl), glUniform2f(H->u_ts, (float) t->w, (float) t->h);
    uintptr_t const at = (uintptr_t) b->runs[r].at;
    if (m != 2) { mode(H, m); glDrawElements(GL_TRIANGLES, b->runs[r].n, GL_UNSIGNED_INT, (void*) (4 * at)); continue; }
    glass(H, 2, b->runs[r].n, at);
    glBindFramebuffer(GL_FRAMEBUFFER, H->gb);   // ..and on what is bare, its tint and sheen
    glass(H, 3, b->runs[r].n, at);
    glBindFramebuffer(GL_FRAMEBUFFER, H->fb); glassy = 1; } } }
 glUniform1i(H->u_bb, 0); glUniform4f(H->u_gz, 0, 0, 0, 0);
 // ..last, where any glass fell on the bare: in any order, a glow there is what it shows
 glUniform1i(H->u_cls, 0);
 for (int k = 0; glassy && k < ni; k++) {
  struct buf *b = buf_of(H, ids[k]);
  if (!b) continue;
  glBindVertexArray(b->vao); glUniform1iv(H->u_li, 8, b->li); glUniform1f(H->u_sh, mul[k]); glUniform3f(H->u_off, b->off[0], b->off[1], b->off[2]);
  for (int r = 0; r < b->nrun; r++) {
   int const tx = code(b->runs[r].tex);
   if (tx > -3) continue;
   struct tex *t = tex_of(H, -3 - tx);
   glUniform1i(H->u_has, t != NULL);
   if (t) glBindTexture(GL_TEXTURE_2D, t->gl), glUniform2f(H->u_ts, (float) t->w, (float) t->h);
   mode(H, 4);
   glDrawElements(GL_TRIANGLES, b->runs[r].n, GL_UNSIGNED_INT, (void*) (4 * (uintptr_t) b->runs[r].at)); } }
 glBindVertexArray(0); mode(H, 0); glUniform1f(H->u_sh, 1); glUniform3f(H->u_off, 0, 0, 0);
 // ..and the sky, under what is bare, onto what the frame keeps there
 struct buf *sb = H->spend && H->sky >= 0 ? buf_of(H, H->sky) : NULL;
 int const ps = H->spend && H->sky < 0 && H->cmt && H->amt && H->nkp >= 50;
 H->spend = 0;
 if (ps && !H->fva) {   // ..a triangle over the whole frame, in clip
  static float const tri[9] = { -1, -1, 0.5f, 3, -1, 0.5f, -1, 3, 0.5f };
  glGenVertexArrays(1, &H->fva); glBindVertexArray(H->fva);
  glGenBuffers(1, &H->fvb); glBindBuffer(GL_ARRAY_BUFFER, H->fvb);
  glBufferData(GL_ARRAY_BUFFER, sizeof tri, tri, GL_STATIC_DRAW);
  glVertexAttribPointer(0, 3, GL_FLOAT, 0, 12, (void*) 0); glEnableVertexAttribArray(0); }
 if (sb || ps) {
  glActiveTexture(GL_TEXTURE4); glBindTexture(GL_TEXTURE_2D, H->mk); glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, w, h);
  glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); mode(H, 5);
  glUniform1i(H->u_has, 0); glUniform1i(H->u_cls, 0); glUniform1i(H->u_sun, 0); glUniform1i(H->u_fg, H->fglass);
  glUniform2f(H->u_fz, 0, 0); glUniform1f(H->u_tone, H->stone); glUniform3f(H->u_off, H->soff[0], H->soff[1], H->soff[2]);
  glActiveTexture(GL_TEXTURE5); glBindTexture(GL_TEXTURE_2D, H->gr);
  int const sp = H->opend && H->ow == w && H->oh == h;
  if (sp) glActiveTexture(GL_TEXTURE7), glBindTexture(GL_TEXTURE_2D, H->ot);
  glActiveTexture(GL_TEXTURE0); glUniform1i(H->u_sp, sp);
  if (sb) {
   glBindVertexArray(sb->vao);
   for (int r = 0; r < sb->nrun; r++) glDrawElements(GL_TRIANGLES, sb->runs[r].n, GL_UNSIGNED_INT, (void*) (4 * (uintptr_t) sb->runs[r].at)); }
  else {
   static float const id4[16] = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };
   glUniformMatrix4fv(H->u_m, 1, 1, id4); glUniform3f(H->u_off, 0, 0, 0);
   glUniform1fv(H->u_kp, 51, H->kp); glUniform1i(H->u_skm, 1);
   glActiveTexture(GL_TEXTURE8); glBindTexture(GL_TEXTURE_2D, H->cmt); glActiveTexture(GL_TEXTURE9); glBindTexture(GL_TEXTURE_2D, H->amt); glActiveTexture(GL_TEXTURE0);
   glBindVertexArray(H->fva); glDrawArrays(GL_TRIANGLES, 0, 3);
   glUniform1i(H->u_skm, 0); glUniformMatrix4fv(H->u_m, 1, 1, m); }
  glBindVertexArray(0); mode(H, 0); glEnable(GL_DEPTH_TEST); glUniform1i(H->u_sp, 0); glUniform3f(H->u_off, 0, 0, 0); }
 H->opend = 0;
 // ..with keep, left unread where no pixel is the cpu's to finish: none where the sky was
 // asked a pixel at a time, which finishes every bare one, else one asked of the gpu
 if ((int) v[10] & 512) {
  GLuint any = 0;
  if (!ps) {
   glBindFramebuffer(GL_FRAMEBUFFER, H->lf); glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); glDepthMask(0);
   glUseProgram(H->kprog); glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, H->rb);
   any = 1;
   glBeginQuery(GL_ANY_SAMPLES_PASSED, H->kq); glDrawArrays(GL_TRIANGLES, 0, 3); glEndQuery(GL_ANY_SAMPLES_PASSED);
   glGetQueryObjectuiv(H->kq, GL_QUERY_RESULT, &any);
   glBindFramebuffer(GL_FRAMEBUFFER, H->fb); glEnable(GL_DEPTH_TEST); glDepthMask(1); glUseProgram(H->prog); }
  if (!any) {
   int const k = H->ks;
   glActiveTexture(GL_TEXTURE4); glBindTexture(GL_TEXTURE_2D, H->kt[k]); glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, w, h);
   glBindTexture(GL_TEXTURE_2D, H->mk); glActiveTexture(GL_TEXTURE0);
   H->kv[k] = 1, H->ks = !k; dprintf(H->out, "kept %d\n", k); return; } }
 size_t const N = (size_t) w * h;
 glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, out + 4 * N);
 if (glassy) {
  glBindFramebuffer(GL_FRAMEBUFFER, H->gb);
  glReadPixels(0, 0, w, h, GL_RGBA, H->fglass ? GL_FLOAT : GL_UNSIGNED_BYTE, H->gx);
  glBindFramebuffer(GL_FRAMEBUFFER, H->fb); }
 // ..as facets's words, signed in 8 bytes, laid over what was read only once it is read:
 // drawn, a bare -1 less its glows, where glass fell -2^25 less its tint and its sheen over
 // 4 (kept on its own, its top byte), or -1. in floats each rounded as facets rounds it
 for (size_t i = 0; i < N; i++) {
  uint32_t a, x = 0; memcpy(&a, out + 4 * (N + i), 4);
  int32_t const q = (int32_t) (a & 0xffffff);
  unsigned const A = a >> 24;
  if (A <= 192 && !q && A && glassy) {
   if (!H->fglass) memcpy(&x, H->gx + 4 * i, 4);
   else {
    float f[4]; memcpy(f, H->gx + 16 * i, 16);
    x = ch(255 * f[2]) << 16 | ch(255 * f[1]) << 8 | ch(255 * f[0]) | (ch(1020 * f[3]) / 4) << 24; } }
  int64_t const o = A > 192 ? q | (int64_t) (A == 254) << 32 : q ? -1 - q : A ? -33554432 - (int64_t) x : -1;
  memcpy(out + 8 * i, &o, 8); }
 dprintf(H->out, "ok\n"); }

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
  ssize_t r = read(H->in, H->line + H->got, sizeof H->line - H->got);
  if (r <= 0) return NULL;
  H->got += (size_t) r; } }

// a session: lines from H->in, answered on H->out, the bulk in file; x for a window's display
static int serve(struct helper *H, char const *file, int x) {
 H->fd = open(file, O_RDWR | O_CLOEXEC);
 if (H->fd < 0) { dprintf(H->out, "err cannot open %s\n", file); return 2; }
 if (!setup(H, x)) return 3;
 // ..the gpu drawing unseen, rather than a window's display drawing slower, but with LOVE_GPU_SOFT=1
 char const *sf = getenv("LOVE_GPU_SOFT");
 if (H->xd && soft() && !(sf && !strcmp(sf, "1"))) {
  eglMakeCurrent(H->d, NULL, NULL, NULL), eglTerminate(H->d), H->xd = NULL;
  if (!setup(H, 0)) return 3; }
 dprintf(H->out, "ready %s\n", glGetString(GL_RENDERER));
 for (char *l; (l = next_line(H)); ) {
  int id, a, b, c, k; long off; double tone;
  if (!strncmp(l, "tex ", 4) && sscanf(l + 4, "%d %d %d %d %ld", &id, &a, &b, &c, &off) == 5) cmd_tex(H, id, a, b, c, (size_t) off);
  else if (!strncmp(l, "buf ", 4) && (k = sscanf(l + 4, "%d %d %d %ld %d", &id, &a, &b, &off, &c)) >= 4) cmd_buf(H, id, a, b, (size_t) off, k == 5 ? c : 8);
  else if (!strncmp(l, "verts ", 6) && sscanf(l + 6, "%d %d %ld %d", &id, &a, &off, &c) == 4) cmd_verts(H, id, a, (size_t) off, c);
  else if (!strncmp(l, "sun ", 4)) cmd_sun(H, l + 4);
  else if (!strncmp(l, "suns ", 5) && sscanf(l + 5, "%d %d %ld", &id, &a, &off) == 3) cmd_suns(H, id, a, (size_t) off);
  else if (!strncmp(l, "lamps ", 6)) {
   int li[8]; if (sscanf(l + 6, "%d %d %ld %d %d %d %d %d %d %d %d", &id, &a, &off, li, li + 1, li + 2, li + 3, li + 4, li + 5, li + 6, li + 7) == 11) cmd_lamps(H, id, a, (size_t) off, li);
   else dprintf(H->out, "err what: %s\n", l); }
  else if (!strncmp(l, "ks", 2) && (l[2] == ' ' || !l[2])) cmd_ks(H, l + 2);
  else if (!strncmp(l, "win ", 4)) cmd_win(H, strtoul(l + 4, NULL, 10));
  else if (!strncmp(l, "show ", 5)) cmd_show(H, l + 5);
  else if (!strncmp(l, "sky ", 4) && sscanf(l + 4, "%d %lf", &id, &tone) == 2) {
   double e[3] = {0, 0, 0};
   sscanf(l + 4, "%*d %*f %lf %lf %lf", &e[0], &e[1], &e[2]);
   cmd_sky(H, id, tone, e); }
  else if (!strncmp(l, "spots ", 6) && sscanf(l + 6, "%d %d %d %ld", &a, &b, &c, &off) == 4) cmd_spots(H, a, b, c, (size_t) off);
  else if (!strncmp(l, "glow ", 5)) cmd_glow(H, l + 5);
  else if (!strncmp(l, "drop ", 5) && sscanf(l + 5, "%d", &id) == 1) cmd_drop(H, id);
  else if (!strncmp(l, "under ", 6) && sscanf(l + 6, "%d %d %ld", &a, &b, &off) == 3) cmd_under(H, a, b, (size_t) off);
  else if (!strncmp(l, "base ", 5) && sscanf(l + 5, "%d %d %ld", &a, &b, &off) == 3) cmd_base(H, a, b, (size_t) off);
  else if (!strncmp(l, "cloud ", 6) && sscanf(l + 6, "%d %ld", &a, &off) == 2) cmd_cloud(H, a, (size_t) off);
  else if (!strncmp(l, "air ", 4) && sscanf(l + 4, "%d %d %ld", &a, &b, &off) == 3) cmd_air(H, a, b, (size_t) off);
  else if (!strncmp(l, "skyp ", 5)) cmd_skyp(H, l + 5);
  else if (!strncmp(l, "place ", 6)) cmd_place(H, l + 6);
  else if (!strncmp(l, "vis ", 4) && sscanf(l + 4, "%d %d %ld", &a, &b, &off) == 3) cmd_vis(H, a, b, (size_t) off);
  else if (!strncmp(l, "scene ", 6) && sscanf(l + 6, "%d %ld", &a, &off) == 2) cmd_scene(H, a, (size_t) off);
  else if (!strncmp(l, "frame ", 6)) cmd_frame(H, l + 6);
  else if (!strcmp(l, "quit")) break;
  else dprintf(H->out, "err what: %s\n", l); }
 return 0; }

#ifndef GLHELP_IN
int main(int argc, char **argv) {
 struct helper *H = calloc(1, sizeof *H);
 if (!H) { dprintf(1, "err no memory\n"); return 2; }
 H->out = 1, H->zk = 1;
 if (argc < 2) { dprintf(1, "err usage: glhelp FILE\n"); return 2; }
 return serve(H, argv[1], argc > 2 && !strcmp(argv[2], "x")); }
#else
// in an app's own process (the droid bridge): lines on fd, the first naming the file; hook(ctx, 0,
// W, H) the window to show a picture's window W by H on, or 0, held until hook(ctx, 1, 0, 0);
// hook(ctx, 2, 0, 0) once the session's gl is gone
int glhelp_serve(int fd, void *(*hook) (void *, int, int, int), void *ctx) {
 struct helper *H = calloc(1, sizeof *H);
 if (!H) return 2;
 H->in = H->out = fd, H->fd = -1, H->zk = 1, H->hook = hook, H->ctx = ctx;
 char *f = next_line(H);
 int r = f ? serve(H, f, 0) : 2;
 // ..all of it gone with the context, the process going on
 if (H->d && H->c) {
  for (int i = 0; i < H->nbuf; i++) buf_free(H->bufs + i);
  eglMakeCurrent(H->d, NULL, NULL, NULL);
  if (H->ws) eglDestroySurface(H->d, H->ws);
  if (H->ps) eglDestroySurface(H->d, H->ps);
  eglDestroyContext(H->d, H->c); }
 hook(ctx, 2, 0, 0);
 if (H->map) munmap(H->map, H->sz);
 if (H->fd >= 0) close(H->fd);
 free(H->texs), free(H->bufs), free(H->gx), free(H->scn), free(H->ids), free(H->sn), free(H->mul), free(H->vis), free(H);
 return r; }
#endif
