// inle/doomsnd.c -- doom's sound: the sound_module_t doomgeneric asks for, mixed
// in software and handed to the horn's C face (love.h's ai_horn_*: inle/hda.c
// under inle, the host's card otherwise). rides the DOOM=1 lane beside doom.c and is
// otherwise not built.
//
// eight channels of DMX lumps (8-bit unsigned mono, mostly 11025 Hz, behind an
// 8-byte header and 16 bytes of padding each side) resampled linearly to the
// device's 48k and mixed with volume and separation into 16-bit stereo. the mix
// keeps a short lead over the play head -- ds_lead frames -- so a shot is heard
// when it is fired; the ring under it is deeper, which is what keeps a slow frame
// from underrunning. music is silent: the lumps are MUS and want a synthesizer.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "doomtype.h"
#include "i_sound.h"
#include "w_wad.h"
#include "z_zone.h"
#include "deh_str.h"
#include "m_misc.h"

// the horn's C face (love.h)
int ai_horn_open(int rate);
intptr_t ai_horn_write(unsigned char const*, uintptr_t);
uintptr_t ai_horn_lag(void);
void ai_horn_close(void);

#define ds_rate 48000
#define ds_lead 4800                 // 100 ms ahead of the head: latency, by ear
#define ds_chunk 1024                // frames mixed per pass
#define ds_chn 16                    // >= snd_channels (8): the game names them

struct ds_sample { unsigned char const *s; uint32_t len, rate; };
struct ds_chan { struct ds_sample const *smp; uint32_t pos, step; int left, right; };
static struct { struct ds_chan ch[ds_chn]; boolean prefix; int on; } ds;

// the sfx's lump name: ds<name>, through a link and the dehacked table
static void lump_name(sfxinfo_t *sfx, char *buf, size_t n) {
 if (sfx->link) sfx = sfx->link;
 if (ds.prefix) M_snprintf(buf, n, "ds%s", DEH_String(sfx->name));
 else M_StringCopy(buf, DEH_String(sfx->name), n); }

// the parsed lump, cached on the sfx for the run: format 3, rate, length, then the
// samples inside their padding. a lump that is not DMX answers NULL and is silent.
static struct ds_sample const *sample_of(sfxinfo_t *sfx) {
 if (sfx->driver_data) return sfx->driver_data;
 if (sfx->lumpnum < 0) return NULL;
 unsigned char const *d = W_CacheLumpNum(sfx->lumpnum, PU_STATIC);
 uint32_t n = (uint32_t) W_LumpLength((unsigned) sfx->lumpnum);
 if (n < 8 || d[0] != 3 || d[1] != 0) return NULL;
 uint32_t rate = d[2] | (uint32_t) d[3] << 8, len = d[4] | (uint32_t) d[5] << 8 | (uint32_t) d[6] << 16 | (uint32_t) d[7] << 24;
 if (len > n - 8 || len <= 48 || !rate) return NULL;
 struct ds_sample *s = Z_Malloc(sizeof *s, PU_STATIC, 0);
 s->s = d + 24, s->len = len - 32, s->rate = rate;
 return sfx->driver_data = s; }

// --- the module --------------------------------------------------------------
static boolean ds_init(boolean use_sfx_prefix) {
 ds.prefix = use_sfx_prefix;
 ds.on = ai_horn_open(ds_rate) == 0;
 fprintf(stderr, "doomsnd: %s\n", ds.on ? "the horn is open at 48000 Hz" : "no horn, silent");
 return ds.on; }

static void ds_shutdown(void) {
 if (ds.on) ai_horn_close();
 ds.on = 0; }

static int ds_lump(sfxinfo_t *sfx) {
 char nm[9];
 lump_name(sfx, nm, sizeof nm);
 return W_GetNumForName(nm); }

