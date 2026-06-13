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
syn keyword LoveForm : ? \\

" Built-in functions (C nifs) + prelude functions
syn keyword LoveFunc cons cap cup caap caup cuap cuup
syn keyword LoveFunc caaap caaup cauap cauup cuaap cuaup cuuap cuuup
syn keyword LoveFunc id co const flip
syn keyword LoveFunc map foldl foldr foldl1 foldr1 filter init last each all any cat catmap
syn keyword LoveFunc rev take drop part zip ldel assq memq lidx sort sortsplit merge msort jot
syn keyword LoveFunc + - * / % < <= = >= > <- -> idp inc dec abs gcd modpow int
syn keyword LoveFunc ~ << >> & \| ^
syn keyword LoveFunc sin cos log pow plex re im conj arg wave
syn keyword LoveFunc nump intp powg num-ap numfn randint net prod neg recip frac bit
syn keyword LoveFunc twop strp symp mapp lamp hotp packp bigp widep arrp comp flop fixp nilp atomp
syn keyword LoveFunc arr array arank alen ashape atype asum aprod amax amin aall
syn keyword LoveFunc a-rank a-shape a-type a-dim
syn keyword LoveFunc string slice intern nom mint tally slurp show sip pad page
syn keyword LoveFunc tablet keys dig sat non peep pin pull buf blit missing
syn keyword LoveFunc lamb peek poke seek trim mono
syn keyword LoveFunc fgetc fungetc feof fputc fputs fputbn fputx fflush read
syn keyword LoveFunc putc puts putn putx getc read in out dot
syn keyword LoveFunc ev call-cc yield spawn wait sleep done? hush key?
syn keyword LoveFunc help scare scare? more? eof?
syn keyword LoveFunc rand randf rand-next randf-next rng-seed rng-get rng-set
syn keyword LoveFunc open close run getenv exit
syn keyword LoveFunc clock gauge book macros assert love-version argv cmdline

" Macros (head-symbol rewrites installed with ::)
syn keyword LoveMacro :: L list do begin progn let if cond quote qq tuple hash
syn keyword LoveMacro && \|\| :- ?- >>= <=<

" Constants: booleans (1/0), the tier-spine array element-kind codes, e pi i
syn keyword LoveConst true false e pi i ieee-inf ieee-nan
syn keyword LoveConst z r c o

" Quoted atoms: 'foo   (' is one-operand \ = quote)
syn match LoveAtomMark "'"
syn match LoveAtom "'[^ \t\n()`',;#\"]\+" contains=LoveAtomMark

" Quasiquote marks: `tmpl  ,unquote  ,@unquote-splice
syn match LoveQuasi ",@\|[`,]"

" Prefix operators: @(…) array  #(…) hash  $x sat  (the tables: book['operators],
" book['monadics] -- glued runs are monadic, the valence law)
syn match LoveSigil "[@#$]"

" Numbers (integer / bignum literals, possibly negative)
syn match LoveNumber "\<-\?\d\+\>"

" Floating point literals: 1.5  -1.5  .5  1.  1e10  1.5e-3  (a point and/or exponent)
" Defined after LoveNumber so a float wins over the integer match at a shared start.
syn match LoveFloat "\<-\?\d\+\.\d*\([eE][-+]\?\d\+\)\?\>"
syn match LoveFloat "\<-\?\.\d\+\([eE][-+]\?\d\+\)\?\>"
syn match LoveFloat "\<-\?\d\+[eE][-+]\?\d\+\>"

" Strings
syn region LoveString start='"' skip='\\\\\|\\"' end='"'

" Comments — ; to end of line, #! shebang; with TODO/FIXME highlighting inside
syn match LoveCommentTodo /\<\(TODO\|FIXME\|NOTE\|XXX\|HACK\)\>/ contained
syn match LoveComment ";.*$" contains=LoveCommentTodo
syn match LoveComment "^#!.*$" contains=LoveCommentTodo

" Unmatched close paren is an error
syn match LoveParenError ")"

syn sync lines=100

