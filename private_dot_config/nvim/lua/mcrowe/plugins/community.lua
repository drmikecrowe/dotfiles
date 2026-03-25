-- AstroCommunity plugins configuration
-- This file contains all community plugins you want to use

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- import/override with your plugins folder
  { import = "astrocommunity.fuzzy-finder.fzf-lua" },
  { import = "astrocommunity.fuzzy-finder.telescope-zoxide" },
  -- {
  --   import = "astrocommunity.editing-support.auto-save-nvim",
  --   opts = {
  --     trigger_events = { -- See :h events
  --       immediate_save = { "BufLeave", "FocusLost" }, -- vim events that trigger an immediate save
  --       defer_save = false, -- { "InsertLeave", "TextChanged" }, -- vim events that trigger a deferred save (saves after `debounce_delay`)
  --       cancel_deferred_save = { "InsertEnter" }, -- vim events that cancel a pending deferred save
  --     },
  --   },
  -- },
  -- { import = "astrocommunity.completion.codeium-nvim" },
  { import = "astrocommunity.recipes.auto-session-restore" },
  { import = "astrocommunity.editing-support.rainbow-delimiters-nvim" },
  { import = "astrocommunity.editing-support.text-case-nvim" },
  { import = "astrocommunity.editing-support.nvim-devdocs" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.chezmoi" },
  -- { import = "astrocommunity.pack.cs" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.python-ruff" },
  -- { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.typescript" },
  { import = "astrocommunity.pack.svelte" },
  { import = "astrocommunity.pack.vue" },
  { import = "astrocommunity.pack.xml" },
  { import = "astrocommunity.pack.yaml" },
}
