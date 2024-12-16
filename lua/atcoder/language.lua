local utils = require('atcoder.utils')

local M = {}

---@class LanguageOption
---@field build fun(cfg:BuildConfig, callback:function)
---@field command fun(cfg:BuildConfig): string
---@field dap_config fun(cfg:DebugConfig): table
---@field id integer

---@class BuildConfig
---@field source_code string

---@class DebugConfig
---@field source_code_path string
---@field input_test_file_path string

-- language id は提出ページの HTML source を見て言語の対応表から探るしか方法はなさそう
---@type {string:LanguageOption}
local lang = {
  cpp = {
    ---@param cfg BuildConfig
    ---@param callback fun(cfg: BuildConfig)
    build = function(cfg, callback)
      local file_path = vim.fn.fnamemodify(cfg.source_code, ':p')
      local outdir = '/tmp/atcoder.nvim/' .. vim.fn.fnamemodify(file_path, ':h:t')
      vim.fn.mkdir(outdir, 'p')
      local exec_path = outdir .. '/' .. vim.fn.fnamemodify(file_path, ':t:r')
      local file_timestamp = utils.get_file_timestamp(file_path)
      local exec_timestamp = utils.get_file_timestamp(exec_path)

      if exec_timestamp == nil or file_timestamp > exec_timestamp then
        vim.fn.mkdir(outdir, 'p')
        vim.system({
          'g++',
          '-std=gnu++23',
          '-O2',
          '-o',
          exec_path,
          file_path,
        }, { text = true }, function(_)
          if type(callback) == 'function' then
            callback(cfg)
          end
        end)
      else
        if type(callback) == 'function' then
          callback(cfg)
        end
      end
    end,
    ---@param cfg BuildConfig
    command = function(cfg)
      local file_path = cfg.source_code
      local outdir = '/tmp/atcoder.nvim/' .. vim.fn.fnamemodify(file_path, ':h:t')
      vim.fn.mkdir(outdir, 'p')
      local exec_path = outdir .. '/' .. vim.fn.fnamemodify(file_path, ':t:r')
      return exec_path
    end,
    ---@param cfg DebugConfig
    dap_config = function(cfg)
      local executable = vim.fn.fnamemodify(cfg.source_code_path, ':r')
      return {
        name = 'debug for atcoder',
        type = 'cppdbg',
        request = 'launch',
        program = executable,
        cwd = vim.fn.fnamemodify(cfg.source_code_path, ':h'),
        args = { '<', cfg.input_test_file_path },
        build = { 'g++', '-g', '-O0', cfg.source_code_path, '-o', executable },
      }
    end,
    id = 5028, -- C++ 23
  },
  python = {
    build = nil, -- use default fn
    command = function(cfg)
      return 'python3 ' .. cfg.source_code
    end,
    dap_config = function(cfg)
      vim.print(cfg)
      return {
        type = 'python',
        request = 'launch',
        name = 'python debug for atcoder',
        program = cfg.source_code_path,
        args = { cfg.input_test_file_path },
        -- 第一引数を stdin にいれることを前提としている。次のコードを input より前にいれる必要がある
        -- import sys
        -- if len(sys.argv) == 2:
        --     sys.stdin = open(sys.argv[1])
      }
    end,
    id = 5078, -- pypy3
  },
}

---@param filetype string|nil
---@return LanguageOption
function M.get_option(filetype)
  filetype = filetype or vim.bo.filetype

  local cfg = lang[filetype]
  cfg.build = cfg.build or function(config, callback)
    if type(callback) == 'function' then
      callback(config)
    end
  end
  return {
    build = cfg.build,
    command = cfg.command,
    dap_config = cfg.dap_config,
    id = cfg.id,
  }
end

---@param opts {string:LanguageOption}
function M.setup(opts)
  lang = vim.tbl_deep_extend('force', lang, opts or {})
end

return M
