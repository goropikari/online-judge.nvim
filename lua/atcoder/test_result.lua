local spinner = require('atcoder.spinner')

local M = {}

---@class TestResultViewer
---@field open function
---@field reset_test_cases function
---@field update function
---@field get_state function
---@field start_spinner function
---@field stop_spinner function
---@field register_rerun_fn function
---@field register_submit_fn function
---
---@field bufnr integer
---@field winid integer
---@field test_cases {string:integer}
---@field spin Spinner
---@field source_code string
---@field command string
---@field test_dir_path string
---@field filetype string
---@field contest_id? string
---@field problem_id? string
---@field lang_id integer
---@field rerun_fn function
---@field submit_fn function

---@class TestResult
---@field source_code string
---@field command string
---@field result string[]
---@field test_dir_path string
---@field filetype string
---@field lang_id integer
---@field contest_id? string
---@field problem_id? string

function M.new()
  ---@type TestResultViewer
  ---@diagnostic disable-next-line
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
  obj.spin = spinner.new(obj.bufnr)

  obj.open = function(self)
    local hidden = false
    hidden = hidden or (not vim.api.nvim_win_is_valid(self.winid))
    hidden = hidden or vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_win_get_buf(self.winid) }) ~= 'atcoder'

    if hidden then
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
    self.contest_id = test_result.contest_id
    self.problem_id = test_result.problem_id
    self.filetype = test_result.filetype
    self.lang_id = test_result.lang_id
    local lines = test_result.result
    for i, line in ipairs(lines) do
      line = line:gsub('^%[%w+%]%s', '')
      line = line:gsub('^sample%-', '▷ sample%-')
      line = line:gsub('^custom%-', '▷ custom%-')
      lines[i] = line
    end
    lines = vim.list_extend({
      'contest_id: ' .. (test_result.contest_id or ''),
      'problem_id: ' .. (test_result.problem_id or ''),
      'test_dir: ' .. test_result.test_dir_path,
      'source_code: ' .. test_result.source_code,
      'command: ' .. test_result.command,
      '',
      'help',
      '  r:    rerun test cases',
      '  e:    edit test case',
      '  <CR>: view/hide test case',
      '  s:    submit',
      '  d:    debug log',
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

  function obj.register_rerun_fn(self, fn)
    self.rerun_fn = fn
  end

  function obj.register_submit_fn(self, fn)
    self.submit_fn = fn
  end

  function obj.get_state(self)
    return {
      source_code = self.source_code,
      command = self.command,
      test_dir_path = self.test_dir_path,
      contest_id = self.contest_id,
      problem_id = self.problem_id,
      filetype = self.filetype,
    }
  end

  function obj.start_spinner(self)
    self.spin:start()
  end
  function obj.stop_spinner(self)
    self.spin:stop()
  end

  -- rerun test cases
  vim.keymap.set({ 'n' }, 'r', function()
    obj.rerun_fn()
  end, {
    buffer = obj.bufnr,
  })

  vim.keymap.set({ 'n' }, 's', function()
    obj.submit_fn()
  end, {
    buffer = obj.bufnr,
  })

  -- edit test case
  vim.keymap.set({ 'n' }, 'e', function()
    local test_dir_path = obj.test_dir_path
    local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w+%-%d+') or ''
    test_case = string.match(test_case, '%w+%-%d+') or ''
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 or vim.fn.filereadable(output_file_path) == 0 then
      -- do nothing if file is not exist.
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
    local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w+%-%d+') or ''
    test_case = string.match(test_case, '%w+%-%d+') or ''
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

  -- debug
  vim.keymap.set({ 'n' }, 'd', function()
    vim.print(vim.inspect(obj))
    vim.cmd('mess')
  end, {
    buffer = obj.bufnr,
  })

  return obj
end

return M
