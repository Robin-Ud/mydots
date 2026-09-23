-- init.lua — Configuração do Neovim
-- Carregado toda vez que o Neovim abre.

-- ========================================================================== --
-- 1. OPÇÕES BÁSICAS
-- ========================================================================== --
vim.opt.number         = true      -- Mostra o número de cada linha
vim.opt.relativenumber = true      -- Número relativo (útil para pular linhas com vim)
vim.opt.clipboard      = "unnamedplus"  -- Copia/cola integrado com o clipboard do sistema
vim.opt.tabstop        = 4         -- Tab visual = 4 espaços
vim.opt.shiftwidth     = 4         -- Indentação automática = 4 espaços
vim.opt.expandtab      = true      -- Usa espaços em vez de \t
vim.opt.swapfile       = false     -- Sem arquivo .swp poluindo a pasta
vim.opt.smartindent    = false     -- Deixa o LSP cuidar da indentação
vim.opt.cindent        = false
vim.opt.indentexpr     = ""
vim.opt.linebreak      = true      -- Quebra linha visual no espaço, nunca no meio da palavra
vim.opt.breakindent    = true      -- Mantém a indentação nas linhas quebradas

vim.g.mapleader = " "              -- Espaço como tecla líder (ex: <leader>w = espaço + w)
vim.g.maplocalleader = ","         -- Líder local: atalhos de linguagem (R.nvim usa este)

-- ========================================================================== --
-- 2. ATALHOS CUSTOMIZADOS
-- ========================================================================== --

-- h / H — insere linha vazia abaixo/acima sem sair do modo normal
vim.keymap.set('n', 'h', 'm`o<Esc>``', { noremap = true, silent = true })
vim.keymap.set('n', 'H', 'm`O<Esc>``', { noremap = true, silent = true })

-- Coluna de movimento deslocada: jklç em vez de hjkl
-- (h ficou livre acima; ç virou "direita")
vim.keymap.set({ 'n', 'v', 'o' }, 'j', 'h', { noremap = true })
vim.keymap.set({ 'n', 'v', 'o' }, 'k', 'j', { noremap = true })
vim.keymap.set({ 'n', 'v', 'o' }, 'l', 'k', { noremap = true })
vim.keymap.set({ 'n', 'v', 'o' }, 'ç', 'l', { noremap = true })

-- Alt+M — salva e roda o arquivo atual com o script tcd
vim.keymap.set('n', '<A-m>', ':w <bar> !tcd %<CR>', { noremap = true, silent = false, desc = "Rodar com tcd" })

-- <leader>w — salva o arquivo
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Salvar' })

-- Mostra diagnósticos (erros/avisos do LSP) num popup quando o cursor para
vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        vim.diagnostic.open_float(nil, { focusable = false })
    end,
})

-- ========================================================================== --
-- 3. CONFIGURAÇÃO DO RUST ANALYZER
-- Deve ser definida ANTES do lazy.nvim carregar o rustaceanvim
-- ========================================================================== --
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
                check = { command = "clippy" },  -- Usa clippy em vez de cargo check
            },
        },
    },
}

-- ========================================================================== --
-- 4. PLUGINS (Lazy.nvim)
-- lazy.nvim é o gerenciador de plugins: instala, atualiza e carrega os plugins.
-- ========================================================================== --

