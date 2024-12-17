local M = {}

local cache_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), '/atcoder.nvim')
local function cache_to(path)
  return vim.fs.joinpath(cache_dir, path)
end

---@class PluginConfig
---@field cache_dir string
---@field out_dirpath string
---@field database_path string
---@field contest_problem string
---@field problems string
---@field contest_problem_csv string
---@field problems_csv string
---@field define_cmds boolean
---@field lang {string:LanguageOption}

---@type PluginConfig
local default_config = {
  out_dirpath = '/tmp/atcoder/',

  database_path = cache_to('/atcoder.db'),
  contest_problem = cache_to('/contest-problem.json'),
  problems = cache_to('/problems.json'),
  contest_problem_csv = cache_to('contest-problem.csv'),
  problems_csv = cache_to('/problems.csv'),
  define_cmds = true,
  lang = {},
  cache_dir = cache_dir,
}

---@type PluginConfig
---@diagnostic disable-next-line
local config = {}

function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts or {})
end

---@return PluginConfig
function M.get()
  return config
end

return M
