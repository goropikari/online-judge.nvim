local case_service = require('online-judge.test_case_service')
local controller = require('online-judge.result_viewer.controller')
local filetype = require('online-judge.result_viewer.filetype')
local renderer = require('online-judge.result_viewer.renderer')
local store_factory = require('online-judge.result_viewer.store')
local utils = require('online-judge.utils')

local M = {}

local default_state = {
  phase = 'idle',
  file_path = '',
  command = '',
  test_dir_path = '',
  raw_lines = {},
  error_lines = {},
  parsed = nil,
  executed_at = '',
  source_winid = -1,
  selected_case = nil,
  expanded_cases = {},
  keymaps = {},
}

local function open_window(bufnr)
  local winid = utils.get_window_id(bufnr)
  if vim.api.nvim_win_is_valid(winid) then
    return winid
  end

  return vim.api.nvim_open_win(bufnr, false, {
    split = 'right',
    width = math.floor(vim.o.columns * 0.4),
    style = 'minimal',
  })
end

function M.new(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('filetype', filetype.buf_filetype, { buf = bufnr })

  local store = store_factory.new(default_state)
  local obj = {
    bufnr = bufnr,
    store = store,
    line_map = {},
    rerun_fn = nil,
    submit_fn = nil,
    debug_fn = nil,
  }
  local redraw_pending = false

  local function current_case_name()
    local winid = utils.get_window_id(bufnr)
    if not vim.api.nvim_win_is_valid(winid) then
      return store:get_state().selected_case
    end

    local row = vim.api.nvim_win_get_cursor(winid)[1]
    local meta = obj.line_map[row]
    if meta and meta.case_name then
      return meta.case_name
    end

    for scan = row - 1, 1, -1 do
      local previous = obj.line_map[scan]
      if previous and previous.case_name then
        return previous.case_name
      end
    end

    return store:get_state().selected_case
  end

  local function current_row()
    local winid = utils.get_window_id(bufnr)
    if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
      return vim.api.nvim_win_get_cursor(winid)[1]
    end
    return nil
  end

  local function redraw(state, opts)
    opts = opts or {}
    local lines, line_map = renderer.render(state)
    obj.line_map = line_map
    vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    local winid = nil
    if opts.auto_open ~= false then
      winid = open_window(bufnr)
    else
      winid = utils.get_window_id(bufnr)
    end

    local target_row = opts.cursor_row
    if target_row and winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
      local max_row = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(winid, { math.min(target_row, max_row), 0 })
    end
  end

  local function request_redraw(state, opts)
    opts = opts or {}
    if redraw_pending and not opts.force then
      return
    end

    state = state or store:get_state()
    local ok = pcall(redraw, state, opts)
    if ok then
      return
    end

    redraw_pending = true
    vim.schedule(function()
      redraw_pending = false
      redraw(store:get_state(), opts)
    end)
  end

  store:subscribe(function(state)
    request_redraw(state, { cursor_row = current_row() })
  end)

  local normalized_keymaps = controller.attach(bufnr, opts.keymaps, {
    rerun = function()
      if obj.rerun_fn then
        obj.rerun_fn()
      end
    end,
    submit = function()
      if obj.submit_fn then
        obj.submit_fn()
      end
    end,
    preview = function()
      obj:toggle_preview()
    end,
    add_case = function()
      case_service.add(obj:get_state().test_dir_path)
    end,
    edit_case = function()
      obj:edit_case()
    end,
    copy_case = function()
      obj:copy_case()
    end,
    delete_case = function()
      obj:delete_case()
    end,
    debug_case = function()
      if obj.debug_fn then
        obj.debug_fn()
      end
    end,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    callback = function()
      local case_name = current_case_name()
      if case_name and store:get_state().selected_case ~= case_name then
        store:patch_state({ selected_case = case_name })
      end
    end,
  })

  function obj:open()
    open_window(bufnr)
  end

  function obj:close()
    local winid = utils.get_window_id(bufnr)
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, false)
    end
  end

  function obj:toggle()
    local winid = utils.get_window_id(bufnr)
    if vim.api.nvim_win_is_valid(winid) then
      self:close()
    else
      self:open()
    end
  end

  function obj:get_state()
    return self.store:get_state()
  end

  function obj:register_rerun_fn(fn)
    self.rerun_fn = fn
  end

  function obj:register_submit_fn(fn)
    self.submit_fn = fn
  end

  function obj:register_debug_fn(fn)
    self.debug_fn = fn
  end

  function obj:start_phase(phase, patch)
    self.store:patch_state(vim.tbl_deep_extend('force', {
      phase = phase,
    }, patch or {}))
  end

  function obj:start_spinner()
    self:start_phase('testing')
  end

  function obj:stop_spinner()
    self.store:patch_state({ phase = 'idle' })
  end

  function obj:reset_test_cases() end

  function obj:toggle_preview()
    local state = self.store:get_state()
    local case_name = current_case_name()
    if case_name == nil or state.test_dir_path == '' or state.parsed == nil then
      return
    end

    local expanded_cases = vim.deepcopy(state.expanded_cases or {})
    if expanded_cases[case_name] then
      expanded_cases[case_name] = nil
    else
      expanded_cases[case_name] = true
    end

    local parsed = vim.deepcopy(state.parsed)
    for _, case_result in ipairs(parsed.cases or {}) do
      if case_result.name == case_name then
        case_result.preview = expanded_cases[case_name] and case_service.preview(state.test_dir_path, case_name, 20) or nil
      end
    end

    local next_state = vim.deepcopy(state)
    next_state.parsed = parsed
    next_state.expanded_cases = expanded_cases
    next_state.selected_case = case_name
    self.store:set_state(next_state, { silent = true })
    request_redraw(next_state, { force = true, cursor_row = current_row() })
  end

  function obj:edit_case()
    local state = self.store:get_state()
    local case_name = current_case_name()
    if case_name == nil then
      return
    end

    local ok, msg = case_service.edit(state.test_dir_path, case_name)
    if not ok and msg and msg ~= 'test case files are missing' then
      utils.notify(msg, vim.log.levels.WARN)
    end
  end

  function obj:copy_case()
    local state = self.store:get_state()
    local case_name = current_case_name()
    if case_name == nil then
      return
    end

    local ok, res = case_service.copy(state.test_dir_path, case_name)
    if not ok and type(res) == 'string' then
      utils.notify(res, vim.log.levels.WARN)
    end
  end

  function obj:delete_case()
    local state = self.store:get_state()
    local case_name = current_case_name()
    if case_name == nil then
      return
    end

    local ok, msg = case_service.delete(state.test_dir_path, case_name)
    if not ok then
      if msg and msg ~= 'cancelled' and msg ~= 'test case files are missing' then
        utils.notify(msg, vim.log.levels.WARN)
      end
      return
    end

    local parsed = vim.deepcopy(state.parsed or { cases = {}, summary = {}, raw_lines = {} })
    parsed.cases = vim.tbl_filter(function(case_result)
      return case_result.name ~= case_name
    end, parsed.cases or {})

    local expanded_cases = vim.deepcopy(state.expanded_cases or {})
    expanded_cases[case_name] = nil

    local next_state = vim.deepcopy(state)
    next_state.parsed = parsed
    next_state.expanded_cases = expanded_cases
    next_state.selected_case = nil
    self.store:set_state(next_state, { silent = true })
    request_redraw(next_state, { force = true, cursor_row = current_row() })
  end

  function obj:update(test_result, callback)
    self.store:batch(function(s)
      s:patch_state({
        phase = 'idle',
        file_path = test_result.file_path,
        command = test_result.command,
        test_dir_path = test_result.test_dir_path,
        raw_lines = vim.deepcopy(test_result.result or test_result.raw_lines or {}),
        error_lines = vim.deepcopy(test_result.error_lines or {}),
        parsed = test_result.parsed,
        executed_at = vim.fn.strftime('%c'),
        source_winid = utils.get_window_id_for_file(test_result.file_path or ''),
        expanded_cases = {},
        selected_case = nil,
      }, { silent = true })
    end)

    if type(callback) == 'function' then
      callback()
    end
  end

  obj.store:set_state(
    vim.tbl_deep_extend('force', default_state, {
      keymaps = normalized_keymaps,
    }),
    { silent = true }
  )
  vim.schedule(function()
    redraw(obj.store:get_state())
  end)

  return obj
end

return M
