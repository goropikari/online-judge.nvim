local M = {}

local async = require('plenary.async')
local utils = require('online-judge.utils')

---@param url string
---@param file_path string
---@param lang_id string
function M.submit(url, file_path, lang_id)
  utils.notify('Submitting to yosupo judge...', vim.log.levels.INFO)

  async.void(function()
    local out = utils.async_system({
      'yosupocl',
      'submit',
      url,
      file_path,
      lang_id,
    })

    if out.code ~= 0 then
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end

    utils.notify(out.stdout, vim.log.levels.INFO)
    vim.ui.open(out.stdout)
  end)()
end

return M
