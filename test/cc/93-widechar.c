/* wide / prefixed character constants -- L'a' (wchar_t), u'x' / U'x'
   (char16_t / char32_t). mooncc carries no distinct wide type, so the prefix
   drops and the value is the ordinary character code; the escape forms ride
   through too. identifiers that merely START with L/u/U (no quote follows) are
   untouched. exit agrees with gcc because a wchar_t constant of an ASCII char
   is just its code. */
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
