require('atcoder.cmds')
local utils = require('atcoder.utils')
local window = require('atcoder.window')

local async = require('plenary.async')
local curl = require('plenary.curl')
local system = async.wrap(vim.system, 3)

local M = {}

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
---@field bufnr integer
---@field win Window
---@field test_cases table
local state = {
  bufnr = -1,
  win = nil, ---@diagnostic disable-line
  test_cases = {},
}

local function open_sqlite()
  vim.cmd('term sqlite3 ' .. config.database_path)
end

local function update_contest_data()
  async.void(function()
    local out = system({
      'rm',
      '-f',
      config.database_path,
    })
    if out.code ~= 0 then
      vim.notify(out.stderr, vim.log.levels.WARN)
      return
    end

    -- local out2 = system({
    --   -- 'curl',
    --   -- '-s',
    --   -- '--compressed',
    --   -- 'https://kenkoooo.com/atcoder/resources/contest-problem.json',
    --   'cat',
    --   config.contest_problem,
    -- })
    -- if out2.code ~= 0 then
    --   vim.notify(out2.stderr, vim.log.levels.WARN)
    --   return
    -- end
    --
    -- local out3 = system({
    --   'jq',
    --   '-r',
    --   '.[]|[.contest_id, .problem_id]|@csv',
    -- }, {
    --   stdin = out2.stdout,
    -- })
    -- if out3.code ~= 0 then
    --   vim.notify(out3.stderr, vim.log.levels.WARN)
    --   return
    -- end
    --
    -- local file = io.open(config.contest_problem_csv, 'w')
    -- if file ~= nil then
    --   file:write('"contest_id","problem_id"\n')
    --   file:write(out3.stdout)
    --   file:close()
    -- end
    --
    -- local out4 = system({
    --   'sqlite3',
    --   '-separator',
    --   ',',
    --   config.database_path,
    --   '.import ' .. config.contest_problem_csv .. ' contests',
    -- })
    -- if out4.code ~= 0 then
    --   vim.notify(out4.stderr, vim.log.levels.WARN)
    -- end

    local out5 = system({
      -- 'curl',
      -- '-s',
      -- '--compressed',
      -- 'https://kenkoooo.com/atcoder/resources/problems.json',
      'cat',
      config.problems,
    })
    if out5.code ~= 0 then
      vim.notify(out5.stderr, vim.log.levels.WARN)
      return
    end

    local out6 = system({
      'jq',
      '-r',
      '.[]|[.id, .contest_id, .problem_index, .name, .title]|@csv',
    }, {
      stdin = out5.stdout,
    })
    if out6.code ~= 0 then
      vim.notify(out6.stderr, vim.log.levels.WARN)
      return
    end

    local file2 = io.open(config.problems_csv, 'w')
    if file2 ~= nil then
      file2:write('"id","contest_id","problem_index","name","title"\n')
      file2:write(out6.stdout)
      file2:close()
    end

    local out7 = system({
      'sqlite3',
      '-separator',
      ',',
      config.database_path,
      '.import ' .. config.problems_csv .. ' problems',
    })
    if out7.code ~= 0 then
      vim.notify(out7.stderr, vim.log.levels.WARN)
    end
    vim.notify('finish updating atcoder.db')
  end)()
end

--- Retrieve the contest_id in the order of the URL written at the beginning of the file, the ATCODER_CONTEST_ID environment variable, and the directory name.
---@return string
local function get_contest_id()
  local id = string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], 'contests/([%w_-]+)/') or os.getenv('ATCODER_CONTEST_ID') or utils.get_dirname() -- base directory name

  local res = vim
    .system({
      'sqlite3',
      config.database_path,
      string.format("SELECT EXISTS (SELECT * FROM problems WHERE contest_id = '%s')", id),
    })
    :wait()
  if res.stdout == '0' then
    vim.notify('invalid contest_id: ' .. id, vim.log.levels.WARN)
  end

  return id
end

---@return string
local function get_problem_id(contest_id)
  local problem_id = string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], 'contests/[%w_-]+/tasks/([%w_-]+)')
  if problem_id then
    return problem_id
  end
  local problem_index = utils.get_filename_without_ext()
  problem_index = string.lower(problem_index)

  local out = vim
    .system({
      'sqlite3',
      config.database_path,
      string.format("SELECT id FROM problems WHERE contest_id = '%s' AND lower(problem_index) = '%s'", contest_id, problem_index),
    })
    :wait()
  if out.code ~= 0 then
    vim.notify(out.stderr, vim.log.levels.WARN)
    return ''
  end
  return vim.trim(out.stdout)
end

---@return string
local function get_test_dirname()
  return vim.fn.expand('%:p:h') .. '/test_' .. utils.get_filename_without_ext()
end

