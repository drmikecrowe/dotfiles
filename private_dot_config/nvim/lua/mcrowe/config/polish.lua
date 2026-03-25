-- Custom polish configurations
-- This contains customizations that run last in the setup process

local M = {}

-- Function to setup all polish customizations
function M.setup()
  -- Set session options
  vim.g.sessionoptions = "blank,buffers,curdir,folds,help,tabpages"

  -- Setup Neo-tree auto-open
  if not vim.env.NVIM_MAN then
    vim.api.nvim_create_augroup("neotree_autoopen", { clear = true })
    vim.api.nvim_create_autocmd("VimEnter", { 
      desc = "Open neo-tree and activate first available buffer if any",
      group = "neotree_autoopen",
      once = true,
      callback = function()
        -- Only run once
        if vim.g.neotree_opened then return end
        
        -- Open Neo-tree first
        vim.cmd("Neotree show")
        vim.g.neotree_opened = true
        
        -- Schedule to find and activate a non-empty buffer if available
        vim.schedule(function()
          -- Get all listed buffers that aren't the initial empty one
          local buffers = {}
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            -- Check if buffer is listed, has a name, and isn't a neo-tree buffer
            if vim.api.nvim_buf_is_valid(bufnr) and 
               vim.fn.buflisted(bufnr) == 1 and
               vim.api.nvim_buf_get_name(bufnr) ~= "" and
               vim.bo[bufnr].filetype ~= "neo-tree" then
              table.insert(buffers, bufnr)
            end
          end
          
          if #buffers == 0 then
            vim.cmd("Neotree focus")
            
            -- Hide the initial empty buffer
            local initial_bufnr = vim.fn.bufnr('#')  -- Get the alternate buffer (likely the initial one)
            if initial_bufnr ~= -1 and vim.api.nvim_buf_get_name(initial_bufnr) == "" then
              vim.api.nvim_set_option_value("buflisted", false, { buf = initial_bufnr })
            end
          end
        end)
      end,
    })
  end
end

return M
