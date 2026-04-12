local lang = require('online-judge.language')
local test_case_service = require('online-judge.test_case_service')
local utils = require('online-judge.utils')

local M = {}

---@param context SourceContext
---@param viewer_state table
---@return boolean
function M.start(context, viewer_state)
  local case_name = viewer_state.selected_case
  if not case_name then
    utils.notify('no test case selected', vim.log.levels.WARN)
    return false
  end

  local ok, dap = pcall(require, 'dap')
  if not ok then
    utils.notify('nvim-dap is required', vim.log.levels.ERROR)
    return false
  end

  local paths = test_case_service.case_paths(context.test_dir_path, case_name)
  if vim.fn.filereadable(paths.input) == 0 then
    utils.notify('test case files are missing', vim.log.levels.WARN)
    return false
  end

  local winid = viewer_state.source_winid or utils.get_window_id_for_file(context.file_path)
  if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
  end

  local dap_config = lang.get_option(context.filetype).dap_config({
    file_path = context.file_path,
    input_test_file_path = paths.input,
  })
  dap.run(dap_config)
  return true
end

return M
