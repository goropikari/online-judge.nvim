local M = {}

function M.download_tests_cmd(url, test_dirname)
  return {
    'bash',
    '-c',
    string.format('mkdir -p %s && touch %s/custom-1.in %s/custom-1.out', test_dirname, test_dirname, test_dirname),
  }
end

function M.insert_problem_url()
  vim.api.nvim_buf_set_lines(0, 0, 0, false, {
    string.format(vim.bo.commentstring, 'http://localhost'),
  })
end

return M
