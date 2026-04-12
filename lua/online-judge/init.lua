local aoj = require('online-judge.service.aoj')
local atcoder = require('online-judge.service.atcoder')

local config = require('online-judge.config')
local debug_flow = require('online-judge.debug_flow')
local lang = require('online-judge.language')
local result_viewer = require('online-judge.result_viewer')
local source_context = require('online-judge.source_context')
local submission_flow = require('online-judge.submission_flow')
local test_flow = require('online-judge.test_flow')
local utils = require('online-judge.utils')
local io = require('online-judge.io')

local debug = require('online-judge.debug')
local async = require('plenary.async')

local M = {}

local nopfn = function(_) end

local function force_download_tests(url, test_dirname, callback)
  local svc = require('online-judge.service.common').create_service(url)
  local cmd = svc.download_tests_cmd(url, test_dirname)
  async.void(function()
    local out = utils.async_system(cmd)
    callback(out)
  end)()
end

---@class State
---@field test_result_viewer table
local state = {}

---@param url string
---@param test_dirname string
---@param callback fun(opts:vim.SystemCompleted)
local function _download_tests(url, test_dirname, callback)
  callback = callback or nopfn

  if io.isdirectory(test_dirname) then
    utils.notify('test files are already downloaded')
    callback({
      code = 0,
      stdout = 'test files are already downloaded',
      stderr = '',
      signal = 0,
    })
    return
  end

  if url == '' then
    utils.notify('url is not written', vim.log.levels.ERROR)
    callback({
      code = 1,
      stdout = '',
      stderr = 'url is not written',
      signal = 0,
    })
    return
  end

  force_download_tests(url, test_dirname, callback)
end

---@param callback fun(opts:vim.SystemCompleted)
local function download_tests(callback)
  local context = source_context.current(state.test_result_viewer)
  _download_tests(context.url, context.test_dir_path, callback)
end

local function test()
  local context = source_context.current(state.test_result_viewer)
  test_flow.run(context, state.test_result_viewer, nopfn)
end

---@class SubmitInfo
---@field filetype string
---@field file_path string
---@field url string

---@return SubmitInfo|nil
local function prepare_submit_info()
  local context = source_context.current(state.test_result_viewer)
  if context.url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    return nil
  end

  return {
    filetype = context.filetype,
    file_path = context.file_path,
    url = context.url,
  }
end

M._prepare_submit_info = prepare_submit_info

---@param opts SubmitInfo
local function _submit(opts)
  submission_flow.submit({
    url = opts.url,
    file_path = opts.file_path,
    filetype = opts.filetype,
    test_dir_path = utils.get_test_dirname(opts.file_path),
  }, state.test_result_viewer)
end

M._submit = _submit

local function submit()
  local info = prepare_submit_info()
  if info == nil then
    return
  end
  _submit(info)
end

---@param opts SubmitInfo
local function _submit_with_test(opts)
  local callback = function()
    vim.defer_fn(function()
      submission_flow.submit({
        url = opts.url,
        file_path = opts.file_path,
        filetype = opts.filetype,
        test_dir_path = utils.get_test_dirname(opts.file_path),
      }, state.test_result_viewer, { update_viewer_on_error = true })
    end, 200)
  end

  local context = source_context.current(state.test_result_viewer)
  test_flow.run(context, state.test_result_viewer, callback)
end

local function submit_with_test()
  local info = prepare_submit_info()
  if info == nil then
    return
  end
  _submit_with_test(info)
end

local function debug_case()
  local context = source_context.current(state.test_result_viewer)
  debug_flow.start(context, state.test_result_viewer:get_state())
end

local function setup_cmds()
  local fns = {
    aoj_login = aoj.login,
    atcoder_login = atcoder.login,
    test = test,
    submit = submit,
    submit_with_test = submit_with_test,
    download_tests = function()
      download_tests(function(out)
        if out.code == 0 then
          utils.notify('tests downloaded successfully')
        else
          utils.notify('failed to download tests', vim.log.levels.ERROR)
          utils.notify(out.stdout, vim.log.levels.ERROR)
        end
      end)
    end,
    enable_exact_match = function()
      config.enable_exact_match()
      utils.notify('exact match enabled')
    end,
    disable_exact_match = function()
      config.disable_exact_match()
      utils.notify('exact match disabled')
    end,
    set_precision = function(opts)
      if opts.fargs[1] == 'set_precision' and opts.fargs[2] then
        config.set_precision(opts.fargs[2])
        print('Precision set to ' .. opts.fargs[2])
      else
        print('Usage: OnlineJudge set_precision <value>')
      end
    end,
  }

  vim.api.nvim_create_user_command('OnlineJudge', function(opts)
    fns[opts.fargs[1]](opts)
  end, {
    ---@diagnostic disable-next-line
    complete = function(arg_lead, cmd_line, cursor_pos)
      return {
        'aoj_login',
        'atcoder_login',
        'test',
        'submit',
        'submit_with_test',
        'download_tests',
        'enable_exact_match',
        'disable_exact_match',
        'set_precision',
      }
    end,
    nargs = '+',
  })
end

function M.setup(opts)
  config.setup(opts)

  local cfg = config.get()

  lang.setup(cfg.lang)
  debug.setup()

  vim.fn.mkdir(cfg.out_dirpath, 'p')
  vim.fn.mkdir(cfg.cache_dir, 'p')

  state.test_result_viewer = result_viewer.new()
  state.test_result_viewer:register_rerun_fn(test)
  state.test_result_viewer:register_submit_fn(submit)
  state.test_result_viewer:register_debug_fn(debug_case)
  if cfg.define_cmds then
    setup_cmds()
  end
end

M._download_tests = _download_tests
M.download_tests = download_tests
M.test = test
M.submit = submit
M.debug_case = debug_case
M.atcoder_login = atcoder.login
M.aoj_login = aoj.login
M.submit_with_test = submit_with_test
M.open = function()
  state.test_result_viewer:open()
end
M.close = function()
  state.test_result_viewer:close()
end
M.toggle = function()
  state.test_result_viewer:toggle()
end

function M.create_test_dir()
  local dirname = utils.get_test_dirname(vim.fn.expand('%:p'))
  vim.fn.mkdir(dirname, 'p')
  local test_prefix = vim.fs.joinpath(dirname, 'custom-1.')
  vim.system({ 'touch', test_prefix .. 'in' })
  vim.system({ 'touch', test_prefix .. 'out' })
end

return M
