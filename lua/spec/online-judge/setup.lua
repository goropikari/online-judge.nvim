local mock = require('luassert.mock')

describe('setup', function()
  local oj

  before_each(function()
    package.loaded['online-judge'] = nil
    oj = require('online-judge')
  end)

  it('passes viewer config to result viewer', function()
    local result_viewer = mock(require('online-judge.result_viewer'), true)
    local config = mock(require('online-judge.config'), true)
    local lang = mock(require('online-judge.language'), true)
    local debug = mock(require('online-judge.debug'), true)

    config.get.returns({
      viewer = {
        auto_open = false,
        position = 'bottom',
        width = 0.5,
        height = 0.25,
        preview_max_lines = 7,
        keymaps = {
          rerun = 'R',
        },
      },
      lang = {},
      out_dirpath = '/tmp/online-judge.nvim',
      cache_dir = '/tmp/online-judge.nvim/cache',
      define_cmds = false,
    })
    result_viewer.new.returns({
      register_rerun_fn = function() end,
      register_submit_fn = function() end,
      register_debug_fn = function() end,
    })

    oj.setup({
      viewer = {
        auto_open = false,
      },
    })

    assert.stub(result_viewer.new).was_called_with({
      auto_open = false,
      position = 'bottom',
      width = 0.5,
      height = 0.25,
      preview_max_lines = 7,
      keymaps = {
        rerun = 'R',
      },
    })

    mock.revert(result_viewer)
    mock.revert(config)
    mock.revert(lang)
    mock.revert(debug)
  end)
end)

describe('settings api', function()
  local oj

  before_each(function()
    package.loaded['online-judge'] = nil
    oj = require('online-judge')
  end)

  it('delegates grouped runtime settings', function()
    local config = mock(require('online-judge.config'), true)

    oj.settings.enable_exact_match()
    oj.settings.disable_exact_match()
    oj.settings.set_precision('1e-9')
    oj.settings.reset_precision()
    oj.settings.set_tle(10)
    oj.settings.set_mle(2048)

    assert.stub(config.enable_exact_match).was_called()
    assert.stub(config.disable_exact_match).was_called()
    assert.stub(config.set_precision).was_called_with('1e-9')
    assert.stub(config.reset_precision).was_called()
    assert.stub(config.set_tle).was_called_with(10)
    assert.stub(config.set_mle).was_called_with(2048)

    mock.revert(config)
  end)
end)
