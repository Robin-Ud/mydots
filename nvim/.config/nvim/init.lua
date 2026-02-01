-- ========================================================================== --
-- 1. CONFIGURAÇÕES BÁSICAS (Vim Options)
-- ========================================================================== --
vim.opt.number = true             -- Números das linhas
vim.opt.relativenumber = true     -- Números relativos
vim.opt.clipboard = "unnamedplus" -- Copiar/Colar do sistema
vim.opt.tabstop = 4               -- Tab com 4 espaços
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.g.mapleader = " "             -- Define o Espaço como tecla Líder
vim.opt.swapfile = false          -- Sem arquivos de swap sujando pastas

-- ========================================================================== --
-- 2. SEUS ATALHOS CUSTOMIZADOS (Keymaps)
-- ========================================================================== --
-- O famoso atalho do ç
vim.keymap.set('n', 'ç', 'm`o<Esc>``', { noremap = true, silent = true })
vim.keymap.set('n', 'Ç', 'm`O<Esc>``', { noremap = true, silent = true })

-- [MUDANÇA AQUI] Leader + t (Espaço depois t) para salvar e rodar o tcd
vim.keymap.set('n', '<leader>t', ':w <bar> !tcd %<CR>', { noremap = true, silent = false, desc = "Rodar TCD" })

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
    -- >> Ferramentas de Código (LSP)
    "neovim/nvim-lspconfig",             -- Essencial para o LSP
    "williamboman/mason.nvim",           -- Instalador de LSPs
    "williamboman/mason-lspconfig.nvim", -- Ponte entre Mason e lspconfig

    -- >> Visual (Tema e Barra)
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            style = "night",
            light_style = "day",
            transparent = false,
            styles = {
                sidebars = "dark",
                floats = "dark",
            },
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd([[colorscheme tokyonight]])
        end
    },
})

-- ========================================================================== --
-- 4. CONFIGURAÇÃO DOS LSPS (C e Python)
-- ========================================================================== --
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "pyright" },
    handlers = {
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end,
    },
})

-- ========================================================================== --
-- 5. AJUSTES FINAIS E ATALHOS DO LSP
-- ========================================================================== --
-- TRAVA DE SEGURANÇA DA INDENTAÇÃO
vim.opt.smartindent = false
vim.opt.cindent = false
vim.opt.indentexpr = "" 

-- Configuração quando o LSP (Intelisense) conecta no arquivo
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local opts = { buffer = ev.buf }
        
        -- Ir para definição (gd) e ver documentação (K)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)

        -- [MUDANÇA AQUI] Leader + f (Espaço depois f) para Formatar
        vim.keymap.set('n', '<leader>f', function() 
            vim.lsp.buf.format { async = true } 
        end, opts)
    end,
})

-- ========================================================================== --
-- 6. FORMATAÇÃO AUTOMÁTICA AO SALVAR
-- ========================================================================== --
-- Mantive ativo: sempre que salvar, ele formata sozinho.
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})
