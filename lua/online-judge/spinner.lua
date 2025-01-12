local spinner = {}

local spinner_symbols = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

function spinner.new(bufnr, processing_msg)
  ---@class Spinner
  ---@field idx integer
  ---@field timer uv_timer_t
  ---@field bufnr integer
  local obj = {
    idx = 1,
    timer = nil, ---@diagnostic disable-line
    bufnr = bufnr,
    msg = processing_msg or 'processing',
  }

  obj.start = function(self)
    if self.timer ~= nil then
      self:stop()
    end
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.bufnr })
    self.timer = vim.uv.new_timer()
    vim.uv.timer_start(self.timer, 0, 100, function()
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { spinner_symbols[self.idx] .. ' ' .. self.msg })
        self.idx = (self.idx % #spinner_symbols) + 1
      end)
    end)
  end

  obj.stop = function(self)
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })
    if self.timer ~= nil then
      self.timer:stop()
      self.timer:close()
      self.timer = nil
    end
  end

  return obj
end

return spinner