local function _download_tests(contest_id, problem_id, include_system)
  local test_dirname = get_test_dirname()
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
  -- vim.print(cmd)
  async.void(function()
    local out = system(cmd, {})
    if out.code ~= 0 then
      -- oj の log は stdout に出る
      vim.notify(out.stdout, vim.log.levels.WARN)
      return
    end
    vim.notify('Download tests of ' .. problem_id .. ': ' .. test_dirname)
  end)()
end

local function download_tests(include_system)
  local contest_id = get_contest_id()
  local problem_id = get_problem_id(contest_id)
  if vim.fn.isdirectory(problem_id) == 0 then
    _download_tests(contest_id, problem_id, include_system)
  else
    vim.notify('already downloaded')
  end
end

local function exec_config()
  local prog = {
    cpp = {
      build = function(callback)
        local outdir = '/tmp/' .. get_problem_id()
        local exec_path = outdir .. '/' .. utils.get_filename_without_ext()
        local file_timestamp = utils.get_file_timestamp(utils.get_absolute_path())
        local exec_timestamp = utils.get_file_timestamp(exec_path)
        if exec_timestamp == nil or file_timestamp > exec_timestamp then
          vim.notify('compiling')
          vim.fn.mkdir(outdir, 'p')
          vim.system({
            'g++',
            '-std=gnu++20',
            '-O2',
            '-o',
            exec_path,
            utils.get_absolute_path(),
          }, {}, function()
            vim.notify('finish compiling')
            if type(callback) == 'function' then
              callback()
            end
          end)
        else
          if type(callback) == 'function' then
            callback()
          end
        end
      end,
      cmd = function()
        local outdir = '/tmp/' .. get_problem_id()
        vim.fn.mkdir(outdir, 'p')
        local exec_path = outdir .. '/' .. utils.get_filename_without_ext()
        return exec_path
      end,
    },
  }
  local prog_cfg = prog[vim.bo.filetype]
  local build = vim.tbl_get(prog_cfg, 'build')
  if build == nil then
    build = function(cb)
      cb()
    end
  end
  return {
    build,
    prog_cfg.cmd(),
  }
end

---@class TestResult
---@field code integer
---@field stdout string
---@field stderr string
---@field test_dir_path string
---@field source_code string
---@field command string

---@params TestResult
---@params callback function
local function _update_test_result(test_result, callback)
  local lines = vim.split(test_result.stdout, '\n')
  for i, line in ipairs(lines) do
    line = line:gsub('^%[%w+%]%s', '')
    line = line:gsub('^sample%-', '▷ sample%-')
    line = line:gsub('^custom%-', '▷ custom%-')
    lines[i] = line
  end
  lines = vim.list_extend({
    'test_dir: ' .. test_result.test_dir_path,
    'source code: ' .. test_result.source_code,
    'cmd: ' .. test_result.command,
    '',
    'help',
    '  e:    edit test case',
    '  r:    rerun test cases',
    '  <CR>: view/hide test case',
    '',
  }, lines)
  vim.api.nvim_set_option_value('modifiable', true, { buf = state.bufnr })
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_lines(state.bufnr, -1, -1, false, { 'Executed at:', vim.fn.strftime('%c') })
  vim.api.nvim_set_option_value('modifiable', false, { buf = state.bufnr })
  state.win:open()

  if test_result.code ~= 0 then
    return
  end

  if type(callback) == 'function' then
    callback()
  end
end

local function _execute_test(test_dir_path, source_code, command, callback)
  state.test_cases = {}
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
    local out = system(cmd, {})
    vim.schedule(function()
      _update_test_result({
        code = out.code,
        stdout = out.stdout,
        stderr = out.stderr,
        test_dir_path = test_dir_path,
        source_code = source_code,
        command = command,
      }, callback)
    end)
  end)()
end

local function execute_test(callback)
  local build, cmd = unpack(exec_config())
  build(function()
    vim.schedule(function()
      _execute_test(get_test_dirname(), utils.get_absolute_path(), cmd, callback)
    end)
  end)
end

local function login()
  async.void(function()
    local cmd = {
      'oj',
      'login',
      '-u',
      vim.fn.input('username'),
      '-p',
      vim.fn.inputsecret('password'),
      'https://atcoder.jp',
    }

    local res = system(cmd)
    if res.code ~= 0 then
      vim.notify(res.stdout, vim.log.levels.WARN)
      vim.notify(res.stderr, vim.log.levels.WARN)
      return
    end
    vim.notify(res.stdout)
  end)()
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
      fn = update_contest_data,
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
        submit(get_contest_id(), get_problem_id())
      end,
    },
    {
      name = 'AtCoderLogin',
      fn = login,
    },
  }
  for _, cmd in pairs(cmds) do
    vim.api.nvim_create_user_command(cmd.name, cmd.fn, {})
  end
