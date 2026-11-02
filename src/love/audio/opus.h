// src/love/audio/opus.h -- what opus.c, silk.c and celt.c share: the range decoder (rfc 6716
// 4.1) and each layer's door. every state lives in the caller's cask; nothing allocates.
#ifndef LOVE_OPUS_H
#define LOVE_OPUS_H
#include <stdint.h>

// the range decoder over one frame: symbols from the front, raw bits from the back
struct rdec {
 const uint8_t *buf;
 uint32_t len, off, eoff;   // the bytes, the next from the front, those taken from the back
 uint32_t rng, val, ext;    // the range, the value within it, the last division's step
 uint32_t ew; int en;       // the back's bit window and its fill
 int rem, bits, err;        // the byte under the front, bits used, a malformed stream seen
};
void rd_init(struct rdec *d, const uint8_t *buf, uint32_t len);
unsigned rd_freq(struct rdec *d, unsigned ft);                    // a frequency in [0, ft)
unsigned rd_freqb(struct rdec *d, unsigned bits);                 // the same, ft = 1 << bits
void rd_take(struct rdec *d, unsigned fl, unsigned fh, unsigned ft);   // consume [fl, fh)
int rd_logp(struct rdec *d, unsigned logp);                       // 1 with chance 1 / 2^logp
int rd_icdf(struct rdec *d, const uint8_t *icdf, unsigned ftb);   // a symbol by an inverse cdf
uint32_t rd_uint(struct rdec *d, uint32_t ft);                    // uniform in [0, ft)
uint32_t rd_raw(struct rdec *d, unsigned bits);                   // raw bits from the back
int rd_ilog(uint32_t v);                                          // bits to write v, 0 for 0
int rd_tell(const struct rdec *d);                                // whole bits used
uint32_t rd_tellf(const struct rdec *d);                          // eighth bits used

// the decoder (opusdec.c): op_size bytes, laid by op_init for ch output channels (1 or 2);
// op_decode takes one packet (len 0 conceals a lost one) into pcm, 48 kHz floats ch
// interleaved, at most n a channel -> samples a channel | -why (1 a bad argument, 2 too
// little room, 3 an internal fault, 4 a malformed packet)
int op_size(void);
int op_init(void *b, int ch);
int op_decode(void *b, const uint8_t *p, int len, float *pcm, int n);
uint32_t op_final(const void *b);                                 // the last packet's final range

#endif
