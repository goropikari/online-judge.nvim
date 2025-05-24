local lang = require('online-judge.language')
local spinner = require('online-judge.spinner')
local utils = require('online-judge.utils')
local config = require('online-judge.config')

local M = {}

local buf_filetype = 'online_judge'
M.buf_filetype = buf_filetype

local test_case_name_pattern = '%a[%w%-_]*%d+'

---@class TestResultViewer
---@field open fun(TestResultViewer)
---@field close fun(TestResultViewer)
---@field toggle fun(TestResultViewer)
---@field reset_test_cases fun(TestResultViewer)
---@field update fun(TestResultViewer, TestResult, function)
---@field get_state function
---@field start_spinner fun(TestResultViewer)
---@field stop_spinner fun(TestResultViewer)
---@field register_rerun_fn fun(TestResultViewer, fn)
---@field register_submit_fn fun(TestResultViewer, fn)
---@field _test_file_prefix fun(TestResultViewer): string
---@field _test_file_path_under_cursor fun(TestResultViewer): {input:string, output:string}
---@field _open_test_case fun(input_path:string, output_path:string)
---
---@field bufnr integer
---@field test_case_preview_length {string:integer}
---@field test_case_display_length {string:integer}
---@field spin Spinner
---@field rerun_fn function
---@field submit_fn function
---
---@field file_path string
---@field command string
---@field test_dir_path string

---@class TestResult
---@field file_path string
---@field command string
---@field test_dir_path string
---@field result string[]

