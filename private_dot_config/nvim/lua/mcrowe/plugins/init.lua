-- Main entry point for custom plugins
-- This file loads all custom plugins and configurations

---@type LazySpec
return {
  -- Load community plugins
  require "mcrowe.plugins.community",
  -- Load user plugins
  require "mcrowe.plugins.user",
  -- Load LSP configuration
  require "mcrowe.plugins.lsp",

  require "mcrowe.plugins.obsidian",
  require "mcrowe.plugins.tmux",
}
