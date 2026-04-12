local M = {}

local function clone(value)
  return vim.deepcopy(value)
end

---@return table
function M.new(initial_state)
  local state = clone(initial_state or {})
  local listeners = {}

  local store = {}

  function store:get_state()
    return clone(state)
  end

  local function notify()
    for _, listener in ipairs(listeners) do
      listener(store:get_state())
    end
  end

  function store:subscribe(listener)
    table.insert(listeners, listener)
    return function()
      for i, item in ipairs(listeners) do
        if item == listener then
          table.remove(listeners, i)
          break
        end
      end
    end
  end

  function store:set_state(next_state, opts)
    state = clone(next_state)
    opts = opts or {}
    if not opts.silent then
      notify()
    end
  end

  function store:patch_state(patch, opts)
    state = vim.tbl_deep_extend('force', state, clone(patch))
    opts = opts or {}
    if not opts.silent then
      notify()
    end
  end

  function store:batch(fn)
    fn(store)
    notify()
  end

  return store
end

return M
