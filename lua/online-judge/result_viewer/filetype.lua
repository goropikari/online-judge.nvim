local M = {}

M.buf_filetype = 'online_judge'

function M.is_result_viewer_buf(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_get_option_value('filetype', { buf = bufnr }) == M.buf_filetype
end

return M
