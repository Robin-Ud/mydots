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

" Espaço+w salva; Espaço+y no visual copia as linhas pro clipboard
nnoremap <Space>w :w<CR>
vnoremap <Space>y :w !wl-copy<CR><CR>
