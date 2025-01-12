local atcoder = require('online-judge.service.atcoder')
local aoj = require('online-judge.service.aoj')
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
---@param callback fun(cfg:{test_dirname:string})
local function _download_tests(url, test_dirname, callback)
  if vim.fn.isdirectory(test_dirname) == 1 then
    utils.notify('test files are already downloaded')
    if type(callback) == 'function' then
      callback({
        test_dirname = test_dirname,
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
    'd',
    url,
    '--directory',
    test_dirname,
  }
  async.void(function()
    local out = utils.async_system(cmd)
    if out.code ~= 0 then
      -- oj の log は stdout に出る
      utils.notify(out.stdout, vim.log.levels.ERROR)
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end
    utils.notify('Download tests of ' .. url)

    if type(callback) == 'function' then
      callback({
        test_dirname = test_dirname,
      })
    end
  end)()
end

---@param callback fun(cfg:{test_dirname:string})
local function download_tests(callback)
  local url = utils.get_problem_url()
  local test_dirname = utils.get_test_dirname(vim.fn.expand('%:p'))
  _download_tests(url, test_dirname, function(opts)
    callback = callback or nopfn
    opts = opts or {}
    callback(opts)
  end)
end

---@param test_dirname string
---@param file_path string
---@param command string
---@param callback fun(opts:{code:integer, test_dir_path:string, file_path:string, command:string, result:string[], stderr:string})
local function _execute_test(test_dirname, file_path, command, callback)
  state.test_result_viewer:reset_test_cases()
  async.void(function()
    local cmd = {
      oj(),
      't',
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
    -- vim.print(cmd)
    local out = utils.async_system(cmd)
    vim.schedule(function()
      callback = callback or nopfn
      callback({
        code = out.code,
        test_dir_path = test_dirname,
        file_path = file_path,
        command = command,
        result = vim.split(out.stdout, '\n'),
        stderr = out.stderr,
      })
    end)
  end)()
end

---@class TestContext: BuildConfig
---@field test_dirname string
---@field command string

---@param ctx TestContext
---@param build_fn fun(cfg:BuildConfig, callback:function)
---@param url string
---@param test_dirname string
---@param command string
---@param file_path string
---@param callback function
local function test_sequence(ctx, build_fn, url, test_dirname, command, file_path, callback)
  state.test_result_viewer:start_spinner()
  build_fn(ctx, function(post_build)
    ctx = vim.tbl_deep_extend('force', ctx, post_build or {})
    vim.schedule(function()
      async.void(function()
        local download_tests_async = async.wrap(_download_tests, 3)
        local _execute_test_async = async.wrap(_execute_test, 4)

        local download_res = download_tests_async(url, test_dirname)
        ctx = vim.tbl_deep_extend('force', ctx, download_res or {})

        ---@type {code:integer,test_dir_path:string,file_path:string,command:string,result:string[],stderr:string}
        local test_res = _execute_test_async(test_dirname, file_path, command)
        ctx = vim.tbl_deep_extend('force', ctx, test_res or {})

        state.test_result_viewer:stop_spinner()

        ctx = vim.tbl_deep_extend('force', ctx, test_res)
        state.test_result_viewer:update(ctx)

        if test_res.code == 0 then
          callback(ctx)
        end
      end)()
    end)
  end)
end

-- execute callback if pass the tests
---@param callback fun(opts:{file_path:string, test_dirname:string, filetype:string, code:integer, test_dir_path:string, file_path:string,command:string,result:string[],stderr:string})
local function execute_test(callback)
  callback = callback or nopfn
  local lang_opt = lang.get_option()
  local build_fn = lang_opt.build
  assert(build_fn, 'build_fn is nil')
  local cmd_fn = lang_opt.command

  local url = utils.get_problem_url()
  if url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    return
  end

  local file_path = utils.get_absolute_path()
  local test_dirname = utils.get_test_dirname(file_path)

  local ctx = {
    file_path = file_path,
    test_dirname = test_dirname,
    filetype = vim.bo.filetype,
    url = url,
  }
  local command = cmd_fn(ctx)
  ctx.command = command

  state.test_result_viewer:open()
  test_sequence(ctx, build_fn, url, test_dirname, command, file_path, callback)
end

local function rerun_for_test_result_viewer(callback)
  callback = callback or nopfn
  local cfg = state.test_result_viewer:get_state()
  local url = cfg.url
  local file_path = cfg.file_path
  local test_dirname = utils.get_test_dirname(file_path)
  local filetype = utils.get_filetype(file_path)

  local lang_opt = lang.get_option(filetype)
  local build_fn = lang_opt.build
  assert(build_fn, 'build_fn is nil')
  local command = lang_opt.command({ file_path = file_path })

  local ctx = {
    file_path = file_path,
    test_dirname = test_dirname,
    filetype = filetype,
    url = url,
  }

  test_sequence(ctx, build_fn, url, test_dirname, command, file_path, callback)
end

local function test()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    rerun_for_test_result_viewer(nopfn)
    return
  end
  execute_test(nopfn)
end

---@class SubmitInfo
---@field url string
---@field file_path string
---@field lang_id integer
---@field aoj_lang_id string

---@return SubmitInfo|nil
local function prepare_submit_info()
  local url = ''
  local file_path = ''
  local filetype = ''
  local lang_id = 0
  local aoj_lang_id = ''
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    local viewer_state = state.test_result_viewer:get_state()
    url = viewer_state.url
    file_path = viewer_state.file_path
    filetype = utils.get_filetype(file_path)
  else
    url = utils.get_problem_url()
    if url == '' then
      utils.notify('problem url is required', vim.log.levels.ERROR)
      return nil
    end
    file_path = utils.get_absolute_path()
    filetype = vim.bo.filetype
  end
  local lang_opt = lang.get_option(filetype)
  lang_id = lang_opt.id
  aoj_lang_id = lang_opt.aoj_id
  local test_dirname = utils.get_test_dirname(file_path)

  return {
    url = url,
    file_path = file_path,
    lang_id = lang_id,
    aoj_lang_id = aoj_lang_id,
    test_dirname = test_dirname,
    filetype = filetype,
  }
end

---@param opts SubmitInfo
local function _submit(opts)
  local url = opts.url
  local file_path = opts.file_path
  local lang_id = opts.lang_id
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
    _submit(opts)
  end

  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == test_result.buf_filetype then
    rerun_for_test_result_viewer(callback)
  else
    execute_test(callback)
  end
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
    test = test,
    submit = submit,
    submit_with_test = submit_with_test,
    download_tests = function()
      download_tests(nopfn)
    end,
    login = atcoder.login,
  }

  vim.api.nvim_create_user_command('OnlineJudge', function(opts)
    fns[opts.args]()
  end, {
    ---@diagnostic disable-next-line
    complete = function(arg_lead, cmd_line, cursor_pos)
      return {
        'test',
        'submit',
        'submit_with_test',
        'download_tests',
        'login',
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
  state.test_result_viewer:register_rerun_fn(rerun_for_test_result_viewer)
  state.test_result_viewer:register_submit_fn(submit_with_test)
  if cfg.define_cmds then
    setup_cmds()
  end
end

M._download_tests = _download_tests
M.download_tests = download_tests
M.test = test
M.login = atcoder.login
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
