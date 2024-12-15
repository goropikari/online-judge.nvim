local lang = require('atcoder.language')
local spinner = require('atcoder.spinner')
local utils = require('atcoder.utils')

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
---@field _test_file_path function
---
---@field bufnr integer
---@field test_case_preview_length {string:integer}
---@field test_case_display_length {string:integer}
---@field origin_dap_adapters {string:dap.Adapter}
---@field spin Spinner
---@field rerun_fn function
---@field submit_fn function
---
---@field source_code string
---@field command string
---@field test_dir_path string
---@field filetype string
---@field lang_id integer
---@field contest_id? string
---@field problem_id? string

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
    test_case_preview_length = {},
    test_case_display_length = {},
    source_code = '',
    command = '',
    test_dir_path = '',
    origin_dap_adapters = {},
  }
  obj.spin = spinner.new(obj.bufnr)

  obj.open = function(self)
    -- split などをしたときに winid が元のものとは別のものが割りあたっていることがあるため常に buffer 基準で winid を取得しなければならない
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

  obj.reset_test_cases = function(self)
    self.test_case_preview_length = {}
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

    local cnt = 1
    local prev_file = ''
    for _, v in ipairs(lines) do
      local match_str = string.match(v, 'sample%-%d+$') or string.match(v, 'custom%-%d+$')
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
      'contest_id: ' .. (test_result.contest_id or ''),
      'problem_id: ' .. (test_result.problem_id or ''),
      'test_dir: ' .. test_result.test_dir_path,
      'source_code: ' .. test_result.source_code,
      'command: ' .. test_result.command,
      '',
      'help',
      '  r:    rerun test cases',
      '  d:    debug test case',
      '  <CR>: view/hide test case',
      '  a:    add test case',
      '  e:    edit test case',
      '  D:    delete test case',
      '  s:    submit',
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
      source_code = self.source_code,
      command = self.command,
      test_dir_path = self.test_dir_path,
      contest_id = self.contest_id,
      problem_id = self.problem_id,
      filetype = self.filetype,
      lang_id = self.lang_id,
    }
  end

  function obj.start_spinner(self)
    self.spin:start()
  end
  function obj.stop_spinner(self)
    self.spin:stop()
  end

  function obj._test_file_path(self)
    local test_dir_path = self.test_dir_path
    local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w+%-%d+') or ''
    test_case = string.match(test_case, '%w+%-%d+') or ''
    local file_path_prefix = test_dir_path .. '/' .. test_case

    return {
      input = file_path_prefix .. '.in',
      output = file_path_prefix .. '.out',
    }
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

    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. input_file_path)
    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. output_file_path)
    vim.cmd('wincmd k')
  end, {
    buffer = obj.bufnr,
  })

  -- add test case
  vim.keymap.set({ 'n' }, 'a', function()
    local cnt = utils.count_custom_prefix_files(obj.test_dir_path, '^custom%-')
    cnt = cnt / 2
    cnt = cnt + 1
    local input_file_path = string.format('%s/custom-%d.in', obj.test_dir_path, cnt)
    local output_file_path = string.format('%s/custom-%d.out', obj.test_dir_path, cnt)
    vim.cmd('split')
    vim.cmd('wincmd j')
    vim.cmd('split')
    vim.cmd('edit ' .. input_file_path)
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. output_file_path)
    vim.cmd('wincmd k')

    local input_bufnr = vim.fn.bufnr(input_file_path)
    local output_bufnr = vim.fn.bufnr(output_file_path)
    local ns_id = vim.api.nvim_create_namespace('atcoder_nvim_namespace')

    local bufs = {
      { msg = 'input file', bufnr = input_bufnr },
      { msg = 'output file', bufnr = output_bufnr },
    }
    for _, v in ipairs(bufs) do
      vim.api.nvim_buf_set_extmark(v.bufnr, ns_id, 0, 0, {
        virt_text = { { v.msg, 'Comment' } },
        virt_text_pos = 'eol', -- 行末に表示
      })
      vim.api.nvim_create_autocmd({ 'InsertEnter' }, {
        buffer = v.bufnr,
        callback = function()
          vim.api.nvim_buf_clear_namespace(v.bufnr, ns_id, 0, -1)
        end,
      })
    end
  end, {
    buffer = obj.bufnr,
  })

  -- delete test case
  vim.keymap.set({ 'n' }, 'D', function()
    local test_dir_path = obj.test_dir_path
    local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w+%-%d+') or ''
    test_case = string.match(test_case, '%w+%-%d+') or ''
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 then
      -- do nothing if file does not exist.
      return
    end
    for _, v in ipairs({ input_file_path, output_file_path }) do
      if vim.api.nvim_buf_is_loaded(vim.fn.bufnr(v)) then
        vim.cmd('bd ' .. v)
      end
    end
    if string.match(test_case, '^sample%-') then
      vim.notify('could not delete sample test case', vim.log.levels.WARN)
      return
    end
    local remove = vim.fn.input('remove test case [y/N]')
    local yes = { yes = true, y = true }
    if yes[string.lower(remove)] then
      vim.system({
        'rm',
        '-f',
        input_file_path,
        output_file_path,
      }, {}, function(out)
        if out.code ~= 0 then
          vim.notify(out.stderr, vim.log.levels.ERROR)
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

  -- debug using test case under cursor
  -- vim.keymap.set({ 'n' }, 'D', function()
  --   local adapter_name = 'cppdbg'
  --
  --   local dap = require('dap')
  --   if not obj.origin_dap_adapters[adapter_name] then
  --     obj.origin_dap_adapters[adapter_name] = dap.adapters[adapter_name]
  --   end
  --
  --   local origin_adapter = obj.origin_dap_adapters[adapter_name]
  --   if origin_adapter == nil then
  --     vim.notify('you must configure dap-adapter for cpp', vim.log.levels.ERROR)
  --     return
  --   end
  --
  --   local test_dir_path = obj.test_dir_path
  --   local test_case = string.match(vim.api.nvim_get_current_line(), '[▷▽] %w+%-%d+') or ''
  --   test_case = string.match(test_case, '%w+%-%d+') or ''
  --   local file_path_prefix = test_dir_path .. '/' .. test_case
  --   local input_file_path = file_path_prefix .. '.in'
  --
  --   if type(origin_adapter) == 'function' then
  --     dap.adapters[adapter_name] = function(callback, config, parent)
  --       local final_config = vim.deepcopy(config)
  --       final_config.args = final_config.args or {}
  --       vim.list_extend(final_config.args, '< ' .. input_file_path)
  --       origin_adapter(callback, final_config, parent)
  --     end
  --   elseif type(origin_adapter) == 'table' then
  --     local prev_enrich_config = origin_adapter.enrich_config
  --     local adapter = vim.deepcopy(origin_adapter)
  --     adapter.enrich_config = function(config, on_config)
  --       local final_config = vim.deepcopy(config)
  --       final_config.args = final_config.args or {}
  --       vim.list_extend(final_config.args, { '<', input_file_path })
  --       vim.print(vim.inspect(final_config))
  --       prev_enrich_config(final_config, on_config)
  --     end
  --     dap.adapters[adapter_name] = adapter
  --   else
  --     vim.notify('invalid type adapter is registered', vim.log.levels.ERROR)
  --     return
  --   end
  --
  --   local winid = utils.get_window_id_for_file(obj.source_code)
  --   vim.api.nvim_set_current_win(winid)
  --   dap.continue()
  -- end, {
  --   buffer = obj.bufnr,
  -- })

  -- debug test case under cursor
  vim.keymap.set({ 'n' }, 'd', function()
    local ok, dap = pcall(require, 'dap')
    if not ok then
      vim.notify('nvim-dap is required', vim.log.levels.ERROR)
      return
    end

    -- window 移動する前に実行しなければならない
    local test_file_path = obj:_test_file_path()

    local winid = utils.get_window_id_for_file(obj.source_code)
    vim.api.nvim_set_current_win(winid)

    local dap_config = lang.get_option(obj.filetype).dap_config({
      source_code_path = obj.source_code,
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

return M
