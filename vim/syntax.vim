" vim syntax for l lisp (.l)
" based on lisp.vim by Charles E Campbell <http://www.drchip.org/astronaut/vim/index.html#SYNTAX_LISP>
if exists("b:current_syntax")
  finish
endif

" symbol-constituent chars (the reader ends a token only on whitespace and
" ( ) " ' ` , # ; ). operators @ # $ are excluded so they highlight standalone;
" % is a plain symbol now (the infix mod alias).
"  33 !  37 %  38 &  42 *  43 +  45 -  46 .  47 /  48-57 digits  58 :
"  60-63 < = > ?  92 \  94 ^  95 _  124 |  126 ~   (@ = alphabetics)
syn iskeyword @,33,37,38,42-43,45-47,48-57,58,60-63,92,94-95,124,126

" The three special forms: : (letrec*/seq), ? (cond), \ (lambda/quote)
syn keyword LForm : ? \\

" Built-in functions (C nifs) + prelude functions
syn keyword LFunc cons cap cbp caap cabp cbap cbbp
syn keyword LFunc caaap caabp cabap cabbp cbaap cbabp cbbap cbbbp
syn keyword LFunc id co const flip
syn keyword LFunc map foldl foldr foldl1 foldr1 filter init last each all any cat catmap
syn keyword LFunc rev take drop part zip ldel assq memq lidx sort sortsplit merge msort
syn keyword LFunc + - * / % mod < <= = >= > <- -> idp inc dec abs gcd modpow int
syn keyword LFunc ~ << >> & \| ^
syn keyword LFunc sin cos log pow plex re im conj arg clift
syn keyword LFunc nump intp powg num-ap numfn randint
syn keyword LFunc twop strp symp mapp lamp handlep tupp bigp boxp arrp comp flop fixp nilp atomp
syn keyword LFunc arr array arank alen ashape atype asum aprod amax amin aall
syn keyword LFunc a-rank a-shape a-type a-dim
syn keyword LFunc string slice scat intern nom slurp show sip pad page
syn keyword LFunc table keys dig sat peep pin pull buf blit
syn keyword LFunc lam peek poke seek trim
syn keyword LFunc fgetc fungetc feof fputc fputs fputn fputx fflush fread
syn keyword LFunc putc puts putn putx getc read in out dot
syn keyword LFunc ev call-cc yield spawn wait sleep done? kill key?
syn keyword LFunc trap sing sing? more? eof?
syn keyword LFunc rand randf rand-next randf-next rng-seed rng-get rng-set
syn keyword LFunc open close run getenv exit
syn keyword LFunc clock gauge dict macros assert version-number argv cmdline

" Macros (head-symbol rewrites installed with ::)
syn keyword LMacro :: L list do begin progn let if cond quote qq gsym tuple hash
syn keyword LMacro && \|\| :- ?- >>= <=<

" Constants: booleans (1/0), the tier-spine array element-kind codes, e pi i
syn keyword LConst true false e pi i
syn keyword LConst z r c o

" Quoted atoms: 'foo   (' is one-operand \ = quote)
syn match LAtomMark "'"
syn match LAtom "'[^ \t\n()`',;#\"]\+" contains=LAtomMark

" Quasiquote marks: `tmpl  ,unquote  ,@unquote-splice
syn match LQuasi ",@\|[`,]"

" Prefix operators: @(…) array  #(…) hash  $x sat  (table: dict['operators])
syn match LSigil "[@#$]"

" Numbers (integer / bignum literals, possibly negative)
syn match LNumber "\<-\?\d\+\>"

" Floating point literals: 1.5  -1.5  .5  1.  1e10  1.5e-3  (a point and/or exponent)
" Defined after LNumber so a float wins over the integer match at a shared start.
syn match LFloat "\<-\?\d\+\.\d*\([eE][-+]\?\d\+\)\?\>"
syn match LFloat "\<-\?\.\d\+\([eE][-+]\?\d\+\)\?\>"
syn match LFloat "\<-\?\d\+[eE][-+]\?\d\+\>"

" Strings
syn region LString start='"' skip='\\\\\|\\"' end='"'