-- Instala o lazy.nvim automaticamente se ainda não estiver instalado
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

    -- LSP: protocolo que conecta o editor a "servidores de linguagem"
    -- (são eles que dão autocomplete, erros, ir para definição, etc.)
    "neovim/nvim-lspconfig",           -- Configurações prontas para vários LSPs
    "williamboman/mason.nvim",         -- Instala LSPs com :Mason
    "williamboman/mason-lspconfig.nvim",

    -- Rust: plugin especializado que usa o rust-analyzer com mais recursos
    {
        'mrcjkb/rustaceanvim',
        version = '^5',
        lazy = false,
    },

    -- R: abre um console do R num split e manda código do buffer para ele.
    -- Atalhos (localleader = vírgula):
    --   ,rf  abre o R      ,rq  fecha o R
    --   ,l   manda a linha do cursor    ,d  manda a linha e desce
    --   ,ss  manda a seleção (modo visual)
    --   ,aa  manda o arquivo inteiro    ,ro  abre o painel de objetos
    -- O R.nvim compila sozinho o nvimcom no primeiro start — precisa do gcc.
    {
        "R-nvim/R.nvim",
        lazy = false,
        opts = {
            R_args         = { "--quiet", "--no-save" },
            min_editor_width = 72,
            rconsole_width   = 78,
            objbr_mappings   = { c = "class", ["<localleader>gg"] = "head({object})" },
            -- Split vertical: código à esquerda, console do R à direita
            rconsole_height  = 0,
            hook = {
                on_filetype = function()
                    -- Enter no modo visual manda a seleção para o console
                    vim.keymap.set("v", "<CR>", "<Plug>RSendSelection",
                        { buffer = true, desc = "R: mandar seleção" })
                    -- Enter no modo normal manda a linha e desce
                    vim.keymap.set("n", "<CR>", "<Plug>RDSendLine",
                        { buffer = true, desc = "R: mandar linha" })
                end,
            },
        },
    },

    -- Treesitter: parsing real da linguagem para syntax highlighting mais preciso
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        -- branch fixo em "master": o branch padrão do projeto virou "main",
        -- que exige Neovim 0.12 (usa vim.list.unique). Aqui roda 0.11.6, e no
        -- "main" o config abaixo falhava calado — o highlight vinha do syntax
        -- antigo, não do treesitter. Só reavaliar ao subir para o 0.12.
        branch = "master",
        config = function()
            local status_ok, configs = pcall(require, "nvim-treesitter.configs")
            if not status_ok then return end
            configs.setup({
                ensure_installed = { "c", "lua", "vim", "vimdoc", "rust", "python",
                                     "r", "markdown", "markdown_inline" },
                highlight = { enable = true },
            })
        end
    },

    -- nvim-cmp: autocomplete (a janelinha que aparece enquanto você digita)
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",     -- Sugestões vindas do LSP
            "hrsh7th/cmp-buffer",       -- Sugestões de palavras do arquivo atual
            "hrsh7th/cmp-path",         -- Sugestões de caminhos de arquivo
            "L3MON4D3/LuaSnip",         -- Motor de snippets
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
                    ['<C-b>']     = cmp.mapping.scroll_docs(-4),
                    ['<C-f>']     = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>']     = cmp.mapping.abort(),
                    ['<CR>']      = cmp.mapping.confirm({ select = true }),
                    ['<Tab>']     = cmp.mapping.select_next_item(),
                    ['<S-Tab>']   = cmp.mapping.select_prev_item(),
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp', max_item_count = 15 },  -- Prioridade 1: sugestões do LSP
                    { name = 'luasnip', max_item_count = 5 },    -- Prioridade 2: snippets
                }, {
                    -- Fallback: palavras do buffer atual. keyword_length controla a partir
                    -- de quantas letras a sugestão aparece (3, não só com 4+), e max_item_count
                    -- baixo evita que a lista fique cavalar em arquivos de prosa (.md, etc.)
                    { name = 'buffer', keyword_length = 3, max_item_count = 5 },
                })
            })
        end
    },

    -- Tokyo Night: tema escuro com cores inspiradas em Tokyo à noite
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,     -- Carrega antes de outros plugins para evitar flash
        opts = {
            style       = "night",
            transparent = false,
            styles      = { sidebars = "dark", floats = "dark" },
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd([[colorscheme tokyonight]])
        end
    },
})

-- ========================================================================== --
-- 5. CONFIGURAÇÃO DOS LSPs
-- Mason instala os servidores; mason-lspconfig os conecta ao nvim-cmp.
-- ========================================================================== --
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "pyright" },  -- C e Python instalados automaticamente
    handlers = {
        function(server_name)
            -- O rustaceanvim gerencia o rust_analyzer por conta própria
            if server_name == "rust_analyzer" then return end

            local capabilities = require('cmp_nvim_lsp').default_capabilities()
            local config = { capabilities = capabilities }

            -- Pyright: não inicia automaticamente em projetos do tipo "farmer"
            if server_name == "pyright" then
                config.on_new_config = function(new_config, new_root_dir)
                    if new_root_dir and new_root_dir:lower():match("farmer") then
                        new_config.autostart = false
                    end
                end
            end

            require('lspconfig')[server_name].setup(config)
        end,
    },
})

-- R: o languageserver não vem pelo Mason, é um pacote do CRAN
-- (Rscript ~/etc/r-setup/pacotes.R instala).
-- Por isso é configurado à mão, fora dos handlers do mason-lspconfig.
-- Usa a API nova do nvim 0.11 (vim.lsp.config/enable); o require('lspconfig')
-- direto está deprecado e imprime aviso na inicialização.
if vim.fn.executable("R") == 1 then
    vim.lsp.config('r_language_server', {
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
    })
    vim.lsp.enable('r_language_server')
end

-- ========================================================================== --
-- 6. ATALHOS DO LSP
-- Ativados apenas quando um LSP está conectado ao arquivo atual (LspAttach).
-- ========================================================================== --
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local opts = { buffer = ev.buf }

        vim.keymap.set('n', 'gd',         vim.lsp.buf.definition,   opts)  -- Ir para definição
        vim.keymap.set('n', 'K',          vim.lsp.buf.hover,         opts)  -- Documentação
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action,   opts)  -- Ações (fix, refactor)
        vim.keymap.set('n', '<leader>f',  function()
            vim.lsp.buf.format { async = true }
        end, opts)                                                           -- Formatar arquivo
        vim.keymap.set('n', '<leader>h',  function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end, { desc = "Toggle Inlay Hints" })                                -- Liga/desliga dicas de tipo
    end,
})

-- ========================================================================== --
-- 7. FORMATAÇÃO AUTOMÁTICA AO SALVAR
-- ========================================================================== --
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})
