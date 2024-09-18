return {
  {
    "redxtech/nix-reaver.nvim",
    opts = {
      keys = {
        { "n", "<leader>ue", ":NixReaver<cr>" },
      },
      config = function() require("nix-reaver.nvim").setup() end,
    },
  },
}
