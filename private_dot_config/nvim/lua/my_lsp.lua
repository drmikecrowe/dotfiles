local my_servers = {
  -- "bashls",
  -- "biome",
  -- "dagger",
  -- "denols",
  -- "docker_compose_language_service",
  -- "dockerls",
  -- "efm",
  -- "gopls",
  -- "lua_ls",
  -- "nil_ls",
  -- "pyright",
  -- "ruff",
  -- "ruff_lsp",
  -- "svelte",
  -- "tailwindcss",
  -- "terraformls",
  -- "tflint",
  -- "tsserver",
  -- "volar",
  -- "yamlls",
}
vim.my_ensure_installed = {}
vim.my_already_installed = {}
if vim.env.NIX_STORE then
  vim.my_already_installed = my_servers
else
  vim.my_ensure_installed = my_servers
end
