local M = {}

local utils = require('online-judge.utils')

---@class LanguageOption
---@field build fun(cfg:BuildConfig, callback:function)?
---@field command fun(cfg:BuildConfig): string
---@field dap_config fun(cfg:DebugConfig): DapConfig

---@class BuildConfig
---@field file_path string

---@class DebugConfig
---@field file_path string
---@field input_test_file_path string

---@class DapConfig : dap.Configuration
---@field program string

---@class CppDapConfig : DapConfig
---@field build string[]
---@field cwd string

---@class CodelldbDapConfig : CppDapConfig
---@field stdio string[]
---@field expression 'native'

---@class PythonDapConfig : DapConfig
---@field args string[]

-- language id は提出ページの HTML source を見て言語の対応表から探るしか方法はなさそう
---@type table<string,LanguageOption>
local lang = {
  cpp = {
    build = function(cfg, callback)
      local file_path = vim.fn.fnamemodify(cfg.file_path, ':p')
      local outdir = vim.fs.joinpath('/tmp/online-judge.nvim', vim.fn.fnamemodify(file_path, ':h:t'))
      vim.fn.mkdir(outdir, 'p')
      local exec_path = vim.fs.joinpath(outdir, vim.fn.fnamemodify(file_path, ':t:r'))
      local file_timestamp = utils.get_file_timestamp(file_path)
      local exec_timestamp = utils.get_file_timestamp(exec_path)

      if exec_timestamp == nil or file_timestamp > exec_timestamp then
        vim.fn.mkdir(outdir, 'p')
        vim.system({
          'g++',
          '-std=c++23',
          '-O2',
          '-Wunused-variable',
          '-o',
          exec_path,
          file_path,
        }, { text = true }, function(out)
          if type(callback) == 'function' then
            utils.notify(out.stderr, vim.log.levels.WARN)
            callback(out)
          end
        end)
      else
        if type(callback) == 'function' then
          callback({ code = 0 })
        end
      end
    end,
    command = function(cfg)
      local file_path = cfg.file_path
      local outdir = vim.fs.joinpath('/tmp/online-judge.nvim', vim.fn.fnamemodify(file_path, ':h:t'))
      vim.fn.mkdir(outdir, 'p')
      local exec_path = vim.fs.joinpath(outdir, vim.fn.fnamemodify(file_path, ':t:r'))
      return exec_path
    end,
    ---@return CodelldbDapConfig
    dap_config = function(cfg)
      local outdir = '/tmp/online-judge.nvim/debug'
      vim.fn.mkdir(outdir, 'p')
      local executable = vim.fs.joinpath(outdir, vim.fn.fnamemodify(cfg.file_path, ':t:r'))
      local base_config = {
        name = 'debug for atcoder',
        request = 'launch',
        program = executable,
        cwd = vim.fn.fnamemodify(cfg.file_path, ':h'),
        build = { 'g++', '--std=c++23', '-ggdb3', cfg.file_path, '-o', executable },
      }

      return vim.tbl_deep_extend('force', base_config, {
        type = 'oneline_judge_codelldb',
        stdio = { cfg.input_test_file_path },
        expressions = 'native',
      })
    end,
  },
  python = {
    build = nil, -- use default fn
    command = function(cfg)
      return 'python3 ' .. cfg.file_path
    end,
    ---@return PythonDapConfig
    dap_config = function(cfg)
      return {
        type = 'python',
        request = 'launch',
        name = 'python debug for atcoder',
        program = cfg.file_path,
        args = { cfg.input_test_file_path },
        -- 第一引数を stdin にいれることを前提としている。次のコードを input より前にいれる必要がある
        -- import sys
        -- if len(sys.argv) == 2:
        --     sys.stdin = open(sys.argv[1])
      }
    end,
  },
  julia = {
    build = nil, -- use default fn
    command = function(cfg)
      return 'julia ' .. cfg.file_path
    end,
    dap_config = function(cfg)
      return {}
    end,
  },
}

---@param filetype string?
---@return LanguageOption
function M.get_option(filetype)
  filetype = filetype or vim.bo.filetype

  local cfg = lang[filetype]
  cfg.build = cfg.build or function(config, callback)
    if type(callback) == 'function' then
      callback({ code = 0 })
    end
  end
  return {
    build = cfg.build,
    command = cfg.command,
    dap_config = cfg.dap_config,
  }
end

---@param opts {string:LanguageOption}
function M.setup(opts)
  lang = vim.tbl_deep_extend('force', lang, opts or {})
end

return M
