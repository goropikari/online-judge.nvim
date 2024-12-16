local async = require('plenary.async')
local utils = require('atcoder.utils')
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
      utils.notify(res.stdout, vim.log.levels.WARN)
      utils.notify(res.stderr, vim.log.levels.WARN)
      return
    end
    utils.notify(res.stdout)
  end)()
end

return M
