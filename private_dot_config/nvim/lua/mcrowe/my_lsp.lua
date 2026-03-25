-- Enabled LSP servers for mcrowe's configuration
local my_servers = {
  "bashls",
  "lua_ls", 
  "basedpyright",
  "ruff_lsp",
  "gopls",
  "vtsls",
  "denols",
  "svelte",
  "tailwindcss",
  "html",
  "cssls",
  "jsonls",
  "yamlls",
  "dockerls",
  "docker_compose_language_service",
  "terraformls",
  "marksman",
  "emmet_ls",
}

vim.my_ensure_installed = {}
vim.my_already_installed = {}

if vim.env.NIX_STORE then
  vim.my_already_installed = my_servers
else
  vim.my_ensure_installed = my_servers
end
