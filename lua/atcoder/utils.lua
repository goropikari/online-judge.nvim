local M = {}

function M.get_file_timestamp(file)
  local stat = vim.uv.fs_stat(file)
  if stat then
    return stat.mtime.sec -- 秒単位の最終更新時刻
  else
    return nil, 'File does not exist'
  end
end

---@return string
function M.get_dirname()
  return vim.fn.expand('%:p:h:t')
end

---@return string
function M.get_filename_without_ext()
  return vim.fn.expand('%:p:t:r')
end

---@return string
function M.get_absolute_path()
  return vim.fn.expand('%:p')
end

function M.count_custom_prefix_files(dir_path, prefix_pattern)
  local count = 0
  local dir = vim.uv.fs_scandir(dir_path)
  if not dir then
    print('Invalid path: ' .. dir_path)
    return 0
  end
  while true do
    local name, type = vim.uv.fs_scandir_next(dir)
    if not name then
      break
    end
    if type == 'file' and name:match(prefix_pattern) then
      count = count + 1
    end
  end
  return count
end

---@param bufnr integer
function M.get_window_id(bufnr)
  local windows = vim.api.nvim_list_wins()

  for _, win_id in ipairs(windows) do
    if vim.api.nvim_win_get_buf(win_id) == bufnr then
      return win_id
    end
  end

  return -1
end

---@param filepath string
function M.get_window_id_for_file(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  return M.get_window_id(bufnr)
end

return M
