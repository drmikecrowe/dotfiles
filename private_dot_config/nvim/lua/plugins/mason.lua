-- Configuration enabled by setup script

-- Customize Mason
-- This configuration ensures all necessary LSP servers, formatters, linters, and debuggers are installed

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
      ensure_installed = {
        -- Language Servers
        "lua-language-server", -- Lua LSP
        "bash-language-server", -- Bash LSP
        "basedpyright", -- Python LSP
        "ruff-lsp", -- Python linter/formatter LSP
        "gopls", -- Go LSP
        "vtsls", -- TypeScript/JavaScript LSP (faster than tsserver)
        "svelte-language-server", -- Svelte LSP
        "vue-language-server", -- Vue LSP
        "tailwindcss-language-server", -- Tailwind CSS LSP
        "html-lsp", -- HTML LSP
        "css-lsp", -- CSS LSP
        "json-lsp", -- JSON LSP
        "yaml-language-server", -- YAML LSP
        "dockerfile-language-server", -- Docker LSP
        -- "docker-compose-language-service", -- Docker Compose LSP
        -- "terraformls",               -- Terraform LSP
        -- "tflint",                    -- Terraform linter
        "marksman", -- Markdown LSP
        "emmet-ls", -- Emmet LSP

        -- Formatters
        "stylua", -- Lua formatter
        "prettierd", -- JavaScript/TypeScript/JSON/CSS/HTML formatter
        "shfmt", -- Shell script formatter
        "ruff", -- Python formatter
        "gofumpt", -- Go formatter (alternative to gofmt)
        -- "terraform-fmt",             -- Terraform formatter

        -- Linters
        "selene", -- Lua linter
        "shellcheck", -- Shell script linter
        "hadolint", -- Dockerfile linter
        "eslint_d", -- JavaScript/TypeScript linter (fast)
        "markdownlint", -- Markdown linter

        -- Debuggers
        "debugpy", -- Python debugger
        "delve", -- Go debugger
        "js-debug-adapter", -- JavaScript/TypeScript debugger
        "bash-debug-adapter", -- Bash debugger

        -- Additional Tools
        "tree-sitter-cli", -- Tree-sitter CLI
        "taplo", -- TOML toolkit
      },
    },
  },
}
