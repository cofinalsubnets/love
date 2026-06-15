if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

command! -buffer AiRainbow call s:ToggleRainbow()

function! s:ToggleRainbow()
  let g:ai_rainbow = !get(g:, 'ai_rainbow', 1)
  set syntax=ai
endfunction

nnoremap <buffer> <LocalLeader>r :AiRainbow<CR>
