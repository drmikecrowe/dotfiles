-- Configuration enabled by setup script

-- Customize None-ls sources for enhanced formatting and diagnostics

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    local null_ls = require "null-ls"

    -- Check supported formatters and linters
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/formatting
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics

    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      -- Lua
      null_ls.builtins.formatting.stylua,
      null_ls.builtins.diagnostics.selene,

      -- Python
      null_ls.builtins.formatting.ruff_format,
      null_ls.builtins.diagnostics.ruff,

      -- JavaScript/TypeScript/JSON/CSS/HTML/Markdown
      null_ls.builtins.formatting.prettierd.with {
        filetypes = {
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
          "vue",
          "css",
          "scss",
          "less",
          "html",
          "json",
          "jsonc",
          "yaml",
          "markdown",
          "graphql",
          "handlebars",
          "svelte",
        },
      },

      -- Shell scripts
      null_ls.builtins.formatting.shfmt,
      null_ls.builtins.diagnostics.shellcheck,

      -- Go
      null_ls.builtins.formatting.gofumpt,
      null_ls.builtins.formatting.goimports,

      -- Docker
      null_ls.builtins.diagnostics.hadolint,

      -- Terraform
      -- null_ls.builtins.formatting.terraform_fmt,
      -- null_ls.builtins.diagnostics.tflint,

      -- Markdown
      null_ls.builtins.diagnostics.markdownlint,

      -- TOML
      null_ls.builtins.formatting.taplo,

      -- Code actions
      null_ls.builtins.code_actions.gitsigns,
    })

    -- Configure root directory detection
    opts.root_dir = require("null-ls.utils").root_pattern(
      ".null-ls-root",
      ".neoconf.json",
      "Makefile",
      ".git",
      "package.json",
      "go.mod",
      "pyproject.toml",
      "setup.py",
      "requirements.txt"
    )
  end,
}
