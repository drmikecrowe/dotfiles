-- LSP configuration for mcrowe's custom setup

---@type LazySpec
return {
  -- Configure AstroLSP
  {
    "AstroNvim/astrolsp",
    opts = function(_, opts)
      -- Ensure specific language servers are installed
      opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
        -- List of servers to install
        bashls = {},
        dagger = {},
        denols = {
          -- Don't auto-start denols
          autostart = false,
        },
        docker_compose_language_service = {},
        dockerls = {},
        lua_ls = {},
        basedpyright = {},
        ruff = {},
        ruff_lsp = {},
        svelte = {},
        tailwindcss = {},
        tflint = {},
        tsserver = {},
        volar = {}, -- Vue language server
        yamlls = {},
      })

      -- Configure automatic installation
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "bashls",
        "dagger",
        "docker_compose_language_service",
        "dockerls",
        "lua_ls",
        "basedpyright",
        "ruff",
        "ruff_lsp",
        "svelte",
        "tailwindcss",
        "tflint",
        "tsserver",
        "volar",
        "yamlls",
      })

      return opts
    end,
  },
}
