-- Configuration enabled by setup script

-- Customize Treesitter with comprehensive language support

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      -- Core languages
      "lua",
      "vim",
      "vimdoc",
      "query",

      -- Web development
      "javascript",
      "typescript",
      "html",
      "css",
      "json",
      "jsonc",
      "yaml",
      "toml",
      "xml",
      "svelte",
      "vue",

      -- Programming languages
      "python",
      "go",
      "gomod",
      "gowork",
      "bash",
      "fish",
      "powershell",

      -- Documentation and markup
      "markdown",
      "markdown_inline",
      "rst",

      -- Configuration files
      "dockerfile",
      -- "docker-compose",
      -- "terraform",
      "hcl",
      "nginx",

      -- Git
      "git_config",
      "git_rebase",
      "gitcommit",
      "gitignore",
      "gitattributes",

      -- Data formats
      "sql",
      "graphql",
      "proto",

      -- Other useful parsers
      "regex",
      "http",
      "ssh_config",
    },
    -- Enable additional features
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true,
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
  },
}
