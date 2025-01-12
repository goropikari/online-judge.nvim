local auth = require('atcoder.auth')
local config = require('atcoder.config')
local lang = require('atcoder.language')
local test_result = require('atcoder.test_result')
local utils = require('atcoder.utils')

local debug = require('atcoder.debug')
local async = require('plenary.async')
local system = async.wrap(function(cmd, callback)
  vim.system(cmd, { text = true }, callback)
end, 2)
local oj = config.oj

local M = {}

local nopfn = function(_) end

---@class State
---@field test_result_viewer TestResultViewer
local state = {}

---@return string
local function get_test_dirname()
  return vim.fs.joinpath(vim.fn.expand('%:p:h'), '/test_' .. utils.get_filename_without_ext())
end

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
    local out = system(cmd)
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
  local test_dirname = get_test_dirname()
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
    local out = system(cmd)
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
---@param callback fun(opts:{file_path:string, test_dirname:string, filetype:string, lang_id:integer, contest_id:string, problem:string, code:integer,test_dir_path:string,file_path:string,command:string,result:string[],stderr:string})
local function execute_test(callback)
  callback = callback or nopfn
  local lang_opt = lang.get_option()
  local build_fn = lang_opt.build
  assert(build_fn, 'build_fn is nil')
  local cmd_fn = lang_opt.command
  local lang_id = lang_opt.id

  local url = utils.get_problem_url()
  if url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    return
  end

  local file_path = utils.get_absolute_path()
  local test_dirname = get_test_dirname()

  local ctx = {
    file_path = file_path,
    test_dirname = test_dirname,
    filetype = vim.bo.filetype,
    lang_id = lang_id,
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
  local url = utils.get_problem_url()
  local filetype = cfg.filetype
  local test_dirname = cfg.test_dir_path
  local file_path = cfg.file_path
  local command = cfg.command

  local lang_opt = lang.get_option(filetype)
  local build_fn = lang_opt.build
  assert(build_fn, 'build_fn is nil')
  local lang_id = lang_opt.id

  local ctx = {
    file_path = file_path,
    test_dirname = test_dirname,
    filetype = filetype,
    lang_id = lang_id,
  }

  test_sequence(ctx, build_fn, url, test_dirname, command, file_path, callback)
end

local function test()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
    rerun_for_test_result_viewer(nopfn)
    return
  end
  execute_test(nopfn)
end

---@return {url:string,file_path:string,lang_id:integer}|nil
local function prepare_submit_info()
  local url = ''
  local file_path = ''
  local lang_id = 0
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
    local viewer_state = state.test_result_viewer:get_state()
    url = viewer_state.url
    file_path = viewer_state.file_path
    lang_id = viewer_state.lang_id
  else
    url = utils.get_problem_url()
    if url == '' then
      utils.notify('problem url is required', vim.log.levels.ERROR)
      return nil
    end
    file_path = utils.get_absolute_path()
    lang_id = lang.get_option(vim.bo.filetype).id
  end

  return {
    url = url,
    file_path = file_path,
    lang_id = lang_id,
  }
end

---@param opts {url:string,file_path:string,lang_id:integer,aoj_lang_id:string}
local function _submit(opts)
  local url = opts.url
  local file_path = opts.file_path
  local lang_id = opts.lang_id
  if os.getenv('ATCODER_FORCE_SUBMISSION') ~= '1' then
    local confirm = vim.fn.input('submit [y/N]: ')
    confirm = string.lower(confirm)
    if not ({ yes = true, y = true })[confirm] then
      return
    end
  end

  async.void(function()
    utils.notify('submit: ' .. url)
    local out = system({
      oj(),
      'submit',
      '-y',
      '-l',
      lang_id,
      '-w',
      '0',
      url,
      file_path,
    })
    if out.code ~= 0 then
      utils.notify(out.stdout, vim.log.levels.ERROR)
      utils.notify(out.stderr, vim.log.levels.ERROR)
    end

    vim.schedule(function()
      local result = vim.fn.split(out.stdout, '\n')
      for _, line in ipairs(result) do
        local submission_url = line:match('%[SUCCESS%]%sresult:%s([%p%w]+)')
        if submission_url then
          utils.notify(submission_url)
        end
      end
    end)
  end)()
end

local function submit()
  local info = prepare_submit_info()
  if info == nil then
    return
  end
  _submit({
    url = info.url,
    file_path = info.file_path,
    lang_id = info.lang_id,
  })
end

---@param url string
---@param file_path string
---@param lang_id integer
local function _submit_with_test(url, file_path, lang_id)
  local callback = function()
    _submit({
      url = url,
      file_path = file_path,
      lang_id = lang_id,
    })
  end

  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
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
  _submit_with_test(info.url, info.file_path, info.lang_id)
end

local function setup_cmds()
  local fns = {
    test = test,
    submit = submit,
    submit_with_test = submit_with_test,
    download_tests = function()
      download_tests(nopfn)
    end,
    login = auth.login,
  }

  vim.api.nvim_create_user_command('AtCoder', function(opts)
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
M.login = auth.login
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
  local dirname = get_test_dirname()
  vim.fn.mkdir(dirname, 'p')
  local test_prefix = vim.fs.joinpath(dirname, 'custom-1.')
  vim.system({ 'touch', test_prefix .. 'in' })
  vim.system({ 'touch', test_prefix .. 'out' })
end

return M
