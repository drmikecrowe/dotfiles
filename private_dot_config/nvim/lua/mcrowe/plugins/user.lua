-- Custom user plugins configuration
-- This file contains all your custom plugins and overrides

---@type LazySpec
return {
  -- Custom plugins
  "augmentcode/augment.vim",
  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- Plugin overrides
  { "folke/snacks.nvim", enabled = false },
  { "max397574/better-escape.nvim", enabled = false },

  -- Custom configurations for default plugins
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "AstroNvim/astrocore" },
    init = function()
      -- Ensure window commands are properly sequenced
      vim.g.neo_tree_remove_legacy_commands = true
    end,
    opts = {
      window = {
        position = "left",
        width = 30,
        mapping_options = {
          noremap = true,
          nowait = true,
        },
      },
      filesystem = {
        -- follow_current_file = true,
        -- TODO
        hijack_netrw_behavior = "open_current",
        use_libuv_file_watcher = true,
      },
      event_handlers = {
        {
          event = "neo_tree_window_after_open",
          handler = function(args)
            if args.position == "left" or args.position == "right" then
              vim.schedule(function() vim.cmd "wincmd =" end)
            end
          end,
        },
      },
      open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline" },
      close_if_last_window = true,
      enable_refresh_on_write = true,
      source_selector = {
        winbar = false,
        statusline = false,
      },
    },
  },
}
