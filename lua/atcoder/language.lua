local utils = require('atcoder.utils')

local M = {}

---@class LanguageConfig
---@field file_path string
---@field contest_id? string
---@field problem_id? string

local lang = {
  cpp = {
    build = function(cfg, callback)
      local file_path = vim.fn.fnamemodify(cfg.file_path, ':p')
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
        }, { text = true }, function()
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
    cmd = function(cfg)
      local file_path = cfg.file_path
      local outdir = '/tmp/atcoder.nvim/' .. vim.fn.fnamemodify(file_path, ':h:t')
      vim.fn.mkdir(outdir, 'p')
      local exec_path = outdir .. '/' .. vim.fn.fnamemodify(file_path, ':t:r')
      return exec_path
    end,
  },
}

function M.get_config(filetype)
  filetype = filetype or vim.bo.filetype
  local cfg = lang[filetype]
  cfg.build = cfg.build or function(config, callback)
    if type(callback) == 'function' then
      callback(config)
    end
  end
  return {
    cfg.build,
    cfg.cmd,
  }
end

return M
