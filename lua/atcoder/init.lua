require('atcoder.cmds')
local auth = require('atcoder.auth')
local config = require('atcoder.config')
local oj = config.oj
local database = require('atcoder.database')
local lang = require('atcoder.language')
local test_result = require('atcoder.test_result')
local utils = require('atcoder.utils')

local debug = require('atcoder.debug')
local async = require('plenary.async')
local system = async.wrap(function(cmd, callback)
  vim.system(cmd, { text = true }, callback)
end, 2)

local M = {}

local nopfn = function(_) end

---@class State
---@field db Database
---@field test_result_viewer TestResultViewer
local state = {}

--- Retrieve the contest_id in the order of the URL written at the beginning of the file, the ATCODER_CONTEST_ID environment variable, and the directory name.
---@return string
local function get_contest_id()
  local id = string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], 'contests/([%w_-]+)/') or os.getenv('ATCODER_CONTEST_ID') or utils.get_dirname() -- base directory name

  -- local found = state.db:exist_contest_id(id)
  -- if not found then
  --   utils.notify('invalid contest_id: ' .. id, vim.log.levels.ERROR)
  --   return ''
  -- end

  return id
end

---@return string|nil
local function get_problem_id(contest_id)
  local problem_id = string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], 'contests/[%w_-]+/tasks/([%w_-]+)')
  if problem_id then
    return problem_id
  end
  local problem_index = utils.get_filename_without_ext()
  problem_index = string.lower(problem_index)

  local id = state.db:get_problem_id(contest_id, problem_index)
  return id
end

---@return string
local function get_test_dirname()
  return vim.fs.joinpath(vim.fn.expand('%:p:h'), '/test_' .. utils.get_filename_without_ext())
end

local function _download_tests(contest_id, problem_id, test_dirname, include_system, callback)
  if vim.fn.isdirectory(test_dirname) == 1 then
    utils.notify('test files are already downloaded')
    if type(callback) == 'function' then
      callback({
        contest_id = contest_id,
        problem_id = problem_id,
        test_dirname = test_dirname,
      })
    end
    return
  end
  contest_id = contest_id or ''
  problem_id = problem_id or ''
  if contest_id == '' or problem_id == '' then
    utils.notify('contest_id or problem_id is empty: contest_id = ' .. contest_id .. ', problem_id = ' .. problem_id, vim.log.levels.ERROR)
    return
  end
  local cmd = {
    oj(),
    'd',
    vim.fn.join({
      'https://atcoder.jp/contests',
      contest_id,
      'tasks',
      problem_id,
    }, '/'),
    '--directory',
    test_dirname,
  }
  if include_system then
    table.insert(cmd, '--system')
  end
  async.void(function()
    local out = system(cmd)
    if out.code ~= 0 then
      -- oj の log は stdout に出る
      utils.notify(out.stdout, vim.log.levels.ERROR)
      return
    end
    utils.notify('Download tests of ' .. problem_id .. ': ' .. test_dirname)

    if type(callback) == 'function' then
      callback({
        contest_id = contest_id,
        problem_id = problem_id,
        test_dirname = test_dirname,
      })
    end
  end)()
end

local function download_tests(include_system, callback)
  local contest_id = get_contest_id()
  local problem_id = get_problem_id(contest_id)
  local test_dirname = get_test_dirname()
  _download_tests(contest_id, problem_id, test_dirname, include_system, function(opts)
    callback = callback or nopfn
    opts = opts or {}
    opts = vim.tbl_deep_extend('force', opts, { contest_id = contest_id, problem_id = problem_id })
    callback(opts)
  end)
end

local function _execute_test(test_dir_path, source_code, command, callback)
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
      test_dir_path,
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
        test_dir_path = test_dir_path,
        source_code = source_code,
        command = command,
        result = vim.split(out.stdout, '\n'),
        stderr = out.stderr,
      })
    end)
  end)()
end

