" ~/.vimrc — o vi das coisas rápidas (o que demora vai pro VSCode).
"
" No Fedora o `vi` é o vim-minimal: sem eval, sem syntax, sem clipboard.
" Por isso aqui só tem `set` e `map`: nada de if/let/syntax on, que dão
" erro E319 nessa versão. O vim completo (vim-enhanced) lê isto também.

set nocompatible
set encoding=utf-8
set number relativenumber
set incsearch hlsearch ignorecase smartcase
set tabstop=4 shiftwidth=4 expandtab
set backspace=indent,eol,start
set noswapfile
set belloff=all
set mouse=a
set scrolloff=5
set ruler

" Movimento em jklç (igual ao VSCode)
noremap j h
noremap k j
noremap l k
noremap ç l

" h / H: linha nova embaixo / em cima sem sair do modo normal
nnoremap h m`o<Esc>``
nnoremap H m`O<Esc>``

" Espaço+w salva
nnoremap <Space>w :w<CR>

" --- Clipboard compartilhado (só no vim-enhanced) ----------------------
" Nenhum vim do Fedora tem +clipboard, então vai por wl-copy/wl-paste:
"   y      -> também vai pro clipboard (cola com Ctrl+V em qualquer app)
"   p / P  -> se você deu Ctrl+C em outro app desde o último p, cola isso;
"             senão cola o registro normal (ddp continua trocando linhas)
" O vim-minimal pula tudo entre `if 1` e `endif`; lá Espaço+y copia linhas.
vnoremap <Space>y :w !wl-copy<CR><CR>
if 1
  let g:clip_visto = ''
  function! s:Copia() abort
    if v:event.operator ==# 'y' && v:event.regname ==# ''
      let g:clip_visto = @"
      call system('wl-copy', @")
    endif
  endfunction
  function! s:PuxaClip() abort
    let l:c = system('wl-paste -n 2>/dev/null')
    if v:shell_error == 0 && l:c !=# '' && l:c !=# g:clip_visto
      let g:clip_visto = l:c
      call setreg('"', l:c, l:c =~# "\n$" ? 'l' : 'c')
    endif
    return ''
  endfunction
  augroup clip_wayland
    autocmd!
    autocmd TextYankPost * call s:Copia()
  augroup END
  nnoremap <silent> <expr> p <SID>PuxaClip() . 'p'
  nnoremap <silent> <expr> P <SID>PuxaClip() . 'P'
  xnoremap <silent> <expr> p <SID>PuxaClip() . 'p'
endif
