vim.g.mapleader = ','
vim.g.maplocalleader = ','
vim.wo.number = true
vim.wo.signcolumn = 'yes'
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4

-- clipboard
vim.opt.clipboard = 'unnamedplus' -- Sync with system clipboard

-- https://neovim.io/doc/user/provider.html#clipboard-osc52
if vim.fn.has('wsl') == 1 or os.getenv('HOSTNAME') ~= nil then
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    },
    paste = {
      -- https://github.com/neovim/neovim/discussions/28010#discussioncomment-9877494
      ['+'] = function()
        return {
          vim.fn.split(vim.fn.getreg(''), '\n'),
          vim.fn.getregtype(''),
        }
      end,
    },
  }
end

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require('lazy').setup({
  spec = {
    {
      'mfussenegger/nvim-dap',
      version = '0.8.0',
      dependencies = {
        {
          -- Creates a beautiful debugger UI
          'rcarriga/nvim-dap-ui',
          dependencies = { 'nvim-neotest/nvim-nio' },
          config = function()
            local dap = require('dap')
            local dapui = require('dapui')
            dapui.setup()
            dap.listeners.after.event_initialized['dapui_config'] = dapui.open
            dap.listeners.before.event_terminated['dapui_config'] = dapui.close
            dap.listeners.before.event_exited['dapui_config'] = dapui.close
          end,
        },
        {
          -- code 中に変数の値を表示する
          'theHamsta/nvim-dap-virtual-text',
          opts = {},
        },
      },
      keys = {
        { '<leader>d', desc = 'Debug' },
        {
          '<leader>dC',
          function()
            require('dap').clear_breakpoints()
          end,
          desc = 'Debug: Clear Breakpoint',
        },
        {
          '<leader>db',
          function()
            require('dap').toggle_breakpoint()
          end,
          desc = 'Debug: Toggle Breakpoint',
        },
        {
          '<leader>dc',
          function()
            require('dap').toggle_breakpoint(vim.fn.input('debug condition: '))
          end,
          desc = 'Debug: Toggle Conditional Breakpoint',
        },
        {
          '<leader>duc',
          function()
            require('dapui').close()
          end,
          desc = 'Close DAP UI',
        },
        {
          '<F5>',
          function()
            require('dap').continue()
          end,
          desc = 'Debug: Continue',
        },
        {
          '<F10>',
          function()
            require('dap').step_over()
          end,
          desc = 'Debug: Step over',
        },
      },
    },
    {
      'mfussenegger/nvim-dap-python',
      ft = { 'python' },
      config = function()
        require('dap-python').setup('python3')
      end,
    },
    {
      dir = '/workspaces/atcoder.nvim',
      dependencies = {
        'nvim-lua/plenary.nvim',
      },
      opts = {},
    },
    -- { import = 'plugins' },
  },
  install = { colorscheme = { 'habamax' } },
  checker = { enabled = true },
})

vim.cmd('colorscheme habamax')
