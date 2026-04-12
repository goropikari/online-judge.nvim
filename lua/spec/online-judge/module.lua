local mock = require('luassert.mock')

describe('download_test', function()
  local oj = require('online-judge')

  it('already test dir exists', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local source_context = mock(require('online-judge.source_context'), true)

    io.isdirectory.returns(true)
    source_context.current.returns({
      url = 'https://example.com',
      test_dir_path = 'dummy_test_dirname',
    })

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files are already downloaded', opts.stdout)
    end

    oj.download_tests(callback)

    mock.revert(io)
    mock.revert(utils)
    mock.revert(source_context)
  end)

  it('download sample tests', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local cfg = mock(require('online-judge.config'), true)
    local source_context = mock(require('online-judge.source_context'), true)

    io.isdirectory.returns(false)
    utils.async_system.returns({
      code = 0,
      stdout = 'test files downloaded',
    })
    cfg.oj.returns('dummy_oj')
    source_context.current.returns({
      url = 'https://example.com',
      test_dir_path = 'dummy_test_dirname',
    })

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files downloaded', opts.stdout)
    end

    oj.download_tests(callback)

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
    mock.revert(source_context)
  end)

  it('no problem url error', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local source_context = mock(require('online-judge.source_context'), true)

    io.isdirectory.returns(false)
    source_context.current.returns({
      url = '',
      test_dir_path = 'dummy_test_dirname',
    })

    local callback = function(opts)
      assert.equals(1, opts.code)
      assert.equals('url is not written', opts.stderr)
    end

    oj.download_tests(callback)

    assert.stub(utils.async_system).was_not_called()

    mock.revert(io)
    mock.revert(utils)
    mock.revert(source_context)
  end)

  it('refreshes only sample tests', function()
    local sample_manager = mock(require('online-judge.sample_manager'), true)
    local source_context = mock(require('online-judge.source_context'), true)
    local service_common = mock(require('online-judge.service.common'), true)
    local utils = mock(require('online-judge.utils'), true)

    source_context.current.returns({
      url = 'https://example.com',
      test_dir_path = 'dummy_test_dirname',
    })
    service_common.create_service.returns({
      download_tests_cmd = function(_, _, dir)
        return { 'oj', 'download', '--directory', dir }
      end,
    })
    utils.async_system.returns({
      code = 0,
      stdout = 'test files downloaded',
      stderr = '',
      signal = 0,
    })

    local callback = function(opts)
      assert.equals(0, opts.code)
    end

    oj.refresh_samples(callback)

    assert.stub(sample_manager.remove_sample_cases).was_called_with('dummy_test_dirname')
    assert.stub(sample_manager.normalize_samples).was_called_with('dummy_test_dirname')

    mock.revert(sample_manager)
    mock.revert(source_context)
    mock.revert(service_common)
    mock.revert(utils)
  end)
end)

describe('submission', function()
  local oj = require('online-judge')

  describe('submit', function()
    it('delegates current source context to submission_flow', function()
      local source_context = mock(require('online-judge.source_context'), true)
      local submission_flow = mock(require('online-judge.submission_flow'), true)

      source_context.current.returns({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
        test_dir_path = '/path/to/test_a',
      })

      oj.submit()

      assert.stub(submission_flow.submit).was_called_with({
        filetype = 'cpp',
        file_path = '/path/to/a.cpp',
        url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a',
        test_dir_path = '/path/to/test_a',
      }, match.is_table())

      mock.revert(source_context)
      mock.revert(submission_flow)
    end)
  end)
end)
