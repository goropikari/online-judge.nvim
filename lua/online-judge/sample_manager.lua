local io = require('online-judge.io')
local utils = require('online-judge.utils')

local M = {}

local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == 'file'
end

local function remove_file(path)
  vim.uv.fs_unlink(path)
end

local function rename_file(from, to)
  local ok, err = vim.uv.fs_rename(from, to)
  return ok ~= nil, err
end

local function scandir(dir_path)
  local dir = vim.uv.fs_scandir(dir_path)
  if not dir then
    return function()
      return nil
    end
  end

  return function()
    return vim.uv.fs_scandir_next(dir)
  end
end

---@param dir_path string
---@return boolean
function M.has_sample_cases(dir_path)
  for name, type in scandir(dir_path) do
    if not name then
      break
    end
    if type == 'file' and name:match('^sample%-%d+%.in$') then
      local prefix = name:gsub('%.in$', '')
      if is_file(vim.fs.joinpath(dir_path, prefix .. '.out')) then
        return true
      end
    end
  end

  return false
end

---@param dir_path string
function M.remove_sample_cases(dir_path)
  if not io.isdirectory(dir_path) then
    return
  end

  for name, type in scandir(dir_path) do
    if not name then
      break
    end
    if type == 'file' and name:match('^sample%-%d+%.') then
      remove_file(vim.fs.joinpath(dir_path, name))
    end
  end
end

---@param dir_path string
function M.normalize_samples(dir_path)
  if not io.isdirectory(dir_path) then
    return
  end

  local pairs = {}
  for name, type in scandir(dir_path) do
    if not name then
      break
    end
    if type == 'file' and name:match('%.in$') then
      local prefix = name:gsub('%.in$', '')
      if not prefix:match('^custom%-') then
        local out_path = vim.fs.joinpath(dir_path, prefix .. '.out')
        if is_file(out_path) then
          table.insert(pairs, prefix)
        end
      end
    end
  end

  table.sort(pairs)
  local unique = {}
  local seen = {}
  for _, prefix in ipairs(pairs) do
    if not seen[prefix] then
      seen[prefix] = true
      table.insert(unique, prefix)
    end
  end

  local staged = {}
  for index, prefix in ipairs(unique) do
    local temp_prefix = string.format('__oj_sample_tmp_%d__', index)
    local renamed = true
    for _, ext in ipairs({ 'in', 'out' }) do
      local from = vim.fs.joinpath(dir_path, prefix .. '.' .. ext)
      local to = vim.fs.joinpath(dir_path, temp_prefix .. '.' .. ext)
      if from ~= to and not rename_file(from, to) then
        renamed = false
      end
    end
    if renamed then
      table.insert(staged, temp_prefix)
    end
  end

  for index, prefix in ipairs(staged) do
    local sample_prefix = string.format('sample-%d', index)
    for _, ext in ipairs({ 'in', 'out' }) do
      local from = vim.fs.joinpath(dir_path, prefix .. '.' .. ext)
      local to = vim.fs.joinpath(dir_path, sample_prefix .. '.' .. ext)
      rename_file(from, to)
    end
  end
end

---@param dir_path string
---@return integer
function M.next_custom_id(dir_path)
  return utils.maximum_test_id(dir_path, 'custom') + 1
end

return M
