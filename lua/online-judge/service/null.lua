local M = {}

function M.insert_problem_url()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, {
    string.format(vim.bo.commentstring, 'http://localhost'),
  })
end

return M
