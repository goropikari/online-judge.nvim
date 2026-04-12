local service_registry = require('online-judge.service_registry')
local utils = require('online-judge.utils')

local M = {}

---@param context SourceContext
---@return boolean
local function confirm_submission(context)
  if os.getenv('ONLINE_JUDGE_FORCE_SUBMISSION') == '1' then
    return true
  end

  local confirm = string.lower(vim.fn.input('submit [y/N]: '))
  return ({ y = true, yes = true })[confirm] == true
end

---@param context SourceContext
---@param viewer table|nil
---@param opts {update_viewer_on_error?:boolean}|nil
---@return boolean
function M.submit(context, viewer, opts)
  opts = opts or {}

  if context.url == '' then
    utils.notify('problem url is required', vim.log.levels.ERROR)
    if viewer and opts.update_viewer_on_error then
      viewer:update({
        file_path = context.file_path,
        command = '',
        test_dir_path = context.test_dir_path,
        error_lines = { 'problem url is required' },
      })
    end
    return false
  end

  if not confirm_submission(context) then
    return false
  end

  if viewer then
    viewer:start_phase('submitting')
  end

  local service = service_registry.resolve(context.url)
  service.submit(context.url, context.file_path, context.filetype)

  if viewer then
    vim.defer_fn(function()
      viewer:stop_spinner()
    end, 200)
  end

  return true
end

return M
