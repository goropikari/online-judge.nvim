local M = {}

local async = require('plenary.async')

local oj = require('online-judge.config').oj
local utils = require('online-judge.utils')

function M.login()
  async.void(function()
    local cmd = {
      oj(),
      'login',
      '-u',
      vim.fn.input('username: '),
      '-p',
      vim.fn.inputsecret('password: '),
      'https://atcoder.jp',
    }

    local res = utils.async_system(cmd)
    if res.code ~= 0 then
      utils.notify(res.stdout, vim.log.levels.WARN)
      utils.notify(res.stderr, vim.log.levels.WARN)
      return
    end
    utils.notify(res.stdout)
  end)()
end

function M.submit(url, file_path, lang_id)
  async.void(function()
    utils.notify('submit: ' .. url)
    local out = utils.async_system({
      oj(),
      'submit',
      '-y',
      '-l',
      lang_id,
      '-w',
      '0',
      url,
      file_path,
    })
    if out.code ~= 0 then
      utils.notify(out.stdout, vim.log.levels.ERROR)
      utils.notify(out.stderr, vim.log.levels.ERROR)
    end

    vim.schedule(function()
      local result = vim.fn.split(out.stdout, '\n')
      for _, line in ipairs(result) do
        local submission_url = line:match('%[SUCCESS%]%sresult:%s([%p%w]+)')
        if submission_url then
          utils.notify(submission_url)
        end
      end
    end)
  end)()
end

return M
