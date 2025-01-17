local aoj = require('online-judge.service.aoj')
local atcoder = require('online-judge.service.atcoder')
local config = require('online-judge.config')
local lang = require('online-judge.language')
local test_result = require('online-judge.test_result')
local utils = require('online-judge.utils')

local debug = require('online-judge.debug')
local async = require('plenary.async')
local oj = config.oj

local M = {}

local nopfn = function(_) end

---@class State
---@field test_result_viewer TestResultViewer
local state = {}

---@param url string
---@param test_dirname string
---@param callback fun(opts:vim.SystemCompleted)
local function _download_tests(url, test_dirname, callback)
  if vim.fn.isdirectory(test_dirname) == 1 then
    utils.notify('test files are already downloaded')
    if type(callback) == 'function' then
      callback({
        code = 0,
        stdout = 'test files are already downloaded',
        stderr = '',
        signal = 0,
      })
    end
    return
  end

  if url == '' then
    utils.notify(url .. ' is not written', vim.log.levels.ERROR)
    return
  end
  local cmd = {
    oj(),
    'download',
    url,
    '--directory',
    test_dirname,
  }
  async.void(function()
    local out = utils.async_system(cmd)
    callback = callback or nopfn
    callback(out)
  end)()
end

---@param callback fun(opts:vim.SystemCompleted)
local function download_tests(callback)
  local file_path = utils.get_absolute_path()
  local url = utils.get_problem_url(file_path)
  local test_dirname = utils.get_test_dirname(file_path)
  _download_tests(url, test_dirname, function(opts)
    callback = callback or nopfn
    opts = opts or {}
    callback(opts)
  end)
end

---@class TestCompleted : vim.SystemCompleted
---@field result string[] result of oj test result

---@param test_dirname string
---@param command string
---@param callback fun(opts:TestCompleted)
local function execute_test(test_dirname, command, callback)
  callback = callback or nopfn

  async.void(function()
    state.test_result_viewer:reset_test_cases()

    local cmd = {
      oj(),
      'test',
      '--error',
      '1e-6',
      '--tle',
      config.tle(),
      '--directory',
      test_dirname,
      '-c',
      command,
    }
    if vim.fn.executable('time') == 1 then -- `sudo apt-get install time`
      vim.list_extend(cmd, { '--mle', config.mle() })
    end

    local out = utils.async_system(cmd)
    vim.schedule(function()
      out = vim.tbl_deep_extend('force', out, {
        result = vim.split(out.stdout, '\n'),
      })
      callback(out)
    end)
  end)()
end

-- execute callback if pass the tests
---@param callback fun(TestCompleted)
local function build_download_test(file_path, callback)
  callback = callback or nopfn

  local filetype = utils.get_filetype(file_path)

  local lang_opt = lang.get_option(filetype)
  local build_fn = lang_opt.build
  assert(build_fn, 'build_fn is nil')
  local command = lang_opt.command({ file_path = file_path })

  local url = utils.get_problem_url(file_path)
  if url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    return
  end
  local test_dir_path = utils.get_test_dirname(file_path)

  state.test_result_viewer:open()
  state.test_result_viewer:start_spinner()
  build_fn({ file_path = file_path }, function(post_build)
    vim.schedule(function()
      async.void(function()
        local download_tests_async = async.wrap(_download_tests, 3)
        local _execute_test_async = async.wrap(execute_test, 3)

        local download_res = download_tests_async(url, test_dir_path)
        if download_res.code ~= 0 then
          state.test_result_viewer:stop_spinner()
          utils.notify('failed to download tests', vim.log.levels.ERROR)
          return
        end

        local test_res = _execute_test_async(test_dir_path, command)

        state.test_result_viewer:stop_spinner()
        state.test_result_viewer:update({
          file_path = file_path,
          command = command,
          test_dir_path = test_dir_path,
          result = test_res.result,
        })

        callback(test_res)
      end)()
    end)
  end)
end

