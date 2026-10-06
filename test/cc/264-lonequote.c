/* a quote that opens no literal is its own pp-token (C11 6.4p3): harmless in a skipped
 * group, where lua's ljumptab.h keeps the sed line that wrote its table */
#if 0
** you can update the following list with this command:
**
**  sed -n '/^OP_/\!d; s/OP_/\&\&L_OP_/ ; s/,.*/,/ ; s/\/.*// ; p'  lopcodes.h
**
it's an unclosed quote, and so is this one: "
#endif

int main(void)
{
	return 'a' == 97 && sizeof "it's" == 5 ? 0 : 1;
}
