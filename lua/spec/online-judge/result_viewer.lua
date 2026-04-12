local stub = require('luassert.stub')

describe('result viewer config', function()
  it('does not auto open when auto_open is false', function()
    local viewer_module = require('online-judge.result_viewer')

    local open_win = stub(vim.api, 'nvim_open_win')
    local create_autocmd = stub(vim.api, 'nvim_create_autocmd')
    local schedule = stub(vim, 'schedule', function(_) end)

    local viewer = viewer_module.new({
      auto_open = false,
    })

    viewer:update({
      file_path = '/tmp/a.cpp',
      command = 'python3 /tmp/a.cpp',
      test_dir_path = '/tmp/test_a',
      result = {},
      parsed = {
        cases = {},
        summary = {},
        raw_lines = {},
      },
    })

    assert.stub(open_win).was_not_called()

    schedule:revert()
    create_autocmd:revert()
    open_win:revert()
    vim.api.nvim_buf_delete(viewer.bufnr, { force = true })
  end)

  it('renders configured keymaps in help text', function()
    local viewer_module = require('online-judge.result_viewer')

    local create_autocmd = stub(vim.api, 'nvim_create_autocmd')
    local schedule = stub(vim, 'schedule', function(_) end)

    local viewer = viewer_module.new({
      auto_open = false,
      keymaps = {
        rerun = { keys = { 'R', '<F5>' }, desc = 'rerun tests' },
        debug_case = false,
      },
    })

    viewer:update({
      file_path = '/tmp/a.cpp',
      command = 'python3 /tmp/a.cpp',
      test_dir_path = '/tmp/test_a',
      result = {},
      parsed = {
        cases = {},
        summary = {},
        raw_lines = {},
      },
    })

    local lines = vim.api.nvim_buf_get_lines(viewer.bufnr, 0, -1, false)

    assert.is_true(vim.tbl_contains(lines, 'help {{{'))
    assert.is_true(vim.tbl_contains(lines, '  R, <F5>: rerun test cases'))
    assert.is_true(vim.tbl_contains(lines, '  : debug selected case'))
    assert.is_true(vim.tbl_contains(lines, '}}}'))

    schedule:revert()
    create_autocmd:revert()
    vim.api.nvim_buf_delete(viewer.bufnr, { force = true })
  end)
end)
