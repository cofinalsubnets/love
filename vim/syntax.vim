" vim syntax for l lisp (.l)
" based on lisp.vim by Charles E Campbell <http://www.drchip.org/astronaut/vim/index.html#SYNTAX_LISP>
if exists("b:current_syntax")
  finish
endif

" symbol-constituent chars (the reader ends a token only on whitespace and
" ( ) " ' ` , # ; ). operators @ # $ are excluded so they highlight standalone;
" % is a plain dyadic infix now (mod is gone).
"  33 !  37 %  38 &  42 *  43 +  45 -  46 .  47 /  48-57 digits  58 :
"  60-63 < = > ?  92 \  94 ^  95 _  124 |  126 ~   (@ = alphabetics)
syn iskeyword @,33,37,38,42-43,45-47,48-57,58,60-63,92,94-95,124,126

" The three special forms: : (letrec*/seq), ? (cond), \ (lambda/quote)
syn keyword AiForm : ? \\

" Built-in functions (C nifs) + prel functions
syn keyword AiFunc cons cap cup caap caup cuap cuup
syn keyword AiFunc caaap caaup cauap cauup cuaap cuaup cuuap cuuup
syn keyword AiFunc id co const flip
syn keyword AiFunc map foldl foldr foldl1 foldr1 filter init last each all any cat catmap
syn keyword AiFunc rev take drop part zip ldel assq memq lidx sort sortsplit merge msort jot
syn keyword AiFunc + - * / % < <= = >= > <- -> idp inc dec abs gcd modpow int
syn keyword AiFunc << >> & \| ^
syn keyword AiFunc pin pull peep tablet mint gauge
syn keyword AiFunc sin cos log pow re im conj arg wave
syn keyword AiFunc nump intp powg num-ap numfn randint net prod neg recip frac bit
syn keyword AiFunc twop strp symp mapp lamp hotp packp bigp widep arrp comp flop fixp nilp atomp
syn keyword AiFunc arr array arank alen ashape atype asum aprod amax amin aall iota
syn keyword AiFunc a-rank a-shape a-type a-dim
syn keyword AiFunc string slice intern nom mint tally slurp show sip pad page
syn keyword AiFunc tablet keys dig sat non peep pin pull buf blit missing
syn keyword AiFunc lamb peek poke seek trim mono
syn keyword AiFunc fgetc fungetc feof fputc fputs fputbn fputx fflush read
syn keyword AiFunc putc puts putn putx getc read in out dot
syn keyword AiFunc ev call-cc yield spawn wait sleep done? hush key?
syn keyword AiFunc help scare scare? more? eof?
syn keyword AiFunc rand randf rand-next randf-next rng-seed rng-get rng-set
syn keyword AiFunc open close run getenv exit
syn keyword AiFunc clock gauge book macros assert ai-version argv cmdline
syn keyword AiSigilWord non wave qq uq sat

" Macros (head-symbol rewrites installed with ::)
syn keyword AiMacro :: L list do begin progn let if cond quote qq tuple hash
syn keyword AiMacro && \|\| :- ?- >>= <=<

" Constants: booleans (1/0), the tier-spine array element-kind codes, e pi i
syn keyword AiConst true false e pi tau i ieee-inf ieee-nan
syn keyword AiConst z r c o

" Quoted atoms: 'foo   (' is one-operand \ = quote)
syn match AiAtomMark "'"
syn match AiAtom "'[^ \t\n()`',;#\"]\+" contains=AiAtomMark

" Quasiquote marks: `tmpl  ,unquote  ,@unquote-splice
syn match AiQuasi ",@\|[`,]"

" Prefix operators: @(…) array  #(…) hash  $x sat  (the tables: book['operators],
" book['monadics] -- glued runs are monadic, the valence law)
syn match AiSigil "[@#$~.!?%^*+/<>=-]"

" Numbers (integer / bignum literals, possibly negative)
syn match AiNumber "\<-\?\d\+\>"

" Floating point literals: 1.5  -1.5  .5  1.  1e10  1.5e-3  (a point and/or exponent)
" Defined after AiNumber so a float wins over the integer match at a shared start.
syn match AiFloat "\<-\?\d\+\.\d*\([eE][-+]\?\d\+\)\?\>"
syn match AiFloat "\<-\?\.\d\+\([eE][-+]\?\d\+\)\?\>"
syn match AiFloat "\<-\?\d\+[eE][-+]\?\d\+\>"

" Strings
syn region AiString start='"' skip='\\\\\|\\"' end='"'

