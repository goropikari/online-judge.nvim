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

function M.download_tests_cmd(url, test_dirname)
  return {
    oj(),
    'download',
    url,
    '--directory',
    test_dirname,
  }
end

---@param filetype string
---@return string
local function filetype2langid(filetype)
  local data = {
    cpp = '6017', -- C++23
    python = '6083', -- pypy3
    julia = '6114', -- julia 1.9.2
  }
  return data[filetype]
end

---@param url string
---@param file_path string
---@param filetype string
function M.submit(url, file_path, filetype)
  async.void(function()
    utils.notify('submit: ' .. url)
    local out = utils.async_system({
      oj(),
      'submit',
      '-y',
      '-l',
      filetype2langid(filetype),
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

function M.insert_problem_url()
  local contest_id = utils.get_dirname()
  local problem_id = contest_id .. '_' .. utils.get_filename_without_ext()
  local url = string.format('https://atcoder.jp/contests/%s/tasks/%s', contest_id, problem_id)
  local url_line = string.format(vim.o.commentstring, url)
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { url_line })
end

return M
