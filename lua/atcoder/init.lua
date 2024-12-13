require('atcoder.cmds')
local utils = require('atcoder.utils')
local auth = require('atcoder.auth')
local database = require('atcoder.database')
local test_result = require('atcoder.test_result')
local lang = require('atcoder.language')

local async = require('plenary.async')
local curl = require('plenary.curl')
local system = async.wrap(function(cmd, callback)
  vim.system(cmd, { text = true }, callback)
end, 2)

local M = {}

local nopfn = function(_) end

local cache_dir = vim.fn.stdpath('cache') .. '/atcoder.nvim'

---@class PluginConfig
---@field out_dirpath string
---@field database_path string
---@field contest_problem string
---@field problems string
---@field contest_problem_csv string
---@field problems_csv string
---@field define_cmds boolean

---@type PluginConfig
local default_config = {
  out_dirpath = '/tmp/atcoder/',

  database_path = cache_dir .. '/atcoder.db',
  contest_problem = cache_dir .. '/contest-problem.json',
  problems = cache_dir .. '/problems.json',
  contest_problem_csv = cache_dir .. '/contest-problem.csv',
  problems_csv = cache_dir .. '/problems.csv',
  define_cmds = true,
}

---@type PluginConfig
---@diagnostic disable-next-line
local config = {}

---@class State
---@field db Database
---@field test_result_viewer TestResultViewer
local state = {}

--- Retrieve the contest_id in the order of the URL written at the beginning of the file, the ATCODER_CONTEST_ID environment variable, and the directory name.
---@return string
local function get_contest_id()
  local id = string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], 'contests/([%w_-]+)/') or os.getenv('ATCODER_CONTEST_ID') or utils.get_dirname() -- base directory name

  local found = state.db:exist_contest_id(id)
  if not found then
    vim.notify('invalid contest_id: ' .. id, vim.log.levels.WARN)
    return ''
  end

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
  return vim.fn.expand('%:p:h') .. '/test_' .. utils.get_filename_without_ext()
end

local function _download_tests(contest_id, problem_id, include_system, callback)
  local test_dirname = get_test_dirname()
  if vim.fn.isdirectory(test_dirname) == 1 then
    vim.notify('test files are already downloaded')
    if type(callback) == 'function' then
      callback()
    end
    return
  end
  contest_id = contest_id or ''
  problem_id = problem_id or ''
  if contest_id == '' or problem_id == '' then
    vim.notify('contest_id or problem_id is empty: contest_id = ' .. contest_id .. ', problem_id = ' .. problem_id)
    return
  end
  local cmd = {
    'oj',
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
      vim.notify(out.stdout, vim.log.levels.WARN)
      return
    end
    vim.notify('Download tests of ' .. problem_id .. ': ' .. test_dirname)

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
  callback = callback or nopfn
  local contest_id = get_contest_id()
  local problem_id = get_problem_id(contest_id)
  _download_tests(contest_id, problem_id, include_system, function(opts)
    opts = vim.tbl_deep_extend('force', { contest_id = contest_id, problem_id = problem_id }, opts or {})
    callback(opts)
  end)
end

local function _execute_test(test_dir_path, source_code, command, callback)
  state.test_result_viewer:reset_test_cases()
  async.void(function()
    local cmd = {
      'oj',
      't',
      '--error',
      '1e-6',
      '--tle',
      5,
      '--mle',
      1024,
      '--directory',
      test_dir_path,
      '-c',
      command,
    }
    local out = system(cmd)
    vim.schedule(function()
      state.test_result_viewer:update({
        test_dir_path = test_dir_path,
        source_code = source_code,
        command = command,
        result = vim.split(out.stdout, '\n'),
      }, callback)
    end)
  end)()
end

local function execute_test(callback)
  callback = callback or nopfn
  local build_fn, cmd_fn = unpack(lang.get_config())
  local file_path = utils.get_absolute_path()
  local test_dirname = get_test_dirname()
  local cfg = {
    file_path = file_path,
    test_dirname = test_dirname,
  }
  cfg.command = cmd_fn(cfg)
  ---@params post_build {file_path:string, test_dirname:string, command:string}
  build_fn(cfg, function(post_build)
    cfg = vim.tbl_deep_extend('force', cfg, post_build or {})
    vim.schedule(function()
      ---@params post_download {contest_id:string, problm_id:string}
      download_tests(false, function(post_download)
        cfg = vim.tbl_deep_extend('force', cfg, post_download or {})
        ---@params post_test {}
        _execute_test(test_dirname, file_path, cfg.command, function(post_test)
          cfg = vim.tbl_deep_extend('force', cfg, post_test or {})
          callback(cfg)
        end)
      end)
    end)
  end)
end

---@return string
local function generate_submit_url(contest_id, problem_id)
  return string.format('https://atcoder.jp/contests/%s/tasks/%s', contest_id, problem_id)
end

local function submit(contest_id, problem_id)
  local url = generate_submit_url(contest_id, problem_id)
  local filepath = utils.get_absolute_path()

  local callback = function()
    curl.head({
      url = url,
      timeout = 500,
      callback = function(res)
        if res.status ~= 200 then
          vim.notify(vim.inspect(res))
          return
        end
        vim.notify('submit: ' .. url)

        async.void(function()
          local out = system({
            'oj',
            'submit',
            '-y',
            url,
            filepath,
          })
          if out.code ~= 0 then
            vim.notify(out.stdout, vim.log.levels.WARN)
            vim.notify(out.stderr, vim.log.levels.WARN)
          end
          vim.notify(out.stdout)
        end)()
      end,
    })
  end
  execute_test(callback)
end

local function setup_cmds()
  local cmds = {
    {
      name = 'AtCoderUpdateContestData',
      fn = function()
        state.db:update_contest_data()
      end,
    },
    {
      name = 'AtCoderTest',
      fn = execute_test,
    },
    {
      name = 'AtCoderDownloadTest',
      fn = function()
        download_tests(false)
      end,
    },
    {
      name = 'AtCoderSubmit',
      fn = function()
        submit(get_contest_id(), get_problem_id(get_contest_id()))
      end,
    },
    {
      name = 'AtCoderLogin',
      fn = auth.login,
    },
  }
  for _, cmd in pairs(cmds) do
    vim.api.nvim_create_user_command(cmd.name, cmd.fn, {})
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts or {})
  vim.fn.mkdir(config.out_dirpath, 'p')
  vim.fn.mkdir(cache_dir, 'p')
  state.db = database.new()
  state.test_result_viewer = test_result.new()
  if config.define_cmds then
    setup_cmds()
  end
end

M.update_contest_data = function()
  state.db:update_contest_data()
end
M._download_tests = _download_tests
M.download_tests = download_tests
M.execute_test = execute_test
M._execute_test = _execute_test
M.login = auth.login
M.submit = submit
M.open_database = function()
  state.db:open()
end

vim.keymap.set({ 'n' }, '<leader>at', function()
  execute_test()
end, { desc = 'atcoder: test sample cases' })

vim.keymap.set({ 'n' }, '<leader>ad', function()
  download_tests()
end, { desc = 'atcoder: download sample test cases' })

return M
