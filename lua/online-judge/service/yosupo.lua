local M = {}

local async = require('plenary.async')
local utils = require('online-judge.utils')

function M.download_tests_cmd(url, test_dirname)
  return {
    'yosupocl',
    'download-test',
    url,
    test_dirname,
  }
end

local function filetype2langid(filetype)
  local data = {
    cpp = 'cpp',
    python = 'pypy3',
  }
  return data[filetype]
end

---@param url string
---@param file_path string
---@param filetype string
function M.submit(url, file_path, filetype)
  utils.notify('Submitting to yosupo judge...', vim.log.levels.INFO)

  async.void(function()
    local out = utils.async_system({
      'yosupocl',
      'submit',
      url,
      file_path,
      filetype2langid(filetype),
    })

    if out.code ~= 0 then
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end

    utils.notify(out.stdout, vim.log.levels.INFO)
    vim.ui.open(out.stdout)
  end)()
end

function M.insert_problem_url()
  local name = vim.fn.expand('%:p:t:r')
  vim.api.nvim_buf_set_lines(0, 0, 0, false, {
    string.format(vim.bo.commentstring, 'http://localhost:5173/problem/' .. name),
  })
end

return M
