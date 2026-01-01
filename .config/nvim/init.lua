-- ========================================================================== --
-- 1. CONFIGURAÇÕES BÁSICAS (Vim Options)
-- ========================================================================== --
vim.opt.number = true           -- Números das linhas
vim.opt.relativenumber = true  -- Números relativos
vim.opt.clipboard = "unnamedplus" -- Copiar/Colar do sistema
vim.opt.tabstop = 4             -- Tab com 4 espaços
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.g.mapleader = " "           -- Define o Espaço como tecla Líder
vim.opt.swapfile = false
--
-- ========================================================================== --
-- 2. SEUS ATALHOS CUSTOMIZADOS (Keymaps)
-- ========================================================================== --
-- O famoso atalho do ç que a gente criou
vim.keymap.set('n', 'ç', 'm`o<Esc>``', { noremap = true, silent = true })
vim.keymap.set('n', 'Ç', 'm`O<Esc>``', { noremap = true, silent = true })
-- Mapeia F5 para salvar (:w) e rodar o tcd no arquivo atual
vim.keymap.set('n', '<F5>', ':w <bar> !tcd %<CR>', { noremap = true, silent = false })

-- Atalho para salvar com Espaço + w
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Salvar' })

-- ========================================================================== --
-- 3. GERENCIADOR DE PLUGINS (Lazy.nvim)
-- ========================================================================== --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  "neovim/nvim-lspconfig", -- Plugin essencial para o LSP funcionar
  "williamboman/mason.nvim", -- Interface para instalar os LSPs
  "williamboman/mason-lspconfig.nvim", -- Ponte entre Mason e lspconfig
})

-- ========================================================================== --
-- 4. CONFIGURAÇÃO DOS LSPS (C e Python)
-- ========================================================================== --
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "pyright" },
    
    -- A MÁGICA: Isso aqui configura os servidores automaticamente e 
    -- evita aquele erro de "deprecated" do require manual.
    handlers = {
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end,
    },
})

-- ========================================================================== --
-- 5. AJUSTES FINAIS (Indentação e Atalhos)
-- ========================================================================== --

-- TRAVA DE SEGURANÇA DA INDENTAÇÃO
-- Isso impede o Neovim de tentar adivinhar onde colocar o cursor.
vim.opt.smartindent = false
vim.opt.cindent = false
vim.opt.indentexpr = "" 

-- Atalhos do LSP (Só funcionam quando o servidor conectar)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
  end,
})
