// singles no vfp immediate reaches, loaded from pools: near a jump's island, past a vldr's reach
// down a long straight run, one word shared by several reads, in a loop and across a call
#include <stdint.h>

volatile float sink;
__attribute__((noinline)) static float id(float x) { return x; }
__attribute__((noinline)) static float run(float x) {
 // straight-line, a fresh constant each read: the early reads' pool is past a vldr's reach
 float a = x * 1.1f + 2.3f, b = a * 0.7071f - 3.3f, c = b * 1.4142f + a * 0.3333f;
 a = a * 1.00037f + 0.00123f; sink = a; b = b * 1.00074f + 0.00233f; sink = b; c = c * 1.00111f + 0.00343f; sink = c;
 a = a * 1.00148f + 0.00453f; sink = a; b = b * 1.00185f + 0.00563f; sink = b; c = c * 1.00222f + 0.00673f; sink = c;
 a = a * 1.00259f + 0.00783f; sink = a; b = b * 1.00296f + 0.00893f; sink = b; c = c * 1.00333f + 0.01003f; sink = c;
 a = a * 1.00370f + 0.01113f; sink = a; b = b * 1.00407f + 0.01223f; sink = b; c = c * 1.00444f + 0.01333f; sink = c;
 a = a * 1.00481f + 0.01443f; sink = a; b = b * 1.00518f + 0.01553f; sink = b; c = c * 1.00555f + 0.01663f; sink = c;
 a = a * 1.00592f + 0.01773f; sink = a; b = b * 1.00629f + 0.01883f; sink = b; c = c * 1.00666f + 0.01993f; sink = c;
 a = a * 1.00703f + 0.02103f; sink = a; b = b * 1.00740f + 0.02213f; sink = b; c = c * 1.00777f + 0.02323f; sink = c;
 a = a * 1.00814f + 0.02433f; sink = a; b = b * 1.00851f + 0.02543f; sink = b; c = c * 1.00888f + 0.02653f; sink = c;
 a = a * 1.00925f + 0.02763f; sink = a; b = b * 1.00962f + 0.02873f; sink = b; c = c * 1.00999f + 0.02983f; sink = c;
 a = a * 1.01036f + 0.03093f; sink = a; b = b * 1.01073f + 0.03203f; sink = b; c = c * 1.01110f + 0.03313f; sink = c;
 a = a * 1.01147f + 0.03423f; sink = a; b = b * 1.01184f + 0.03533f; sink = b; c = c * 1.01221f + 0.03643f; sink = c;
 a = a * 1.01258f + 0.03753f; sink = a; b = b * 1.01295f + 0.03863f; sink = b; c = c * 1.01332f + 0.03973f; sink = c;
 a = a * 1.01369f + 0.04083f; sink = a; b = b * 1.01406f + 0.04193f; sink = b; c = c * 1.01443f + 0.04303f; sink = c;
 a = a * 1.01480f + 0.04413f; sink = a; b = b * 1.01517f + 0.04523f; sink = b; c = c * 1.01554f + 0.04633f; sink = c;
 a = a * 1.01591f + 0.04743f; sink = a; b = b * 1.01628f + 0.04853f; sink = b; c = c * 1.01665f + 0.04963f; sink = c;
 a = a * 1.01702f + 0.05073f; sink = a; b = b * 1.01739f + 0.05183f; sink = b; c = c * 1.01776f + 0.05293f; sink = c;
 a = a * 1.01813f + 0.05403f; sink = a; b = b * 1.01850f + 0.05513f; sink = b; c = c * 1.01887f + 0.05623f; sink = c;
 a = a * 1.01924f + 0.05733f; sink = a; b = b * 1.01961f + 0.05843f; sink = b; c = c * 1.01998f + 0.05953f; sink = c;
 a = a * 1.02035f + 0.06063f; sink = a; b = b * 1.02072f + 0.06173f; sink = b; c = c * 1.02109f + 0.06283f; sink = c;
 a = a * 1.02146f + 0.06393f; sink = a; b = b * 1.02183f + 0.06503f; sink = b; c = c * 1.02220f + 0.06613f; sink = c;
 a = a * 1.02257f + 0.06723f; sink = a; b = b * 1.02294f + 0.06833f; sink = b; c = c * 1.02331f + 0.06943f; sink = c;
 a = a * 1.02368f + 0.07053f; sink = a; b = b * 1.02405f + 0.07163f; sink = b; c = c * 1.02442f + 0.07273f; sink = c;
 a = a * 1.02479f + 0.07383f; sink = a; b = b * 1.02516f + 0.07493f; sink = b; c = c * 1.02553f + 0.07603f; sink = c;
 a = a * 1.02590f + 0.07713f; sink = a; b = b * 1.02627f + 0.07823f; sink = b; c = c * 1.02664f + 0.07933f; sink = c;
 a = a * 1.02701f + 0.08043f; sink = a; b = b * 1.02738f + 0.08153f; sink = b; c = c * 1.02775f + 0.08263f; sink = c;
 a = a * 1.02812f + 0.08373f; sink = a; b = b * 1.02849f + 0.08483f; sink = b; c = c * 1.02886f + 0.08593f; sink = c;
 a = a * 1.02923f + 0.08703f; sink = a; b = b * 1.02960f + 0.08813f; sink = b; c = c * 1.02997f + 0.08923f; sink = c;
 a = a * 1.03034f + 0.09033f; sink = a; b = b * 1.03071f + 0.09143f; sink = b; c = c * 1.03108f + 0.09253f; sink = c;
 a = a * 1.03145f + 0.09363f; sink = a; b = b * 1.03182f + 0.09473f; sink = b; c = c * 1.03219f + 0.09583f; sink = c;
 a = a * 1.03256f + 0.09693f; sink = a; b = b * 1.03293f + 0.09803f; sink = b; c = c * 1.03330f + 0.09913f; sink = c;
 a = a * 1.03367f + 0.10023f; sink = a; b = b * 1.03404f + 0.10133f; sink = b; c = c * 1.03441f + 0.10243f; sink = c;
 a = a * 1.03478f + 0.10353f; sink = a; b = b * 1.03515f + 0.10463f; sink = b; c = c * 1.03552f + 0.10573f; sink = c;
 return a * 6.2832f + b * 2.7183f + c * 1.6180f;
}
__attribute__((noinline)) static float poly(const float *v, int n) {
 float t = 0;
 for (int i = 0; i < n; i++) {
  float x = v[i], x2 = x * x;
  t += x * (0.9998f + x2 * (-0.1658f + x2 * (0.0076f - x2 * 0.00018f)));
  if (t > 1000.5f) t = t * 0.001f;
 }
 return t + id(3.14159f) - 3.14159f;
}

int main(void) {
 float v[12];
 for (int i = 0; i < 12; i++) v[i] = (float) i * 0.37f - 2.1f;
 float r = run(0.25f), p = poly(v, 12);
 int32_t s = (int32_t) (r * 1000) * 31 + (int32_t) (p * 100000);
 return (int) ((uint32_t) s % 251);
}