end

local function _get_test_dir_from_buf()
  local lines = vim.api.nvim_buf_get_lines(0, 0, 1, false)
  return string.match(lines[1], 'test_dir: ([%w%p]+)')
end

local function _get_source_code_from_buf()
  local lines = vim.api.nvim_buf_get_lines(0, 1, 2, false)
  return string.match(lines[1], 'source code: ([%w%p]+)')
end

local function _get_exec_cmd_from_buf()
  local lines = vim.api.nvim_buf_get_lines(0, 2, 3, false)
  return string.match(lines[1], 'cmd: ([%w%p]+)')
end

local function rerun_tests_at_atcoder_buf()
  local test_dir_path = _get_test_dir_from_buf()
  local src_code = _get_source_code_from_buf()
  local command = _get_exec_cmd_from_buf()
  vim.print({ test_dir_path, command, src_code })
  _execute_test(test_dir_path, src_code, command)
end

local function setup_keymap()
  -- rerun test
  vim.keymap.set({ 'n' }, 'r', function()
    rerun_tests_at_atcoder_buf()
  end, {
    buffer = state.bufnr,
  })

  -- edit test case
  vim.keymap.set({ 'n' }, 'e', function()
    local test_dir_path = _get_test_dir_from_buf()
    local test_case = vim.fn.expand('<cWORD>')
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 or vim.fn.filereadable(output_file_path) == 0 then
      -- do nothing if file is not exist.
      vim.print(input_file_path, output_file_path)
      return
    end

    vim.cmd('vsplit')
    vim.cmd('split')
    vim.cmd('edit ' .. input_file_path)
    vim.cmd('wincmd j')
    vim.cmd('edit ' .. output_file_path)

    vim.api.nvim_buf_get_name(0)
  end, {
    buffer = state.bufnr,
  })

  -- preview test case
  vim.keymap.set({ 'n' }, '<CR>', function()
    local test_dir_path = _get_test_dir_from_buf()
    local test_case = vim.fn.expand('<cWORD>')
    local file_path_prefix = test_dir_path .. '/' .. test_case

    local input_file_path = file_path_prefix .. '.in'
    local output_file_path = file_path_prefix .. '.out'
    if vim.fn.filereadable(input_file_path) == 0 then
      -- do nothing if file is not exist.
      return
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = state.bufnr })
    local input = vim.fn.readfile(input_file_path, 'r')
    local output = vim.fn.readfile(output_file_path, 'r')

    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local hidden = state.test_cases[test_case] == nil
    if hidden then
      local line = vim.api.nvim_buf_get_lines(state.bufnr, row - 1, row, false)[1]
      line = line:gsub('▷ ', '▽ ')
      vim.api.nvim_buf_set_lines(state.bufnr, row - 1, row, false, { line })
      state.test_cases[test_case] = #input + #output + 4 -- 4 = input, newline, output, newline
      vim.api.nvim_buf_set_lines(
        state.bufnr,
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
      local line = vim.api.nvim_buf_get_lines(state.bufnr, row - 1, row, false)[1]
      line = line:gsub('▽ ', '▷ ')
      vim.api.nvim_buf_set_lines(state.bufnr, row - 1, row, false, { line })
      local delete_num_lines = state.test_cases[test_case]
      vim.api.nvim_buf_set_lines(state.bufnr, row, row + delete_num_lines, false, {})
      state.test_cases[test_case] = nil
    end
    vim.api.nvim_set_option_value('modifiable', false, { buf = state.bufnr })
  end, {
    buffer = state.bufnr,
  })
end

function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts or {})
  vim.fn.mkdir(config.out_dirpath, 'p')
  vim.fn.mkdir(cache_dir, 'p')
  state.bufnr = vim.api.nvim_create_buf(false, true)
  state.win = window.new(state.bufnr)
  vim.api.nvim_set_option_value('filetype', 'atcoder', { buf = state.bufnr })
  setup_keymap()
  if config.define_cmds then
    setup_cmds()
  end
end

M.update_contest_data = update_contest_data
M._download_tests = _download_tests
M.download_tests = download_tests
M.execute_test = execute_test
M._execute_test = _execute_test
M.login = login
M.submit = submit
M.open_sqlite = open_sqlite

vim.keymap.set({ 'n' }, '<leader>at', function()
  if vim.api.nvim_get_option_value('filetype', { buf = 0 }) == 'atcoder' then
    rerun_tests_at_atcoder_buf()
  else
    execute_test()
  end
end, { desc = 'atcoder: test sample cases' })

vim.keymap.set({ 'n' }, '<leader>ad', function()
  download_tests()
end, { desc = 'atcoder: download sample test cases' })

return M