hi def link LoveAtomMark       Delimiter
hi def link LoveSigil          Special
hi def link LoveAtom           Identifier
hi def link LoveComment        Comment
hi def link LoveCommentTodo    Todo
hi def link LoveForm           Statement
hi def link LoveFunc           Function
hi def link LoveMacro          Operator
hi def link LoveConst          Constant
hi def link LoveQuasi          Special
hi def link LoveNumber         Number
hi def link LoveFloat          Float
hi def link LoveParenError     Error
hi def link LoveString         String
hi def link LoveBool           Boolean

" Rainbow parentheses — each nesting level gets its own colour.
" Each region contains the cluster plus the next level; level 9 wraps to 0.
" Toggle with \r (or :LoveRainbow) — controlled by g:love_rainbow (default: 1).
syn cluster LoveListCluster contains=LoveAtom,LoveAtomMark,LoveConst,LoveComment,LoveCommentTodo,LoveFunc,LoveNumber,LoveFloat,LoveSymbol,LoveForm,LoveString,LoveMacro,LoveQuasi,LoveSigil

if !exists("g:love_rainbow")
  let g:love_rainbow = 0
endif

if g:love_rainbow
  syn region LoveList0 matchgroup=LoveLevel0 start="(" end=")" contains=@LoveListCluster,LoveList1
  syn region LoveList1 matchgroup=LoveLevel1 start="(" end=")" contains=@LoveListCluster,LoveList2
  syn region LoveList2 matchgroup=LoveLevel2 start="(" end=")" contains=@LoveListCluster,LoveList3
  syn region LoveList3 matchgroup=LoveLevel3 start="(" end=")" contains=@LoveListCluster,LoveList4
  syn region LoveList4 matchgroup=LoveLevel4 start="(" end=")" contains=@LoveListCluster,LoveList5
  syn region LoveList5 matchgroup=LoveLevel5 start="(" end=")" contains=@LoveListCluster,LoveList6
  syn region LoveList6 matchgroup=LoveLevel6 start="(" end=")" contains=@LoveListCluster,LoveList7
  syn region LoveList7 matchgroup=LoveLevel7 start="(" end=")" contains=@LoveListCluster,LoveList8
  syn region LoveList8 matchgroup=LoveLevel8 start="(" end=")" contains=@LoveListCluster,LoveList9
  syn region LoveList9 matchgroup=LoveLevel9 start="(" end=")" contains=@LoveListCluster,LoveList0

  if &background ==# "dark"
    hi def LoveLevel0 ctermfg=red         guifg=red1
    hi def LoveLevel1 ctermfg=yellow      guifg=orange1
    hi def LoveLevel2 ctermfg=green       guifg=yellow1
    hi def LoveLevel3 ctermfg=cyan        guifg=greenyellow
    hi def LoveLevel4 ctermfg=magenta     guifg=green1
    hi def LoveLevel5 ctermfg=red         guifg=springgreen1
    hi def LoveLevel6 ctermfg=yellow      guifg=cyan1
    hi def LoveLevel7 ctermfg=green       guifg=slateblue1
    hi def LoveLevel8 ctermfg=cyan        guifg=magenta1
    hi def LoveLevel9 ctermfg=magenta     guifg=purple1
  else
    hi def LoveLevel0 ctermfg=red         guifg=red3
    hi def LoveLevel1 ctermfg=darkyellow  guifg=orangered3
    hi def LoveLevel2 ctermfg=darkgreen   guifg=orange2
    hi def LoveLevel3 ctermfg=blue        guifg=yellow3
    hi def LoveLevel4 ctermfg=darkmagenta guifg=olivedrab4
    hi def LoveLevel5 ctermfg=red         guifg=green4
    hi def LoveLevel6 ctermfg=darkyellow  guifg=paleturquoise3
    hi def LoveLevel7 ctermfg=darkgreen   guifg=deepskyblue4
    hi def LoveLevel8 ctermfg=blue        guifg=darkslateblue
    hi def LoveLevel9 ctermfg=darkmagenta guifg=darkviolet
  endif
else
  syn region LoveList matchgroup=LoveParen start="(" end=")" contains=@LoveListCluster,LoveList
  hi def link LoveParen Delimiter
endif

let b:current_syntax = "love"