-- execute callback if pass the tests
local function execute_test(callback)
  callback = callback or nopfn
  local lang_opt = lang.get_option()
  local build_fn = lang_opt.build
  local cmd_fn = lang_opt.command
  local lang_id = lang_opt.id

  local source_code = utils.get_absolute_path()
  local test_dirname = get_test_dirname()
  ---@class TestContext: BuildConfig
  ---@field test_dirname string
  ---@field command string
  local ctx = {
    source_code = source_code,
    test_dirname = test_dirname,
    filetype = vim.bo.filetype,
    lang_id = lang_id,
  }
  local command = cmd_fn(ctx)
  ctx.command = command
  state.test_result_viewer:open()
  state.test_result_viewer:start_spinner()
  build_fn(ctx, function(post_build)
    ctx = vim.tbl_deep_extend('force', ctx, post_build or {})
    vim.schedule(function()
      async.void(function()
        local download_tests_async = async.wrap(download_tests, 2)
        local _execute_test_async = async.wrap(_execute_test, 4)

        ---@type {contest_id:string, problm_id:string}
        local download_res = download_tests_async(false)
        ctx = vim.tbl_deep_extend('force', ctx, download_res or {})

        ---@type {code:integer,test_dir_path:string,source_code:string,command:string,result:string[],stderr:string}
        local test_res = _execute_test_async(test_dirname, source_code, command)
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

local function rerun_for_test_result_viewer(callback)
  callback = callback or nopfn
  local cfg = state.test_result_viewer:get_state()
  local contest_id = cfg.contest_id
  local problem_id = cfg.problem_id
  local filetype = cfg.filetype
  local test_dirname = cfg.test_dir_path
  local source_code = cfg.source_code
  local command = cfg.command

  local lang_opt = lang.get_option(filetype)
  local build_fn = lang_opt.build
  local lang_id = lang_opt.id

  local ctx = {
    source_code = source_code,
    test_dirname = test_dirname,
    filetype = filetype,
    lang_id = lang_id,
  }

  state.test_result_viewer:start_spinner()
  build_fn(ctx, function(post_build)
    ctx = vim.tbl_deep_extend('force', ctx, post_build or {})
    vim.schedule(function()
      async.void(function()
        local download_tests_async = async.wrap(_download_tests, 5)
        local _execute_test_async = async.wrap(_execute_test, 4)

        ---@type {contest_id:string, problm_id:string}
        local download_res = download_tests_async(contest_id, problem_id, test_dirname, false)
        ctx = vim.tbl_deep_extend('force', ctx, download_res or {})

        ---@type {code:integer,test_dir_path:string,source_code:string,command:string,result:string[],stderr:string}
        local test_res = _execute_test_async(test_dirname, source_code, command)
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

local function test()
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
    rerun_for_test_result_viewer()
    return
  end
  execute_test()
end

---@return string
local function generate_problem_url(contest_id, problem_id)
  return string.format('https://atcoder.jp/contests/%s/tasks/%s', contest_id, problem_id)
end

---@param contest_id string
---@param problem_id string
---@param source_code string
---@param lang_id integer
local function _submit(contest_id, problem_id, source_code, lang_id)
  local url = generate_problem_url(contest_id, problem_id)
  -- local filepath = utils.get_absolute_path()
  local file_path = source_code

  local callback = function()
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

  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
    rerun_for_test_result_viewer(callback)
  else
    execute_test(callback)
  end
end

local function submit()
  local contest_id = ''
  local problem_id = ''
  local source_code = ''
  local lang_id = 0
  if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }) == 'atcoder' then
    local viewer_state = state.test_result_viewer:get_state()
    contest_id = viewer_state.contest_id
    problem_id = viewer_state.problem_id
    source_code = viewer_state.source_code
    lang_id = viewer_state.lang_id
  else
    contest_id = get_contest_id()
    problem_id = get_problem_id(contest_id) or error('failed to get problem_id')
    source_code = utils.get_absolute_path()
    lang_id = lang.get_option(vim.bo.filetype).id
  end
  _submit(contest_id, problem_id, source_code, lang_id)
end

local function setup_cmds()
  local fns = {
    test = test,
    submit = submit,
    download_tests = function()
      download_tests(false)
    end,
    update_contest_data = function()
      state.db:update_contest_data()
    end,
    login = auth.login,
    open_database = function()
      state.db:open()
    end,
  }

  vim.api.nvim_create_user_command('AtCoder', function(opts)
    fns[opts.args]()
  end, {
    complete = function(arg_lead, cmd_line, cursor_pos)
      return {
        'test',
        'submit',
        'download_test',
        'login',
        'update_contest_data',
        'open_database',
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
  state.db = database.new()

  state.test_result_viewer = test_result.new()
  state.test_result_viewer:register_rerun_fn(rerun_for_test_result_viewer)
  state.test_result_viewer:register_submit_fn(submit)
  if cfg.define_cmds then
    setup_cmds()
  end
end

M.update_contest_data = function()
  state.db:update_contest_data()
end
M._download_tests = _download_tests
M.download_tests = download_tests
M.test = test
M.login = auth.login
M.submit = submit
M.open = function()
  state.test_result_viewer:open()
end
M.close = function()
  state.test_result_viewer:close()
end
M.toggle = function()
  state.test_result_viewer:toggle()
end
M.open_database = function()
  state.db:open()
end

vim.keymap.set({ 'n' }, '<leader>at', test, { desc = 'atcoder: test sample cases' })

return M
