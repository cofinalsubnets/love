; src/apps/moon/c.lex -- the token shapes mooncc's lexer lays off tables: `love lex` makes
; ctab.l of it. lex.l dispatches on the rule's number, so a new rule goes last; a byte no rule
; takes, and every shape not here (numbers, literals, block comments, asm), is the hand lexer's
ID   [A-Za-z_\x80-\xff][A-Za-z_0-9\x80-\xff]*
%%
\n                  nl
[ \t\r\f\v]+        ws
\\\r?\n             splice
{ID}                id
"//"[^\n]*          lcom
"<<="|">>="|"..."|"=="|"!="|"<="|">="|"&&"|"||"|"<<"|">>"|"+="|"-="|"*="|"/="|"%="|"&="|"|="|"^="|"->"|"++"|"--"|"##"   p
[]()[{};,.:?~!+*/%<>=&|^#-]   p1
