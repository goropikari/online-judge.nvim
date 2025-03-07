local M = {}

function M.login() end

---@param test_dirname string
function M.download_tests_cmd(_, test_dirname)
  return {
    'bash',
    '-c',
    string.format('mkdir -p %s && touch %s/custom-1.in %s/custom-1.out', test_dirname, test_dirname, test_dirname),
  }
end

function M.submit() end

function M.insert_problem_url()
  vim.api.nvim_buf_set_lines(0, 0, 0, false, {
    string.format(vim.bo.commentstring, 'http://localhost'),
  })
end

return M
