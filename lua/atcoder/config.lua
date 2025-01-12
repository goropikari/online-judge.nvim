local M = {}

---@diagnostic disable-next-line
local cache_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), '/atcoder.nvim')
local function cache_to(path)
  return vim.fs.joinpath(cache_dir, path)
end

---@param app string
---@return string
local function mason_path(app)
  local ok, registry = pcall(require, 'mason-registry')

  if ok and registry.is_installed(app) then
    local pkg = registry.get_package(app)
    return pkg:get_install_path()
  end
  return ''
end

---@class PluginConfig
---@field oj {path:string,tle:number,mle:integer}
---@field codelldb_path string
---@field cache_dir string
---@field out_dirpath string
---@field contest_problem string
---@field problems string
---@field contest_problem_csv string
---@field problems_csv string
---@field define_cmds boolean
---@field lang {string:LanguageOption}

---@type PluginConfig
local default_config = {
  oj = {
    path = 'oj',
    tle = 5, -- sec
    mle = 1024, -- mega byte
  },
  codelldb_path = mason_path('codelldb'),

  out_dirpath = '/tmp/atcoder/',

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

---@return string
function M.oj()
  return config.oj.path
end

---@return number
function M.tle()
  return config.oj.tle
end

---@param tle_sec integer
function M.set_tle(tle_sec)
  config.oj.tle = tle_sec
end

---@return integer
function M.mle()
  return config.oj.mle
end

---@param mle_mb integer
function M.set_mle(mle_mb)
  config.oj.mle = mle_mb
end

---@return string
function M.codelldb()
  return vim.fs.joinpath(config.codelldb_path, 'extension', 'adapter', 'codelldb')
end

M.cache_to = cache_to

return M
