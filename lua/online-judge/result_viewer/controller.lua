local utils = require('online-judge.utils')

local M = {}

---@param bufnr integer
---@param keymap table<string, string|string[]|false>|nil
---@param actions table<string, fun()>
function M.attach(bufnr, keymap, actions)
  local maps = vim.tbl_deep_extend('force', {
    rerun = 'r',
    submit = 's',
    preview = '<CR>',
    add_case = 'a',
    edit_case = 'e',
    copy_case = 'c',
    delete_case = 'D',
    debug_case = 'd',
  }, keymap or {})

  local function bind(action_name, callback)
    local keys = maps[action_name]
    if keys == false or type(callback) ~= 'function' then
      return
    end
    if type(keys) == 'string' then
      keys = { keys }
    end
    for _, lhs in ipairs(keys) do
      vim.keymap.set('n', lhs, callback, {
        buffer = bufnr,
        silent = true,
      })
    end
  end

  bind('rerun', function()
    actions.rerun()
  end)

  bind('submit', function()
    if actions.submit then
      actions.submit()
    else
      utils.notify('submit is not wired yet', vim.log.levels.WARN)
    end
  end)

  bind('preview', actions.preview)
  bind('add_case', actions.add_case)
  bind('edit_case', actions.edit_case)
  bind('copy_case', actions.copy_case)
  bind('delete_case', actions.delete_case)
  bind('debug_case', actions.debug_case)

  return maps
end

return M