" Comments — ; to end of line, #! shebang; with TODO/FIXME highlighting inside
syn match LCommentTodo /\<\(TODO\|FIXME\|NOTE\|XXX\|HACK\)\>/ contained
syn match LComment ";.*$" contains=LCommentTodo
syn match LComment "^#!.*$" contains=LCommentTodo

" Unmatched close paren is an error
syn match LParenError ")"

syn sync lines=100

hi def link LAtomMark       Delimiter
hi def link LSigil          Special
hi def link LAtom           Identifier
hi def link LComment        Comment
hi def link LCommentTodo    Todo
hi def link LForm           Statement
hi def link LFunc           Function
hi def link LMacro          Operator
hi def link LConst          Constant
hi def link LQuasi          Special
hi def link LNumber         Number
hi def link LFloat          Float
hi def link LParenError     Error
hi def link LString         String
hi def link LBool           Boolean

" Rainbow parentheses — each nesting level gets its own colour.
" Each region contains the cluster plus the next level; level 9 wraps to 0.
" Toggle with \r (or :LRainbow) — controlled by g:l_rainbow (default: 1).
syn cluster LListCluster contains=LAtom,LAtomMark,LConst,LComment,LCommentTodo,LFunc,LNumber,LFloat,LSymbol,LForm,LString,LMacro,LQuasi,LSigil

if !exists("g:l_rainbow")
  let g:l_rainbow = 0
endif

if g:l_rainbow
  syn region LList0 matchgroup=LLevel0 start="(" end=")" contains=@LListCluster,LList1
  syn region LList1 matchgroup=LLevel1 start="(" end=")" contains=@LListCluster,LList2
  syn region LList2 matchgroup=LLevel2 start="(" end=")" contains=@LListCluster,LList3
  syn region LList3 matchgroup=LLevel3 start="(" end=")" contains=@LListCluster,LList4
  syn region LList4 matchgroup=LLevel4 start="(" end=")" contains=@LListCluster,LList5
  syn region LList5 matchgroup=LLevel5 start="(" end=")" contains=@LListCluster,LList6
  syn region LList6 matchgroup=LLevel6 start="(" end=")" contains=@LListCluster,LList7
  syn region LList7 matchgroup=LLevel7 start="(" end=")" contains=@LListCluster,LList8
  syn region LList8 matchgroup=LLevel8 start="(" end=")" contains=@LListCluster,LList9
  syn region LList9 matchgroup=LLevel9 start="(" end=")" contains=@LListCluster,LList0

  if &background ==# "dark"
    hi def LLevel0 ctermfg=red         guifg=red1
    hi def LLevel1 ctermfg=yellow      guifg=orange1
    hi def LLevel2 ctermfg=green       guifg=yellow1
    hi def LLevel3 ctermfg=cyan        guifg=greenyellow
    hi def LLevel4 ctermfg=magenta     guifg=green1
    hi def LLevel5 ctermfg=red         guifg=springgreen1
    hi def LLevel6 ctermfg=yellow      guifg=cyan1
    hi def LLevel7 ctermfg=green       guifg=slateblue1
    hi def LLevel8 ctermfg=cyan        guifg=magenta1
    hi def LLevel9 ctermfg=magenta     guifg=purple1
  else
    hi def LLevel0 ctermfg=red         guifg=red3
    hi def LLevel1 ctermfg=darkyellow  guifg=orangered3
    hi def LLevel2 ctermfg=darkgreen   guifg=orange2
    hi def LLevel3 ctermfg=blue        guifg=yellow3
    hi def LLevel4 ctermfg=darkmagenta guifg=olivedrab4
    hi def LLevel5 ctermfg=red         guifg=green4
    hi def LLevel6 ctermfg=darkyellow  guifg=paleturquoise3
    hi def LLevel7 ctermfg=darkgreen   guifg=deepskyblue4
    hi def LLevel8 ctermfg=blue        guifg=darkslateblue
    hi def LLevel9 ctermfg=darkmagenta guifg=darkviolet
  endif
else
  syn region LList matchgroup=LParen start="(" end=")" contains=@LListCluster,LList
  hi def link LParen Delimiter
endif

let b:current_syntax = "l"
