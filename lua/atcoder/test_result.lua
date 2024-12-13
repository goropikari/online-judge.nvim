local M = {}

---@class TestResult
---@field test_dir_path string
---@field source_code string
---@field command string
---@field result string[]

function M.new()
  local obj = {
    bufnr = (function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value('filetype', 'atcoder', { buf = bufnr })
      return bufnr
    end)(),
    winid = -1,
    test_cases = {},
    source_code = '',
    command = '',
    test_dir_path = '',
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

  obj.reset_test_cases = function(self)
    self.test_cases = {}
  end

  ---@param test_result TestResult
  ---@param callback function
  function obj.update(self, test_result, callback)
    self.source_code = test_result.source_code
    self.command = test_result.command
    self.test_dir_path = test_result.test_dir_path
    local lines = test_result.result
    for i, line in ipairs(lines) do
      line = line:gsub('^%[%w+%]%s', '')
      line = line:gsub('^sample%-', '▷ sample%-')
      line = line:gsub('^custom%-', '▷ custom%-')
      lines[i] = line
    end
    lines = vim.list_extend({
      'test_dir: ' .. test_result.test_dir_path,
      'source code: ' .. test_result.source_code,
      'cmd: ' .. test_result.command,
      '',
      'help',
      '  e:    edit test case',
      '  <CR>: view/hide test case',
      '',
    }, lines)
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.bufnr })
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { 'Executed at:', vim.fn.strftime('%c') })
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })
    self:open()

    if type(callback) == 'function' then
      callback()
    end
  end

  -- debug
  vim.keymap.set({ 'n' }, 'd', function()
    vim.print(vim.inspect(obj))
    vim.cmd('mess')
  end)

  -- edit test case
  vim.keymap.set({ 'n' }, 'e', function()
    local test_dir_path = obj.test_dir_path
    local test_case = vim.fn.expand('<cWORD>')
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 or vim.fn.filereadable(output_file_path) == 0 then
      -- do nothing if file is not exist.
      vim.print(input_file_path, output_file_path)
      return
    end

    vim.cmd('vsplit')
    vim.cmd('split')
    vim.cmd('edit ' .. input_file_path)
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. output_file_path)
  end, {
    buffer = obj.bufnr,
  })

  -- preview test case
  vim.keymap.set({ 'n' }, '<CR>', function()
    local test_dir_path = obj.test_dir_path
    local test_case = vim.fn.expand('<cWORD>')
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 then
      -- do nothing if file is not exist.
      return
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = obj.bufnr })
    local input = vim.fn.readfile(input_file_path, 'r')
    local output = vim.fn.readfile(output_file_path, 'r')

    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local hidden = obj.test_cases[test_case] == nil
    if hidden then
      local line = vim.api.nvim_buf_get_lines(obj.bufnr, row - 1, row, false)[1]
      line = line:gsub('▷ ', '▽ ')
      vim.api.nvim_buf_set_lines(obj.bufnr, row - 1, row, false, { line })
      obj.test_cases[test_case] = #input + #output + 4 -- 4 = input, newline, output, newline
      vim.api.nvim_buf_set_lines(
        obj.bufnr,
        row,
        row,
        false,
        vim
          .iter({
            'input',
            input,
            '',
            'output',
            output,
            '',
          })
          :flatten()
          :totable()
      )
    else
      local line = vim.api.nvim_buf_get_lines(obj.bufnr, row - 1, row, false)[1]
      line = line:gsub('▽ ', '▷ ')
      vim.api.nvim_buf_set_lines(obj.bufnr, row - 1, row, false, { line })
      local delete_num_lines = obj.test_cases[test_case]
      vim.api.nvim_buf_set_lines(obj.bufnr, row, row + delete_num_lines, false, {})
      obj.test_cases[test_case] = nil
    end
    vim.api.nvim_set_option_value('modifiable', false, { buf = obj.bufnr })
  end, {
    buffer = obj.bufnr,
  })

  return obj
end

return M
