return {
  {
    -- タイプしたキーを表示する
    'nvzone/showkeys',
    cmd = 'ShowkeysToggle',
  },
  {
    'stevearc/conform.nvim',
    opts = {},
  },
  {
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
    config = function()
      vim.defer_fn(function()
        require('nvim-treesitter.configs').setup({
          ensure_installed = { 'cpp', 'python' },
        })
      end, 0)
    end,
  },
  {
    'williamboman/mason.nvim',
    opts = {},
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = {
      'williamboman/mason.nvim',
    },
    opts = {
      ensure_installed = { 'codelldb', 'cpptools', 'stylua', 'typos-lsp' },
    },
  },
}
