// the stones song, apartment.l's, for the speaker: a drone of two sines under a music-box
// phrase every 17 s or so, its echoes off a delay line; every voice tones_run's operators
#pragma once
#include <stdint.h>
#include "../../../src/love/audio/tones.h"

enum { sg_rate = 16000, sg_chunk = 256, sg_notes = 4, sg_parts = 3, sg_dl = 8192 };

// a box note: its partials' rows, from frame 0 at its start, and their feedback
struct sg_note { uint32_t at, end, no; tn_flo ops[sg_parts * tn_row], st[2 * sg_parts]; };

struct song {
  uint32_t z, pos, next;     // the dice, the frames played, the next phrase's frame
  int lr;                    // the last phrase's octave, -1 none
  tn_flo drone[2 * tn_row], dst[4];
  struct sg_note nt[sg_notes];
  tn_flo dl[sg_dl];          // the box's sum, read again by the echoes
  tn_flo sc[sg_parts * sg_chunk], L[sg_chunk], B[sg_chunk];
};

void song_init(struct song *s, uint32_t seed);
// the next n frames (a whole number of chunks) as n duties out of top
void song_fill(struct song *s, uint16_t *d, uint32_t n, uint32_t top);