local function test()
  local file_path = utils.get_absolute_path()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    file_path = state.test_result_viewer:get_state().file_path
  end
  build_download_test(file_path, nopfn)
end

---@class SubmitInfo
---@field aoj_lang_id string
---@field atcoder_lang_id integer
---@field file_path string
---@field url string

---@return SubmitInfo|nil
local function prepare_submit_info()
  local file_path = utils.get_absolute_path()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    local viewer_state = state.test_result_viewer:get_state()
    file_path = viewer_state.file_path
  end

  local url = utils.get_problem_url(file_path)
  if url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    return nil
  end

  local filetype = utils.get_filetype(file_path)
  local lang_opt = lang.get_option(filetype)
  local atcoder_lang_id = lang_opt.atcoder_lang_id
  local aoj_lang_id = lang_opt.aoj_lang_id

  return {
    aoj_lang_id = aoj_lang_id,
    atcoder_lang_id = atcoder_lang_id,
    file_path = file_path,
    url = url,
  }
end

---@param opts SubmitInfo
local function _submit(opts)
  local url = opts.url
  local file_path = opts.file_path
  local lang_id = opts.atcoder_lang_id
  local aoj_lang_id = opts.aoj_lang_id

  if os.getenv('ONLINE_JUDGE_FORCE_SUBMISSION') ~= '1' then
    local confirm = vim.fn.input('submit [y/N]: ')
    confirm = string.lower(confirm)
    if not ({ yes = true, y = true })[confirm] then
      return
    end
  end

  if url:match('https://atcoder.jp') then
    atcoder.submit(url, file_path, lang_id)
  elseif url:match('https://onlinejudge.u%-aizu.ac.jp') then
    aoj.submit(url, file_path, aoj_lang_id)
  else
    utils.notify('Unsupported url: ' .. (url or 'nil'), vim.log.levels.ERROR)
  end
end

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
      _submit(opts)
    end, 200)
  end

  local file_path = utils.get_absolute_path()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    file_path = state.test_result_viewer:get_state().file_path
  end
  build_download_test(file_path, callback)
end

local function submit_with_test()
  local info = prepare_submit_info()
  if info == nil then
    return
  end
  _submit_with_test(info)
end

local function setup_cmds()
  local fns = {
    aoj_login = aoj.login,
    atcoder_login = atcoder.login,
    test = test,
    submit = submit,
    submit_with_test = submit_with_test,
    download_tests = function()
      download_tests(nopfn)
    end,
  }

  vim.api.nvim_create_user_command('OnlineJudge', function(opts)
    fns[opts.args]()
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
      }
    end,
    nargs = 1,
  })
end

function M.setup(opts)
  config.setup(opts)

  local cfg = config.get()

  lang.setup(cfg.lang)
  debug.setup()

  vim.fn.mkdir(cfg.out_dirpath, 'p')
  vim.fn.mkdir(cfg.cache_dir, 'p')

  state.test_result_viewer = test_result.new()
  state.test_result_viewer:register_rerun_fn(test)
  state.test_result_viewer:register_submit_fn(submit_with_test)
  if cfg.define_cmds then
    setup_cmds()
  end
end

M._download_tests = _download_tests
M.download_tests = download_tests
M.test = test
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

function M.insert_problem_url()
  local contest_id = utils.get_dirname()
  local problem_id = contest_id .. '_' .. utils.get_filename_without_ext()
  local url = string.format('https://atcoder.jp/contests/%s/tasks/%s', contest_id, problem_id)
  local url_line = string.format(vim.o.commentstring, url)
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { url_line })
end

function M.create_test_dir()
  local dirname = utils.get_test_dirname(vim.fn.expand('%:p'))
  vim.fn.mkdir(dirname, 'p')
  local test_prefix = vim.fs.joinpath(dirname, 'custom-1.')
  vim.system({ 'touch', test_prefix .. 'in' })
  vim.system({ 'touch', test_prefix .. 'out' })
end

return M
