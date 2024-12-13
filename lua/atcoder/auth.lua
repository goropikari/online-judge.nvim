local async = require('plenary.async')
local system = async.wrap(vim.system, 3)

local M = {}

function M.login()
  async.void(function()
    local cmd = {
      'oj',
      'login',
      '-u',
      vim.fn.input('username'),
      '-p',
      vim.fn.inputsecret('password'),
      'https://atcoder.jp',
    }

    local res = system(cmd)
    if res.code ~= 0 then
      vim.notify(res.stdout, vim.log.levels.WARN)
      vim.notify(res.stderr, vim.log.levels.WARN)
      return
    end
    vim.notify(res.stdout)
  end)()
end

return M
