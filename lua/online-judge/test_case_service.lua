local sample_manager = require('online-judge.sample_manager')

local M = {}

local function is_sample(case_name)
  return case_name ~= nil and (case_name:match('^sample%-') or case_name:match('^example_'))
end

---@param test_dir_path string
---@param case_name string
---@return {input:string, output:string}
function M.case_paths(test_dir_path, case_name)
  local prefix = vim.fs.joinpath(test_dir_path, case_name)
  return {
    input = prefix .. '.in',
    output = prefix .. '.out',
  }
end

---@param paths {input:string, output:string}
local function open_test_cases(paths)
  vim.cmd('split')
  vim.cmd('wincmd j')
  vim.cmd('edit ' .. paths.input)
  vim.cmd('split')
  vim.cmd('wincmd j')
  vim.cmd('edit ' .. paths.output)
  vim.cmd('wincmd k')
end

---@param test_dir_path string
---@return {name:string, paths:{input:string, output:string}}
function M.add(test_dir_path)
  local id = sample_manager.next_custom_id(test_dir_path)
  local name = string.format('custom-%d', id)
  local paths = M.case_paths(test_dir_path, name)

  vim.fn.mkdir(test_dir_path, 'p')
  vim.fn.writefile({}, paths.input)
  vim.fn.writefile({}, paths.output)
  open_test_cases(paths)

  return {
    name = name,
    paths = paths,
  }
end

---@param test_dir_path string
---@param case_name string
---@return boolean, string?
function M.edit(test_dir_path, case_name)
  if is_sample(case_name) then
    return false, 'could not edit sample test case. copy and then edit it.'
  end

  local paths = M.case_paths(test_dir_path, case_name)
  if vim.fn.filereadable(paths.input) == 0 or vim.fn.filereadable(paths.output) == 0 then
    return false, 'test case files are missing'
  end

  open_test_cases(paths)
  return true
end

---@param test_dir_path string
---@param case_name string
---@return boolean, string|{name:string, paths:{input:string, output:string}}
function M.copy(test_dir_path, case_name)
  local from_paths = M.case_paths(test_dir_path, case_name)
  if vim.fn.filereadable(from_paths.input) == 0 or vim.fn.filereadable(from_paths.output) == 0 then
    return false, 'test case files are missing'
  end

  local id = sample_manager.next_custom_id(test_dir_path)
  local name = string.format('custom-%d', id)
  local to_paths = M.case_paths(test_dir_path, name)

  vim.fn.mkdir(test_dir_path, 'p')
  vim.fn.writefile(vim.fn.readfile(from_paths.input), to_paths.input)
  vim.fn.writefile(vim.fn.readfile(from_paths.output), to_paths.output)
  open_test_cases(to_paths)

  return true, {
    name = name,
    paths = to_paths,
  }
end

---@param test_dir_path string
---@param case_name string
---@return boolean, string?
function M.delete(test_dir_path, case_name)
  if is_sample(case_name) then
    return false, 'could not delete sample test case'
  end

  local paths = M.case_paths(test_dir_path, case_name)
  if vim.fn.filereadable(paths.input) == 0 and vim.fn.filereadable(paths.output) == 0 then
    return false, 'test case files are missing'
  end

  local confirm = string.lower(vim.fn.input('remove test case [y/N]: '))
  if not ({ y = true, yes = true })[confirm] then
    return false, 'cancelled'
  end

  for _, path in ipairs({ paths.input, paths.output }) do
    local bufnr = vim.fn.bufnr(path)
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.cmd('bd ' .. bufnr)
    end
    vim.fn.delete(path)
  end

  return true
end

---@param test_dir_path string
---@param case_name string
---@param max_preview_lines integer?
---@return {input:string[], output:string[]}|nil
function M.preview(test_dir_path, case_name, max_preview_lines)
  local paths = M.case_paths(test_dir_path, case_name)
  if vim.fn.filereadable(paths.input) == 0 or vim.fn.filereadable(paths.output) == 0 then
    return nil
  end

  local function truncate(lines)
    if max_preview_lines == nil or max_preview_lines <= 0 or #lines <= max_preview_lines then
      return lines
    end
    local truncated = vim.list_slice(lines, 1, max_preview_lines)
    table.insert(truncated, string.format('... (%d more lines)', #lines - max_preview_lines))
    return truncated
  end

  return {
    input = truncate(vim.fn.readfile(paths.input, 'r')),
    output = truncate(vim.fn.readfile(paths.output, 'r')),
  }
end

function M.is_sample(case_name)
  return is_sample(case_name)
end

return M