" Comments — ; to end of line, #! shebang; with TODO/FIXME highlighting inside
syn match AiCommentTodo /\<\(TODO\|FIXME\|NOTE\|XXX\|HACK\)\>/ contained
syn match AiComment ";.*$" contains=AiCommentTodo
syn match AiComment "#!.*$" contains=AiCommentTodo

" Unmatched close paren is an error
syn match AiParenError ")"

syn sync lines=100

hi def link AiAtomMark       Delimiter
hi def link AiSigil          Operator
hi def link AiSigilWord      Operator
hi def link AiAtom           Identifier
hi def link AiComment        Comment
hi def link AiCommentTodo    Todo
hi def link AiForm           Statement
hi def link AiFunc           Function
hi def link AiMacro          Special
hi def link AiConst          Constant
hi def link AiQuasi          Special
hi def link AiNumber         Number
hi def link AiFloat          Float
hi def link AiParenError     Error
hi def link AiString         String
hi def link AiBool           Boolean

" Rainbow parentheses — each nesting level gets its own colour.
" Each region contains the cluster plus the next level; level 9 wraps to 0.
" Toggle with \r (or :AiRainbow) — controlled by g:ai_rainbow (default: 1).
syn cluster AiListCluster contains=AiAtom,AiAtomMark,AiConst,AiComment,AiCommentTodo,AiFunc,AiNumber,AiFloat,AiSymbol,AiForm,AiString,AiMacro,AiQuasi,AiSigil

if !exists("g:ai_rainbow")
  let g:ai_rainbow = 0
endif

if g:ai_rainbow
  syn region AiList0 matchgroup=AiLevel0 start="(" end=")" contains=@AiListCluster,AiList1
  syn region AiList1 matchgroup=AiLevel1 start="(" end=")" contains=@AiListCluster,AiList2
  syn region AiList2 matchgroup=AiLevel2 start="(" end=")" contains=@AiListCluster,AiList3
  syn region AiList3 matchgroup=AiLevel3 start="(" end=")" contains=@AiListCluster,AiList4
  syn region AiList4 matchgroup=AiLevel4 start="(" end=")" contains=@AiListCluster,AiList5
  syn region AiList5 matchgroup=AiLevel5 start="(" end=")" contains=@AiListCluster,AiList6
  syn region AiList6 matchgroup=AiLevel6 start="(" end=")" contains=@AiListCluster,AiList7
  syn region AiList7 matchgroup=AiLevel7 start="(" end=")" contains=@AiListCluster,AiList8
  syn region AiList8 matchgroup=AiLevel8 start="(" end=")" contains=@AiListCluster,AiList9
  syn region AiList9 matchgroup=AiLevel9 start="(" end=")" contains=@AiListCluster,AiList0

  if &background ==# "dark"
    hi def AiLevel0 ctermfg=red         guifg=red1
    hi def AiLevel1 ctermfg=yellow      guifg=orange1
    hi def AiLevel2 ctermfg=green       guifg=yellow1
    hi def AiLevel3 ctermfg=cyan        guifg=greenyellow
    hi def AiLevel4 ctermfg=magenta     guifg=green1
    hi def AiLevel5 ctermfg=red         guifg=springgreen1
    hi def AiLevel6 ctermfg=yellow      guifg=cyan1
    hi def AiLevel7 ctermfg=green       guifg=slateblue1
    hi def AiLevel8 ctermfg=cyan        guifg=magenta1
    hi def AiLevel9 ctermfg=magenta     guifg=purple1
  else
    hi def AiLevel0 ctermfg=red         guifg=red3
    hi def AiLevel1 ctermfg=darkyellow  guifg=orangered3
    hi def AiLevel2 ctermfg=darkgreen   guifg=orange2
    hi def AiLevel3 ctermfg=blue        guifg=yellow3
    hi def AiLevel4 ctermfg=darkmagenta guifg=olivedrab4
    hi def AiLevel5 ctermfg=red         guifg=green4
    hi def AiLevel6 ctermfg=darkyellow  guifg=paleturquoise3
    hi def AiLevel7 ctermfg=darkgreen   guifg=deepskyblue4
    hi def AiLevel8 ctermfg=blue        guifg=darkslateblue
    hi def AiLevel9 ctermfg=darkmagenta guifg=darkviolet
  endif
else
  syn region AiList matchgroup=AiParen start="(" end=")" contains=@AiListCluster,AiList
  hi def link AiParen Delimiter
endif

let b:current_syntax = "ai"
