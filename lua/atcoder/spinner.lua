local spinner_symbols = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local spinner = {}
function spinner.new()
  ---@class Spinner
  ---@field idx integer
  ---@field timer uv_timer_t
  ---@field bufnr integer
  ---@field winid integer
  local obj = {
    idx = 1,
    timer = nil,
    bufnr = vim.api.nvim_create_buf(false, true),
    winid = -1,
  }

  obj.start = function(self)
    self.winid = vim.api.nvim_open_win(self.bufnr, false, {
      relative = 'editor',
      width = 10,
      height = 1,
      col = vim.o.columns - 1,
      row = vim.o.lines - 3.5,
      style = 'minimal',
      border = 'single',
    })
    self.timer = vim.uv.new_timer()
    vim.uv.timer_start(self.timer, 0, 100, function()
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { spinner_symbols[self.idx] .. ' building' })
        self.idx = (self.idx % #spinner_symbols) + 1
      end)
    end)
  end

  obj.stop = function(self)
    if self.timer ~= nil then
      self.timer:stop()
      self.timer:close()
    end
    if vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, true)
    end
  end

  return obj
end

-- local sp = spinner.new()
-- sp:start()
-- vim.wait(10000)
-- sp:stop()

return spinner
