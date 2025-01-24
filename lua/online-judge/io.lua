local M = {}

function M.isdirectory(dirname)
  return vim.fn.isdirectory(dirname) == 1
end

return M
