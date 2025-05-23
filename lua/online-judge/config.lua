local M = {}

---@diagnostic disable-next-line
local cache_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), '/online-judge.nvim')
local function cache_to(path)
  return vim.fs.joinpath(cache_dir, path)
end

---@class PluginConfig
---@field oj {path:string, tle:number, mle:integer, exact_match:boolean, precision:string}
---@field codelldb_path string
---@field cache_dir string
---@field out_dirpath string
---@field define_cmds boolean
---@field lang {string:LanguageOption}

---@type PluginConfig
local default_config = {
  oj = {
    path = 'oj',
    tle = 5, -- sec
    mle = 1024, -- mega byte
    exact_match = true,
    precision = '1e-6',
  },
  codelldb_path = vim.fn.exepath('codelldb'),
  out_dirpath = '/tmp/online-judge.nvim/',
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

function M.exact_match()
  return config.oj.exact_match
end

function M.enable_exact_match()
  config.oj.exact_match = true
end

function M.disable_exact_match()
  config.oj.exact_match = false
end

function M.precision()
  return config.oj.precision
end

function M.set_precision(precision)
  config.oj.precision = precision
end

function M.reset_precision()
  config.oj.precision = default_config.oj.precision
end

---@return string
function M.codelldb()
  return vim.fs.joinpath(config.codelldb_path)
end

M.cache_to = cache_to

return M
