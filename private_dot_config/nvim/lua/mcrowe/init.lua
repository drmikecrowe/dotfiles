-- Main entry point for mcrowe custom configurations
-- This file is loaded from the main init.lua via require "mcrowe"

local M = {}

-- Initialize all custom configurations
function M.setup()
  -- Polish configurations are now called explicitly in the main init.lua
  -- after the default polish, so we don't need to set up an autocmd here
end

-- Get the plugin specs to be included in the lazy.nvim setup
function M.get_plugins()
  return { import = "mcrowe.plugins" }
end

-- Call setup immediately when this module is loaded
M.setup()

return M
