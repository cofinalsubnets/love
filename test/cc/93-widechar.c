/* wide/prefixed char constants L'a', u'x', U'x' (escapes too) answer the plain
   code; identifiers merely starting with L/u/U are untouched. */
int main(void)
{
  int a = L'A';        /* 65 */
  int b = u'B';        /* 66 */
  int c = U'C';        /* 67 */
  int nl = L'\n';      /* 10 -- escape through the prefix */

  int Long = 5;        /* an identifier beginning with L is not a prefix */
  int under = 3;       /* ...nor u */

  /* 65 + 66 + 67 + 10 + 5 + 3 = 216 */
  return a + b + c + nl + Long + under;
}
