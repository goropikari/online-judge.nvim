local mock = require('luassert.mock')
local stub = require('luassert.stub')

describe('public workflows', function()
  local oj
  local viewer

  before_each(function()
    package.loaded['online-judge'] = nil
    oj = require('online-judge')
    viewer = {
      register_rerun_fn = function() end,
      register_rerun_case_fn = function() end,
      register_submit_fn = function() end,
      register_debug_fn = function() end,
      get_state = function()
        return {}
      end,
    }
  end)

  local function setup_plugin()
    local result_viewer = mock(require('online-judge.result_viewer'), true)
    local config = mock(require('online-judge.config'), true)
    local lang = mock(require('online-judge.language'), true)
    local debug = mock(require('online-judge.debug'), true)

    config.get.returns({
      viewer = {},
      lang = {},
      out_dirpath = '/tmp/online-judge.nvim',
      cache_dir = '/tmp/online-judge.nvim/cache',
      define_cmds = false,
    })
    result_viewer.new.returns(viewer)

    oj.setup({})

    return result_viewer, config, lang, debug
  end

  it('runs the test workflow from the current source context', function()
    local result_viewer, config, lang, debug = setup_plugin()
    local source_context = mock(require('online-judge.source_context'), true)
    local test_flow = mock(require('online-judge.test_flow'), true)

    source_context.current.returns({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    })

    oj.test()

    assert.stub(test_flow.run).was_called_with({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    }, viewer, match.is_function())

    mock.revert(source_context)
    mock.revert(test_flow)
    mock.revert(result_viewer)
    mock.revert(config)
    mock.revert(lang)
    mock.revert(debug)
  end)

  it('starts submit-after-test from the current source context', function()
    local result_viewer, config, lang, debug = setup_plugin()
    local source_context = mock(require('online-judge.source_context'), true)
    local test_flow = mock(require('online-judge.test_flow'), true)

    source_context.current.returns({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    })

    oj.submit_with_test()

    assert.stub(test_flow.run).was_called_with({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    }, viewer, match.is_function())

    mock.revert(source_context)
    mock.revert(test_flow)
    mock.revert(result_viewer)
    mock.revert(config)
    mock.revert(lang)
    mock.revert(debug)
  end)

  it('submits after the test callback completes', function()
    local result_viewer, config, lang, debug = setup_plugin()
    local source_context = mock(require('online-judge.source_context'), true)
    local test_flow = mock(require('online-judge.test_flow'), true)
    local submission_flow = mock(require('online-judge.submission_flow'), true)
    local defer_fn = stub(vim, 'defer_fn', function(fn, _)
      fn()
    end)
    local captured_callback = nil

    test_flow.run.invokes(function(_, _, callback)
      captured_callback = callback
    end)
    source_context.current.returns({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    })

    oj.submit_with_test()
    assert.is_function(captured_callback)

    captured_callback()

    assert.stub(submission_flow.submit).was_called_with({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    }, viewer, { update_viewer_on_error = true })

    defer_fn:revert()
    mock.revert(source_context)
    mock.revert(test_flow)
    mock.revert(submission_flow)
    mock.revert(result_viewer)
    mock.revert(config)
    mock.revert(lang)
    mock.revert(debug)
  end)

  it('runs the selected test case from the current source context', function()
    local result_viewer, config, lang, debug = setup_plugin()
    local source_context = mock(require('online-judge.source_context'), true)
    local test_flow = mock(require('online-judge.test_flow'), true)

    source_context.current.returns({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    })

    oj.test_case('sample-2')

    assert.stub(test_flow.run_case).was_called_with({
      filetype = 'cpp',
      file_path = '/path/to/a.cpp',
      url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      test_dir_path = '/path/to/test_a',
    }, 'sample-2', viewer, match.is_function())

    mock.revert(source_context)
    mock.revert(test_flow)
    mock.revert(result_viewer)
    mock.revert(config)
    mock.revert(lang)
    mock.revert(debug)
  end)
end)
