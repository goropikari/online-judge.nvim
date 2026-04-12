local filetype = require('online-judge.result_viewer.filetype')
local utils = require('online-judge.utils')

local M = {}

---@class SourceContext
---@field file_path string
---@field filetype string
---@field url string
---@field test_dir_path string

---@param file_path string
---@return SourceContext
function M.from_file(file_path)
  file_path = vim.fn.fnamemodify(file_path, ':p')
  return {
    file_path = file_path,
    filetype = utils.get_filetype(file_path),
    url = utils.get_problem_url(file_path),
    test_dir_path = utils.get_test_dirname(file_path),
  }
end

---@param viewer {get_state:fun():table}|nil
---@return SourceContext
function M.current(viewer)
  local file_path = utils.get_absolute_path()
  if filetype.is_result_viewer_buf() and viewer then
    local viewer_state = viewer:get_state()
    if viewer_state.file_path and viewer_state.file_path ~= '' then
      file_path = viewer_state.file_path
    end
  end

  return M.from_file(file_path)
end

return M