// doom's own pan law: vol 0..127, sep 0..255, each side 0..255
static void ds_params(int c, int vol, int sep) {
 if (c < 0 || c >= ds_chn) return;
 int l = ((254 - sep) * vol) / 127, r = (sep * vol) / 127;
 ds.ch[c].left = l < 0 ? 0 : l > 255 ? 255 : l;
 ds.ch[c].right = r < 0 ? 0 : r > 255 ? 255 : r; }

static int ds_start(sfxinfo_t *sfx, int c, int vol, int sep) {
 if (!ds.on || c < 0 || c >= ds_chn) return -1;
 struct ds_sample const *s = sample_of(sfx);
 if (!s) return -1;
 ds.ch[c].smp = s;
 ds.ch[c].pos = 0;
 ds.ch[c].step = (uint32_t) (((uint64_t) s->rate << 16) / ds_rate);
 ds_params(c, vol, sep);
 return c; }

static void ds_stop(int c) {
 if (c >= 0 && c < ds_chn) ds.ch[c].smp = NULL; }

static boolean ds_playing(int c) {
 return c >= 0 && c < ds_chn && ds.ch[c].smp != NULL; }

// one chunk of frames: every live channel, resampled and panned, summed and clipped
static void mix(int16_t *out, uint32_t frames) {
 memset(out, 0, frames * 4);
 for (int c = 0; c < ds_chn; c++) {
  struct ds_chan *ch = &ds.ch[c];
  struct ds_sample const *s = ch->smp;
  if (!s) continue;
  for (uint32_t i = 0; i < frames; i++) {
   uint32_t k = ch->pos >> 16, f = ch->pos & 0xffff;
   if (k + 1 >= s->len) { ch->smp = NULL; break; }
   int a = (int) s->s[k] - 128, b = (int) s->s[k + 1] - 128;
   int v = (a * (int) (0x10000 - f) + b * (int) f) >> 8;   // 16-bit, interpolated
   int l = out[2 * i] + (v * ch->left >> 8), r = out[2 * i + 1] + (v * ch->right >> 8);
   out[2 * i] = (int16_t) (l > 32767 ? 32767 : l < -32768 ? -32768 : l);
   out[2 * i + 1] = (int16_t) (r > 32767 ? 32767 : r < -32768 ? -32768 : r);
   ch->pos += ch->step; } } }

// every frame: top the lead up. a short land is a full ring, which the lead keeps
// far from -- so what was mixed is what was heard.
static void ds_update(void) {
 if (!ds.on) return;
 int16_t buf[2 * ds_chunk];
 uintptr_t lag = ai_horn_lag();
 while (lag < ds_lead) {
  uint32_t n = (uint32_t) (ds_lead - lag);
  if (n > ds_chunk) n = ds_chunk;
  mix(buf, n);
  if (ai_horn_write((unsigned char const*) buf, n * 4) < (intptr_t) (n * 4)) break;
  lag += n; } }

static void ds_cache(sfxinfo_t *sounds, int n) { }

static snddevice_t ds_devices[] = { SNDDEVICE_SB };
sound_module_t DG_sound_module = {
 ds_devices, 1,
 ds_init, ds_shutdown, ds_lump, ds_update, ds_params, ds_start, ds_stop, ds_playing, ds_cache };

// --- music: the door is there and nothing comes through it ------------------
static boolean mu_init(void) { return true; }
static void mu_none(void) { }
static void mu_volume(int v) { }
static void *mu_register(void *data, int len) { return NULL; }
static void mu_unregister(void *h) { }
static void mu_play(void *h, boolean loop) { }
static boolean mu_playing(void) { return false; }
music_module_t DG_music_module = {
 ds_devices, 1,
 mu_init, mu_none, mu_volume, mu_none, mu_none, mu_register, mu_unregister, mu_play, mu_none,
 mu_playing, mu_none };

// what i_sound.c names under FEATURE_SOUND and i_sdlsound.c would have defined
int use_libsamplerate = 0;
float libsamplerate_scale = 0.65f;
