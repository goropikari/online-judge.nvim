local utils = require('online-judge.utils')

local M = {}

local default_keymaps = {
  rerun = 'r',
  rerun_case = 'R',
  submit = 's',
  preview = '<CR>',
  add_case = 'a',
  edit_case = 'e',
  copy_case = 'c',
  delete_case = 'D',
  debug_case = 'd',
}

local function normalize_definition(action_name, definition)
  if definition == false then
    return {
      enabled = false,
      display = '',
    }
  end

  local normalized = {
    enabled = true,
    mode = 'n',
    desc = action_name,
    silent = true,
    nowait = false,
  }

  if type(definition) == 'string' then
    normalized.keys = { definition }
  elseif vim.islist(definition) then
    normalized.keys = vim.deepcopy(definition)
  elseif type(definition) == 'table' then
    local keys = definition.keys or definition[1]
    if type(keys) == 'string' then
      normalized.keys = { keys }
    elseif vim.islist(keys) then
      normalized.keys = vim.deepcopy(keys)
    end
    normalized.mode = definition.mode or normalized.mode
    normalized.desc = definition.desc or normalized.desc
    if definition.silent ~= nil then
      normalized.silent = definition.silent
    end
    if definition.nowait ~= nil then
      normalized.nowait = definition.nowait
    end
  end

  normalized.keys = normalized.keys or {}
  if #normalized.keys == 0 then
    normalized.enabled = false
  end
  normalized.display = normalized.enabled and table.concat(normalized.keys, ', ') or ''
  return normalized
end

---@param bufnr integer
---@param keymap table<string, any>|nil
---@param actions table<string, fun()>
function M.attach(bufnr, keymap, actions)
  local raw_maps = vim.tbl_deep_extend('force', vim.deepcopy(default_keymaps), keymap or {})
  local normalized_maps = {}
  local display_maps = {}

  for action_name, definition in pairs(raw_maps) do
    normalized_maps[action_name] = normalize_definition(action_name, definition)
    display_maps[action_name] = normalized_maps[action_name].display
  end

  local function bind(action_name, callback)
    local map = normalized_maps[action_name]
    if not map or not map.enabled or type(callback) ~= 'function' then
      return
    end

    for _, lhs in ipairs(map.keys) do
      vim.keymap.set(map.mode, lhs, callback, {
        buffer = bufnr,
        silent = map.silent,
        nowait = map.nowait,
        desc = map.desc,
      })
    end
  end

  bind('rerun', function()
    actions.rerun()
  end)

  bind('rerun_case', function()
    if actions.rerun_case then
      actions.rerun_case()
    end
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

  return display_maps
end

return M
