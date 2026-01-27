-- Configuration enabled by setup script

-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    -- Configuration table of features provided by AstroLSP
    features = {
      codelens = true, -- enable/disable codelens refresh on start
      inlay_hints = true, -- enable inlay hints on start
      semantic_tokens = true, -- enable/disable semantic token highlighting
    },
    -- customize lsp formatting options
    formatting = {
      -- control auto formatting on save
      format_on_save = {
        enabled = true, -- enable format on save globally
        allow_filetypes = { -- enable format on save for specified filetypes
          "lua",
          "python", 
          "go",
          "javascript",
          "typescript",
          "json",
          "yaml",
          "html",
          "css",
          "markdown",
          "sh",
          "bash",
        },
        ignore_filetypes = { -- disable format on save for specified filetypes
          -- Add any filetypes you want to skip formatting
        },
      },
      disabled = { -- disable formatting capabilities for the listed language servers
        -- Disable built-in formatters in favor of external ones
        "lua_ls", -- Use stylua instead
        "basedpyright", -- Use ruff instead
        "tsserver", -- Use prettier instead
      },
      timeout_ms = 3000, -- increased timeout for slower formatters
    },
    -- enable servers that you already have installed without mason
    servers = {},
    -- customize language server configuration options passed to `lspconfig`
    config = {
      -- Lua LSP configuration
      lua_ls = {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
              path = vim.split(package.path, ";"),
            },
            diagnostics = {
              globals = { "vim" }, -- recognize 'vim' global
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
            format = {
              enable = false, -- Use stylua instead
            },
          },
        },
      },
      -- Python LSP configuration
      basedpyright = {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoImportCompletions = true,
            },
          },
        },
      },
      -- Ruff LSP configuration (Python linting/formatting)
      ruff_lsp = {
        init_options = {
          settings = {
            args = {
              "--line-length=88",
              "--select=E,W,F,I,N,UP,YTT,S,BLE,FBT,B,A,COM,C4,DTZ,T10,EM,EXE,ISC,ICN,G,INP,PIE,T20,PYI,PT,Q,RSE,RET,SLF,SIM,TID,TCH,INT,ARG,PTH,ERA,PD,PGH,PL,TRY,NPY,RUF",
            },
          },
        },
      },
      -- Go LSP configuration
      gopls = {
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
            },
            staticcheck = true,
            gofumpt = true,
          },
        },
      },
      -- TypeScript/JavaScript configuration
      vtsls = {
        settings = {
          typescript = {
            preferences = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = true,
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
          },
        },
      },
      -- Deno configuration (disabled by default to avoid conflicts)
      denols = {
        autostart = false, -- Only start when deno.json/deno.jsonc is present
        root_dir = require("lspconfig.util").root_pattern("deno.json", "deno.jsonc"),
      },
    },
    -- customize how language servers are attached
    handlers = {
      -- Ensure Deno and Node.js LSPs don't conflict
      denols = function(_, opts)
        opts.root_dir = require("lspconfig.util").root_pattern("deno.json", "deno.jsonc")
        require("lspconfig").denols.setup(opts)
      end,
      vtsls = function(_, opts)
        opts.root_dir = require("lspconfig.util").root_pattern("package.json", "tsconfig.json", "jsconfig.json")
        require("lspconfig").vtsls.setup(opts)
      end,
    },
    -- Configure buffer local auto commands to add when attaching a language server
    autocmds = {
      lsp_codelens_refresh = {
        cond = "textDocument/codeLens",
        {
          event = { "InsertLeave", "BufEnter" },
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then 
              vim.lsp.codelens.refresh { bufnr = args.buf } 
            end
          end,
        },
      },
    },
    -- mappings to be set up on attaching of a language server
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
        ["<Leader>uY"] = {
          function() require("astrolsp.toggles").buffer_semantic_tokens() end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client.supports_method "textDocument/semanticTokens/full" and vim.lsp.semantic_tokens ~= nil
          end,
        },
      },
    },
    -- A custom `on_attach` function to be run after the default `on_attach` function
    on_attach = function(client, bufnr)
      -- Configure specific client capabilities
      if client.name == "ruff_lsp" then
        -- Disable hover in favor of basedpyright
        client.server_capabilities.hoverProvider = false
      end
    end,
  },
}
