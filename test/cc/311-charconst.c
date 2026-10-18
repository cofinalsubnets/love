/* a one-char constant is (int) (char) c: '\xc8' is -56 where plain char is signed (x86-64),
 * 200 where it is unsigned (a64, rv64, arm), and #if reads it as the code does */
#if '\xc8' < 0
static const int pp = 1;
#else
static const int pp = 0;
#endif

int main(void)
{
  char c = '\xc8';
  int k = '\xc8';
  int ok = (k == c) + 2 * (pp == (c < 0)) + 4 * ('\x7f' == 127) + 8 * ('a' == 97);
  return 40 + ok;   /* 55 */
}