function M.new()
  ---@type TestResultViewer
  ---@diagnostic disable-next-line
  local obj = {
    bufnr = (function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value('filetype', buf_filetype, { buf = bufnr })
      return bufnr
    end)(),
    test_case_preview_length = {},
    test_case_display_length = {},
    file_path = '',
    command = '',
    test_dir_path = '',
  }
  obj.spin = spinner.new(obj.bufnr)

  obj.open = function(self)
    -- split をしたときに winid が元のものとは別のものが割りあたっていることがあるため常に buffer 基準で winid を取得しなければならない
    local winid = utils.get_window_id(self.bufnr)
    local hidden = not vim.api.nvim_win_is_valid(winid)

    if hidden then
      vim.api.nvim_open_win(self.bufnr, false, {
        split = 'right',
        width = math.floor(vim.o.columns * 0.4),
        style = 'minimal',
      })
    end
  end

  obj.close = function(self)
    local winid = utils.get_window_id(self.bufnr)
    local hidden = not vim.api.nvim_win_is_valid(winid)

    if not hidden then
      vim.api.nvim_win_close(winid, false)
    end
  end

  obj.toggle = function(self)
    local winid = utils.get_window_id(self.bufnr)
    local hidden = not vim.api.nvim_win_is_valid(winid)

    if hidden then
      obj:open()
    else
      obj:close()
    end
  end

  obj.reset_test_cases = function(self)
    self.test_case_preview_length = {}
  end

  ---@param test_result TestResult
  ---@param callback function
  function obj.update(self, test_result, callback)
    self.file_path = test_result.file_path
    self.command = test_result.command
    self.test_dir_path = test_result.test_dir_path
    local lines = test_result.result
    for i, line in ipairs(lines) do
      line = line:gsub('^%[%w+%]%s(' .. test_case_name_pattern .. ')', '▷ %1')
      line = line:gsub('^%[%w+%]%s', '')
      lines[i] = line
    end

    local cnt = 1
    local prev_file = ''
    for _, v in ipairs(lines) do
      local match_str = string.match(v, test_case_name_pattern .. '$')
      if match_str then
        self.test_case_display_length[prev_file] = cnt
        prev_file = match_str
        cnt = 0
      elseif string.match(v, '^slowest') then
        break
      else
        cnt = cnt + 1
      end
    end
    self.test_case_display_length[prev_file] = cnt
    self.test_case_display_length[''] = nil

    lines = vim.list_extend({
      'test_dir: ' .. test_result.test_dir_path,
      'file_path: ' .. test_result.file_path,
      'command: ' .. test_result.command,
      'exact_match: ' .. tostring(config.exact_match()) .. ', ' .. config.precision(),
      '',
      'help',
      '  r:    rerun test cases',
      '  d:    debug test case',
      '  <CR>: view/hide test case',
      '  a:    add test case',
      '  e:    edit test case',
      '  c:    copy test case',
      '  D:    delete test case',
      '  s:    submit with test',
      '  S:    show internal state for plugin debugging',
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
      file_path = self.file_path,
      command = self.command,
      test_dir_path = self.test_dir_path,
    }
  end

  function obj.start_spinner(self)
    self.spin:start()
  end
  function obj.stop_spinner(self)
    vim.schedule(function()
      self.spin:stop()
    end)
  end

  ---@return string
  ---@diagnostic disable-next-line
  function obj._test_file_prefix(self)
    local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w[%w%-_]*%d+') or ''
    test_case = string.match(test_case, '%w[%w%-_]*%d+') or ''
    return test_case
  end

  function obj._test_file_path_under_cursor(self)
    local test_case = obj:_test_file_prefix()
    local file_path_prefix = vim.fs.joinpath(self.test_dir_path, test_case)

    return {
      input = file_path_prefix .. '.in',
      output = file_path_prefix .. '.out',
    }
  end

  ---@param input_path string
  ---@param output_path string
  function obj._open_test_case(input_path, output_path)
    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. input_path)
    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. output_path)
    vim.cmd('wincmd k')
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

  ---@param input_bufnr integer
  ---@param output_bufnr integer
  local function buf_config(input_bufnr, output_bufnr)
    local ns_id = vim.api.nvim_create_namespace('online_judge_nvim_namespace')

    ---@param buf integer
    local function close_win(buf)
      local windows = vim.api.nvim_list_wins()

      for _, win_id in ipairs(windows) do
        if vim.api.nvim_win_get_buf(win_id) == buf then
          vim.api.nvim_win_close(win_id, false)
        end
      end

      -- TODO: delete buffer
      -- if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      --   vim.cmd('bd ' .. buf)
      -- end
    end

    ---@param input_buf integer
    ---@param output_buf integer
    local function close_wins(input_buf, output_buf)
      obj:open()
      local winid = utils.get_window_id(obj.bufnr)
      vim.api.nvim_set_current_win(winid)

      close_win(input_buf)
      close_win(output_buf)
    end

    -- buffer1 の win 閉じられたときに buffer2  の win も閉じる
    vim.api.nvim_create_autocmd('WinClosed', {
      buffer = input_bufnr,
      callback = function()
        close_wins(input_bufnr, output_bufnr)
      end,
    })

    -- buffer2 の win 閉じられたときに buffer1  の win も閉じる
    vim.api.nvim_create_autocmd('WinClosed', {
      buffer = output_bufnr,
      callback = function()
        close_wins(input_bufnr, output_bufnr)
      end,
    })

    local bufs = {
      { msg = 'input file', bufnr = input_bufnr },
      { msg = 'output file', bufnr = output_bufnr },
    }
    for i, v in ipairs(bufs) do
      vim.api.nvim_buf_set_extmark(v.bufnr, ns_id, 0, 0, {
        virt_text = { { v.msg, 'Comment' } },
        virt_text_pos = 'eol', -- 行末に表示
      })
      vim.api.nvim_create_autocmd({ 'InsertEnter', 'WinClosed' }, {
        buffer = v.bufnr,
        callback = function()
          vim.api.nvim_buf_clear_namespace(bufs[i].bufnr, ns_id, 0, -1)
          vim.api.nvim_buf_clear_namespace(bufs[3 - i].bufnr, ns_id, 0, -1)
        end,
      })
    end
  end

  ---@param paths {input:string,output:string}
  local function open_test_cases(paths)
    obj._open_test_case(paths.input, paths.output)
    local input_bufnr = vim.fn.bufnr(paths.input)
    local output_bufnr = vim.fn.bufnr(paths.output)
    buf_config(input_bufnr, output_bufnr)
  end

  -- edit test case
  vim.keymap.set({ 'n' }, 'e', function()
    if string.match(obj:_test_file_prefix(), '^sample%-') or string.match(obj:_test_file_prefix(), '^example_') then
      utils.notify('could not edit sample test case. copy and then edit it.', vim.log.levels.WARN)
      return
    end

    local test_file_path = obj:_test_file_path_under_cursor()
    if vim.fn.filereadable(test_file_path.input) == 0 or vim.fn.filereadable(test_file_path.output) == 0 then
      -- do nothing if file is not exist.
      return
    end

    open_test_cases(test_file_path)
  end, {
    buffer = obj.bufnr,
  })

  -- add test case
  vim.keymap.set({ 'n' }, 'a', function()
    local id = utils.maximum_test_id(obj.test_dir_path, 'custom')
    id = id + 1

    local input_file_path = string.format('%s/custom-%d.in', obj.test_dir_path, id)
    local output_file_path = string.format('%s/custom-%d.out', obj.test_dir_path, id)

    open_test_cases({ input = input_file_path, output = output_file_path })
  end, {
    buffer = obj.bufnr,
  })

  -- copy test case
  vim.keymap.set({ 'n' }, 'c', function()
    local id = utils.maximum_test_id(obj.test_dir_path, 'custom')
    id = id + 1

    local from_path = obj:_test_file_path_under_cursor()
    local to_path = {
      input = string.format('%s/custom-%d.in', obj.test_dir_path, id),
      output = string.format('%s/custom-%d.out', obj.test_dir_path, id),
    }

    for _, v in ipairs({ 'input', 'output' }) do
      vim
        .system({
          'cp',
          from_path[v],
          to_path[v],
        })
        :wait()
    end

    open_test_cases(to_path)
  end, {
    buffer = obj.bufnr,
  })

  -- delete test case
  vim.keymap.set({ 'n' }, 'D', function()
    local test_case = obj:_test_file_prefix()
    if string.match(test_case, '^sample%-') or string.match(test_case, '^example_') then
      utils.notify('could not delete sample test case', vim.log.levels.WARN)
      return
    end

    local test_file_path = obj:_test_file_path_under_cursor()

    if vim.fn.filereadable(test_file_path.input) == 0 then
      -- do nothing if file does not exist.
      return
    end
    for _, v in ipairs({ test_file_path.input, test_file_path.output }) do
      if vim.api.nvim_buf_is_loaded(vim.fn.bufnr(v)) then
        vim.cmd('bd ' .. v)
      end
    end
    local remove = vim.fn.input('remove test case [y/N]: ')
    local yes = { yes = true, y = true }
    if yes[string.lower(remove)] then
      vim.system({
        'rm',
        '-f',
        test_file_path.input,
        test_file_path.output,
      }, {}, function(out)
        if out.code ~= 0 then
          utils.notify(out.stderr, vim.log.levels.ERROR)
          return
        end

        vim.schedule(function()
          vim.api.nvim_set_option_value('modifiable', true, { buf = obj.bufnr })
          local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
          row = row - 1
          local delete_num_lines = (obj.test_case_preview_length[test_case] or 0) + obj.test_case_display_length[test_case] + 1
          vim.api.nvim_buf_set_lines(obj.bufnr, row, row + delete_num_lines, false, {})
          obj.test_case_preview_length[test_case] = nil
          obj.test_case_display_length[test_case] = nil
          vim.api.nvim_set_option_value('modifiable', false, { buf = obj.bufnr })
        end)
      end)
    end
  end, {
    buffer = obj.bufnr,
  })

  -- preview test case
  vim.keymap.set({ 'n' }, '<CR>', function()
    local test_case = obj:_test_file_prefix()
    local test_case_path = obj:_test_file_path_under_cursor()

    if vim.fn.filereadable(test_case_path.input) == 0 then
      -- do nothing if file is not exist.
      return
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = obj.bufnr })
    local input = vim.fn.readfile(test_case_path.input, 'r')
    local output = vim.fn.readfile(test_case_path.output, 'r')

    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local hidden = obj.test_case_preview_length[test_case] == nil
    if hidden then
      local line = vim.api.nvim_buf_get_lines(obj.bufnr, row - 1, row, false)[1]
      line = line:gsub('▷ ', '▽ ')
      vim.api.nvim_buf_set_lines(obj.bufnr, row - 1, row, false, { line })
      obj.test_case_preview_length[test_case] = #input + #output + 4 -- 4 = input, newline, output, newline
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
      local delete_num_lines = obj.test_case_preview_length[test_case]
      vim.api.nvim_buf_set_lines(obj.bufnr, row, row + delete_num_lines, false, {})
      obj.test_case_preview_length[test_case] = nil
    end
    vim.api.nvim_set_option_value('modifiable', false, { buf = obj.bufnr })
  end, {
    buffer = obj.bufnr,
  })

  -- debug test case under cursor
  vim.keymap.set({ 'n' }, 'd', function()
    local ok, dap = pcall(require, 'dap')
    if not ok then
      utils.notify('nvim-dap is required', vim.log.levels.ERROR)
      return
    end

    -- window 移動する前に実行しなければならない
    local test_file_path = obj:_test_file_path_under_cursor()

    local winid = utils.get_window_id_for_file(obj.file_path)
    vim.api.nvim_set_current_win(winid)

    local filetype = utils.get_filetype(obj.file_path)
    local dap_config = lang.get_option(filetype).dap_config({
      file_path = obj.file_path,
      input_test_file_path = test_file_path.input,
    })
    dap.run(dap_config)
  end, {
    buffer = obj.bufnr,
  })

  -- show internal state
  vim.keymap.set({ 'n' }, 'S', function()
    vim.print(vim.inspect(obj))
    vim.cmd('mess')
  end, {
    buffer = obj.bufnr,
  })

  return obj
end

---@return boolean
function M.is_in_test_result_buf()
  return vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == buf_filetype
end

return M
