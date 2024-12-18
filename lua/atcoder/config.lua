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
---@field cpptools_path string
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
  oj = {
    path = 'oj',
    tle = 5, -- sec
    mle = 1024, -- mega byte
  },
  codelldb_path = mason_path('codelldb'),
  cpptools_path = mason_path('cpptools'),

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

---@return string
function M.oj()
  return config.oj.path
end

---@return number
function M.tle()
  return config.oj.tle
end

---@return integer
function M.mle()
  return config.oj.mle
end

---@return string
function M.cpptools()
  return vim.fs.joinpath(config.cpptools_path, 'extension', 'debugAdapters', 'bin', 'OpenDebugAD7')
end

---@return string
function M.codelldb()
  return vim.fs.joinpath(config.codelldb_path, 'extension', 'adapter', 'codelldb')
end

return M
