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

return M
