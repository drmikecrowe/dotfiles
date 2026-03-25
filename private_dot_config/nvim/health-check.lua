-- Neovim Configuration Health Check
-- Run with: nvim -l health-check.lua

print("=== Neovim Configuration Health Check ===\n")

-- Check Neovim version
local version = vim.version()
if version then
    print("✅ Neovim version: " .. version.major .. "." .. version.minor .. "." .. version.patch)
else
    print("❌ Could not determine Neovim version")
end

-- Check if lazy.nvim is available
local lazy_ok, lazy = pcall(require, "lazy")
if lazy_ok then
    print("✅ Lazy.nvim is available")
else
    print("❌ Lazy.nvim is not available")
end

-- Check Mason installation
local mason_ok, mason = pcall(require, "mason")
if mason_ok then
    print("✅ Mason is available")
    
    -- Check Mason registry
    local registry_ok, registry = pcall(require, "mason-registry")
    if registry_ok then
        local installed = registry.get_installed_packages()
        print("📦 Installed Mason packages: " .. #installed)
        for _, pkg in ipairs(installed) do
            print("  - " .. pkg.name)
        end
    end
else
    print("❌ Mason is not available")
end

-- Check LSP servers
local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
if lspconfig_ok then
    print("✅ LSPConfig is available")
    
    -- List of expected servers
    local expected_servers = {
        "lua_ls", "bashls", "basedpyright", "gopls", "vtsls", 
        "yamlls", "dockerls", "tailwindcss"
    }
    
    for _, server in ipairs(expected_servers) do
        if lspconfig[server] then
            print("✅ LSP server configured: " .. server)
        else
            print("⚠️  LSP server not configured: " .. server)
        end
    end
else
    print("❌ LSPConfig is not available")
end

-- Check Treesitter
local ts_ok, ts = pcall(require, "nvim-treesitter")
if ts_ok then
    print("✅ Treesitter is available")
else
    print("❌ Treesitter is not available")
end

print("\n=== Health Check Complete ===")
print("Run ':checkhealth' in Neovim for more detailed diagnostics")
