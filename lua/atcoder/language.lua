local utils = require('atcoder.utils')

local M = {}

---@class LanguageOption
---@field build fun(cfg:BuildConfig, callback:function)
---@field command fun(cfg:BuildConfig): string
---@field id integer

---@class BuildConfig
---@field source_code string

-- language id は提出ページの HTML source を見て言語の対応表から探るしか方法はなさそう
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
        vim.notify('compiling')
        vim.fn.mkdir(outdir, 'p')
        vim.system({
          'g++',
          '-std=gnu++20',
          '-O2',
          '-o',
          exec_path,
          file_path,
        }, { text = true }, function(out)
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
    id = 5028, -- C++ 23
  },
  python = {
    build = nil, -- use default fn
    cmd = function(cfg)
      return 'python3 ' .. cfg.source_code
    end,
    id = 5078, -- pypy3
  },
}

---@params filetype string|nil
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
    id = cfg.id,
  }
end

---@param opts {string:LanguageOption}
function M.setup(opts)
  lang = vim.tbl_deep_extend('force', lang, opts or {})
end

return M
