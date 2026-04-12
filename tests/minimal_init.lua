local root = vim.fn.getcwd()
local plenary = root .. '/deps/plenary.nvim'

vim.opt.runtimepath:prepend(root)

if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.runtimepath:prepend(plenary)
end

vim.opt.packpath = vim.opt.runtimepath:get()
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.loadplugins = true
