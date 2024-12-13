local M = {}

---@class Window
---@field bufnr integer
---@field winid integer
---@field open function

function M.new(bufnr)
  ---@type Window
  ---@diagnostic disable-next-line
  local obj = {
    bufnr = bufnr,
    winid = -1,
  }

  obj.open = function(self)
    if not vim.api.nvim_win_is_valid(self.winid) then
      self.winid = vim.api.nvim_open_win(self.bufnr, false, {
        split = 'right',
        width = math.floor(vim.o.columns * 0.4),
        style = 'minimal',
      })
    end
  end

  return obj
end

return M
