-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

vim.g.sessionoptions = "blank,buffers,curdir,folds,help,tabpages"

if not vim.env.NVIM_MAN then
  vim.api.nvim_create_augroup("neotree_autoopen", { clear = true })
  vim.api.nvim_create_autocmd("BufRead", { -- Changed from BufReadPre
    desc = "Open neo-tree on enter",
    group = "neotree_autoopen",
    once = true,
    callback = function()
      if not vim.g.neotree_opened then
        vim.cmd "Neotree show"
        vim.g.neotree_opened = true
      end
    end,
  })
end
