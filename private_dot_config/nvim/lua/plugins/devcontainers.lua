return {
  {
    "https://codeberg.org/esensar/nvim-dev-container",
    dependencies = "nvim-treesitter/nvim-treesitter",
    opts = {
      config = function()
        require("nix-reaver.nvim").setup {
          attach_mounts = {
            neovim_config = {
              enabled = true,
              options = { "readonly" },
            },
            neovim_data = {
              enabled = false,
              options = {},
            },
            -- Only useful if using neovim 0.8.0+
            neovim_state = {
              enabled = false,
              options = {},
            },
          },
        }
      end,
    },
  },
}
