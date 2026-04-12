local async = require('plenary.async')

local config = require('online-judge.config')
local lang = require('online-judge.language')
local notifier = require('online-judge.utils')
local parser = require('online-judge.test_parser')
local sample_manager = require('online-judge.sample_manager')
local service_registry = require('online-judge.service_registry')
local test_case_service = require('online-judge.test_case_service')

local M = {}

local function schedule_ui(fn)
  vim.schedule(fn)
end

local function noop_viewer()
  return {
    open = function() end,
    start_phase = function() end,
    update = function(_, _, callback)
      if type(callback) == 'function' then
        callback()
      end
    end,
    start_spinner = function() end,
    stop_spinner = function() end,
  }
end

---@param cmd string[]
---@return vim.SystemCompleted
local function system(cmd)
  return notifier.async_system(cmd)
end

local function test_command(command, test_dir_path)
  local cmd = {
    config.oj(),
    'test',
  }
  if not config.exact_match() then
    vim.list_extend(cmd, { '--error', config.precision() })
  end
  vim.list_extend(cmd, {
    '--ignore-spaces-and-newlines',
    '--tle',
    config.tle(),
    '--directory',
    test_dir_path,
    '-c',
    command,
  })
  if vim.fn.executable('time') == 1 then
    vim.list_extend(cmd, { '--mle', config.mle() })
  end
  return cmd
end

local function prepare_single_case_dir(context, case_name)
  local paths = test_case_service.case_paths(context.test_dir_path, case_name)
  if vim.fn.filereadable(paths.input) == 0 or vim.fn.filereadable(paths.output) == 0 then
    return nil, 'test case files are missing'
  end

  local safe_name = case_name:gsub('[^%w%-_]', '_')
  local dir_path = config.cache_to(vim.fs.joinpath('single_case', safe_name))
  vim.fn.mkdir(dir_path, 'p')
  for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(dir_path, '*'), false, true)) do
    vim.fn.delete(path)
  end

  local target = test_case_service.case_paths(dir_path, case_name)
  vim.fn.writefile(vim.fn.readfile(paths.input), target.input)
  vim.fn.writefile(vim.fn.readfile(paths.output), target.output)
  return dir_path
end

---@param context SourceContext
---@return vim.SystemCompleted
local function download_samples(context)
  if context.url == '' then
    return {
      code = 1,
      stdout = '',
      stderr = 'url is not written',
      signal = 0,
    }
  end

  local service = service_registry.resolve(context.url)
  local res = system(service.download_tests_cmd(context.url, context.test_dir_path))
  if res.code == 0 then
    sample_manager.normalize_samples(context.test_dir_path)
  end
  return res
end

---@param context SourceContext
---@param viewer table
---@param callback fun(opts:table)|nil
---@param case_name string|nil
local function run_impl(context, viewer, callback, case_name)
  callback = callback or function() end
  viewer = viewer or noop_viewer()

  local build_opt = lang.get_option(context.filetype)
  local build_fn = assert(build_opt.build, 'build_fn is nil')
  local command = build_opt.command({ file_path = context.file_path })

  if context.url == '' then
    notifier.notify('problem url is required', vim.log.levels.ERROR)
    viewer:update({
      file_path = context.file_path,
      command = command,
      test_dir_path = context.test_dir_path,
      error_lines = { 'problem url is required' },
    })
    return
  end

  viewer:open()
  viewer:start_phase('building', {
    file_path = context.file_path,
    command = command,
    test_dir_path = context.test_dir_path,
    raw_lines = {},
    error_lines = {},
  })

  build_fn({ file_path = context.file_path }, function(build_res)
    if build_res.code ~= 0 then
      vim.schedule(function()
        notifier.notify('failed to build', vim.log.levels.ERROR)
        if build_res.stderr and build_res.stderr ~= '' then
          notifier.notify(build_res.stderr, vim.log.levels.ERROR)
        end
        viewer:update({
          file_path = context.file_path,
          command = command,
          test_dir_path = context.test_dir_path,
          error_lines = vim.split(build_res.stderr or '', '\n', { plain = true }),
        })
      end)
      return
    end

    async.void(function()
      if not sample_manager.has_sample_cases(context.test_dir_path) then
        schedule_ui(function()
          viewer:start_phase('downloading')
        end)
        local download_res = download_samples(context)
        if download_res.code ~= 0 then
          notifier.notify('failed to download tests', vim.log.levels.ERROR)
          notifier.notify(download_res.stdout ~= '' and download_res.stdout or download_res.stderr, vim.log.levels.ERROR)
          schedule_ui(function()
            viewer:update({
              file_path = context.file_path,
              command = command,
              test_dir_path = context.test_dir_path,
              error_lines = vim.split(download_res.stderr ~= '' and download_res.stderr or download_res.stdout, '\n', { plain = true }),
            })
          end)
          return
        end
      end

      local run_test_dir = context.test_dir_path
      if case_name ~= nil and case_name ~= '' then
        local single_case_dir, err = prepare_single_case_dir(context, case_name)
        if not single_case_dir then
          notifier.notify(err, vim.log.levels.ERROR)
          schedule_ui(function()
            viewer:update({
              file_path = context.file_path,
              command = command,
              test_dir_path = context.test_dir_path,
              error_lines = { err },
            })
          end)
          return
        end
        run_test_dir = single_case_dir
      end

      schedule_ui(function()
        viewer:start_phase('testing')
      end)

      local test_res = system(test_command(command, run_test_dir))
      local parsed = parser.parse(test_res.stdout)
      vim.schedule(function()
        viewer:update({
          file_path = context.file_path,
          command = command,
          test_dir_path = context.test_dir_path,
          result = parsed.raw_lines,
          parsed = parsed,
        })
        callback(vim.tbl_deep_extend('force', test_res, {
          result = parsed.raw_lines,
          parsed = parsed,
        }))
      end)
    end)()
  end)
end

---@param context SourceContext
---@param viewer table
---@param callback fun(opts:table)|nil
function M.run(context, viewer, callback)
  run_impl(context, viewer, callback, nil)
end

---@param context SourceContext
---@param case_name string
---@param viewer table
---@param callback fun(opts:table)|nil
function M.run_case(context, case_name, viewer, callback)
  run_impl(context, viewer, callback, case_name)
end

M.download_samples = download_samples

return M
