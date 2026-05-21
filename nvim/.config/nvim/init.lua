-- ========================================================================== --
-- 1. CONFIGURAÇÕES BÁSICAS (Vim Options)
-- ========================================================================== --
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.g.mapleader = " "
vim.opt.swapfile = false

-- ========================================================================== --
-- 2. SEUS ATALHOS CUSTOMIZADOS (Keymaps)
-- ========================================================================== --
vim.keymap.set('n', 'ç', 'm`o<Esc>``', { noremap = true, silent = true })
vim.keymap.set('n', 'Ç', 'm`O<Esc>``', { noremap = true, silent = true })
vim.keymap.set('n', '<A-m>', ':w <bar> !tcd %<CR>', { noremap = true, silent = false, desc = "Rodar TCD" })
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Salvar' })

-- Mostra o erro em um popup quando o cursor para (CursorHold)
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})

-- ========================================================================== --
-- 3. GERENCIADOR DE PLUGINS (Lazy.nvim)
-- ========================================================================== --

-- Deve ser definido ANTES do lazy carregar o rustaceanvim
vim.g.rustaceanvim = {
    server = {
        cmd = function()
            local ra = vim.fn.exepath("rust-analyzer")
            if ra == "" then ra = vim.fn.expand("~/.cargo/bin/rust-analyzer") end
            return { ra }
        end,
        capabilities = function()
            return require("cmp_nvim_lsp").default_capabilities()
        end,
        settings = {
            ["rust-analyzer"] = {
                check = { command = "clippy" },
            },
        },
    },
}

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- >> Ferramentas de Código (LSP)
    "neovim/nvim-lspconfig",
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",

    -- --> NOVO: O "Cérebro" do Rust (Rustaceanvim)
    {
        'mrcjkb/rustaceanvim',
        version = '^5', -- Recomendado fixar na versão 5
        lazy = false,   -- Carrega assim que inicia (importante para detecção de arquivo)
    },

-- --> NOVO: Syntax Highlighting Melhorado (Treesitter)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            -- Tenta carregar o plugin com segurança
            local status_ok, configs = pcall(require, "nvim-treesitter.configs")
            if not status_ok then
                return -- Se der erro, para por aqui e não quebra o Neovim
            end

            configs.setup({
                -- Garante que instale highlight para essas linguagens
                ensure_installed = { "c", "lua", "vim", "vimdoc", "rust", "python" },
                highlight = { enable = true },
            })
        end
    },    -- --> NOVO: Autocomplete (O motor que faz a janelinha aparecer)
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp", -- Sugestões do LSP
            "hrsh7th/cmp-buffer",   -- Sugestões de palavras no arquivo
            "hrsh7th/cmp-path",     -- Sugestões de caminhos de arquivo
            "L3MON4D3/LuaSnip",     -- Motor de Snippets (Obrigatório pro CMP)
            "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            local cmp = require("cmp")
            cmp.setup({
                snippet = {
                    expand = function(args)
                        require('luasnip').lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Enter confirma
                    ['<Tab>'] = cmp.mapping.select_next_item(),        -- Tab navega pra baixo
                    ['<S-Tab>'] = cmp.mapping.select_prev_item(),      -- Shift+Tab navega pra cima
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' }, -- Prioridade: LSP
                    { name = 'luasnip' },  -- Prioridade: Snippets
                }, {
                    { name = 'buffer' },   -- Prioridade: Texto do buffer
                })
            })
        end
    },

    -- >> Visual (Tema)
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            style = "night",
            transparent = false,
            styles = { sidebars = "dark", floats = "dark" },
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd([[colorscheme tokyonight]])
        end
    },
})


-- ========================================================================== --
-- 4. CONFIGURAÇÃO DOS LSPS
-- ========================================================================== --
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "pyright" }, -- Garanta que tem vírgula aqui
    handlers = {
        function(server_name)
            -- rustaceanvim gerencia o rust_analyzer diretamente
            if server_name == "rust_analyzer" then return end

            local capabilities = require('cmp_nvim_lsp').default_capabilities()
            local config = { capabilities = capabilities }

            -- Trava para não iniciar o Pyright nos scripts do jogo
            if server_name == "pyright" then
                config.on_new_config = function(new_config, new_root_dir)
                    if new_root_dir and new_root_dir:lower():match("farmer") then
                        new_config.autostart = false
                    end
                end
            end

            require('lspconfig')[server_name].setup(config)
        end, -- Fecha a function
    }, -- Fecha o handlers
}) 
-- Fecha o setup-- ========================================================================== --
-- 5. AJUSTES FINAIS E ATALHOS DO LSP
-- ========================================================================== --
vim.opt.smartindent = false
vim.opt.cindent = false
vim.opt.indentexpr = "" 

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local opts = { buffer = ev.buf }
        
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', '<leader>f', function() 
            vim.lsp.buf.format { async = true } 
        end, opts)

        -- --> NOVO: Atalho para ligar/desligar as dicas de tipo (Inlay Hints)
        vim.keymap.set('n', '<leader>h', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end, { desc = "Toggle Inlay Hints" })
    end,
})

-- ========================================================================== --
-- 6. FORMATAÇÃO AUTOMÁTICA
-- ========================================================================== --
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})
