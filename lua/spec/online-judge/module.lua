local mock = require('luassert.mock')

describe('download_test', function()
  local oj = require('online-judge')

  it('already test dir exists', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)

    io.isdirectory.returns(true)

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files are already downloaded', opts.stdout)
    end

    oj._download_tests('https://example.com', 'dummy_test_dirname', callback)

    mock.revert(io)
    mock.revert(utils)
  end)

  it('download sample tests', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local cfg = mock(require('online-judge.config'), true)

    io.isdirectory.returns(false)
    utils.async_system.returns({
      code = 0,
      stdout = 'test files downloaded',
    })
    cfg.oj.returns('dummy_oj')

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files downloaded', opts.stdout)
    end

    oj._download_tests('https://example.com', 'dummy_test_dirname', callback)

    assert.stub(utils.async_system).was_called_with({
      'dummy_oj',
      'download',
      'https://example.com',
      '--directory',
      'dummy_test_dirname',
    })

    mock.revert(io)
    mock.revert(utils)
    mock.revert(cfg)
  end)

  it('no problem url error', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)

    io.isdirectory.returns(false)

    local callback = function(opts)
      assert.equals(1, opts.code)
      assert.equals('url is not written', opts.stderr)
    end

    oj._download_tests('', 'dummy_test_dirname', callback)

    assert.stub(utils.async_system).was_not_called()

    mock.revert(io)
    mock.revert(utils)
  end)
end)

describe('submission', function()
  local oj = require('online-judge')

  describe('prepare_submit_info', function()
    it('returns current source context', function()
      local source_context = mock(require('online-judge.source_context'), true)

      source_context.current.returns({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      })

      local res = oj._prepare_submit_info()

      assert.are.same({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      }, res)

      mock.revert(source_context)
    end)
  end)

  describe('_submit', function()
    it('delegates to submission_flow', function()
      local submission_flow = mock(require('online-judge.submission_flow'), true)
      local utils = mock(require('online-judge.utils'), true)

      oj._submit({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
      })

      assert.stub(submission_flow.submit).was_called_with({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
        test_dir_path = utils.get_test_dirname('/path/to/a.cpp'),
      }, match.is_table())

      mock.revert(submission_flow)
      mock.revert(utils)
    end)
  end)
end)
