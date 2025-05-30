-- Neovim configuration for MufiZ language support with Tree-sitter
-- Place this in your init.lua or create a separate ftplugin/mufiz.lua file

-- Ensure Tree-sitter is installed
require('nvim-treesitter.configs').setup {
  -- Add mufiz to the list of parsers to install
  ensure_installed = {
    "c", "lua", "vim", "vimdoc", "query",
    "mufiz"  -- Add MufiZ support
  },

  -- Enable syntax highlighting
  highlight = {
    enable = true,
    -- Set this to true if you depend on 'syntax' being enabled (like for indentation).
    additional_vim_regex_highlighting = false,
  },

  -- Enable incremental selection
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },

  -- Enable indentation
  indent = {
    enable = true
  },

  -- Enable folding
  fold = {
    enable = true
  }
}

-- File type detection for .mufi files
vim.filetype.add({
  extension = {
    mufi = 'mufiz',
  },
})

-- Set up MufiZ-specific options
vim.api.nvim_create_autocmd("FileType", {
  pattern = "mufiz",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    
    -- Basic editor settings
    vim.bo[buf].shiftwidth = 4
    vim.bo[buf].tabstop = 4
    vim.bo[buf].softtabstop = 4
    vim.bo[buf].expandtab = true
    vim.bo[buf].smartindent = true
    
    -- Comment string for commenting/uncommenting
    vim.bo[buf].commentstring = "// %s"
    
    -- Set up local keymaps for MufiZ files
    local opts = { buffer = buf, silent = true }
    
    -- Run current file
    vim.keymap.set('n', '<leader>r', function()
      local filename = vim.fn.expand('%:p')
      vim.cmd('split | terminal mufiz -r ' .. vim.fn.shellescape(filename))
    end, opts)
    
    -- Format file (if formatter is available)
    vim.keymap.set('n', '<leader>f', function()
      vim.lsp.buf.format()
    end, opts)
    
    -- Quick compile check
    vim.keymap.set('n', '<leader>c', function()
      local filename = vim.fn.expand('%:p')
      vim.cmd('!mufiz --check ' .. vim.fn.shellescape(filename))
    end, opts)
  end,
})

-- Custom highlights for MufiZ (optional)
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    -- Customize MufiZ-specific highlighting
    vim.api.nvim_set_hl(0, '@keyword.mufiz', { link = 'Keyword' })
    vim.api.nvim_set_hl(0, '@function.mufiz', { link = 'Function' })
    vim.api.nvim_set_hl(0, '@string.mufiz', { link = 'String' })
    vim.api.nvim_set_hl(0, '@comment.mufiz', { link = 'Comment' })
    vim.api.nvim_set_hl(0, '@constant.numeric.mufiz', { link = 'Number' })
    vim.api.nvim_set_hl(0, '@constant.builtin.boolean.mufiz', { link = 'Boolean' })
    vim.api.nvim_set_hl(0, '@type.mufiz', { link = 'Type' })
    vim.api.nvim_set_hl(0, '@variable.parameter.mufiz', { link = 'Parameter' })
    vim.api.nvim_set_hl(0, '@property.mufiz', { link = 'Property' })
  end,
})

-- Text objects for MufiZ (using Tree-sitter)
require('nvim-treesitter.configs').setup {
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        -- Functions
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        
        -- Classes
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        
        -- Loops
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        
        -- Conditionals
        ["ai"] = "@conditional.outer",
        ["ii"] = "@conditional.inner",
        
        -- Blocks
        ["ab"] = "@block.outer",
        ["ib"] = "@block.inner",
        
        -- Parameters
        ["ap"] = "@parameter.outer",
        ["ip"] = "@parameter.inner",
      },
    },
    
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]f"] = "@function.outer",
        ["]c"] = "@class.outer",
        ["]l"] = "@loop.outer",
        ["]i"] = "@conditional.outer",
      },
      goto_next_end = {
        ["]F"] = "@function.outer",
        ["]C"] = "@class.outer",
        ["]L"] = "@loop.outer",
        ["]I"] = "@conditional.outer",
      },
      goto_previous_start = {
        ["[f"] = "@function.outer",
        ["[c"] = "@class.outer",
        ["[l"] = "@loop.outer",
        ["[i"] = "@conditional.outer",
      },
      goto_previous_end = {
        ["[F"] = "@function.outer",
        ["[C"] = "@class.outer",
        ["[L"] = "@loop.outer",
        ["[I"] = "@conditional.outer",
      },
    },
  },
}

-- LSP configuration (if you have a MufiZ language server)
local lspconfig = require('lspconfig')

-- Custom LSP configuration for MufiZ
local configs = require('lspconfig.configs')

if not configs.mufiz_lsp then
  configs.mufiz_lsp = {
    default_config = {
      cmd = {'mufiz-lsp'}, -- Replace with actual LSP server command
      filetypes = {'mufiz'},
      root_dir = lspconfig.util.root_pattern('.git', 'build.zig'),
      settings = {},
    },
  }
end

-- Enable the LSP
lspconfig.mufiz_lsp.setup {
  on_attach = function(client, bufnr)
    -- LSP keymaps
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  end,
  capabilities = require('cmp_nvim_lsp').default_capabilities()
}

-- Snippets for MufiZ (using LuaSnip)
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node

ls.add_snippets("mufiz", {
  -- Variable declaration
  s("var", {
    t("var "), i(1, "name"), t(" = "), i(2, "value"), t(";")
  }),
  
  -- Function declaration
  s("fun", {
    t("fun "), i(1, "name"), t("("), i(2, "params"), t(") {"), t({"", "\t"}),
    i(3, "// body"), t({"", "}"})
  }),
  
  -- Class declaration
  s("class", {
    t("class "), i(1, "Name"), t(" {"), t({"", "\t"}),
    i(2, "// class body"), t({"", "}"})
  }),
  
  -- Foreach loop
  s("foreach", {
    t("foreach ("), i(1, "item"), t(" in "), i(2, "collection"), t(") {"), t({"", "\t"}),
    i(3, "// loop body"), t({"", "}"})
  }),
  
  -- If statement
  s("if", {
    t("if ("), i(1, "condition"), t(") {"), t({"", "\t"}),
    i(2, "// then"), t({"", "}"})
  }),
  
  -- Print statement
  s("print", {
    t("print "), i(1, "value"), t(";")
  }),
  
  -- Vector literal
  s("vec", {
    t("{"), i(1, "1.0, 2.0, 3.0"), t("}")
  }),
  
  -- Hash table literal
  s("table", {
    t("table{"), i(1, '"key": "value"'), t("}")
  }),
})