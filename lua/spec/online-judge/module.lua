local mock = require('luassert.mock')

describe('download_test', function()
  local oj = require('online-judge')

  it('already test dir exists', function()
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)

    io.isdirectory.returns(true)
    utils.get_absolute_path.returns('dummy_path')
    utils.get_problem_url.returns('https://example.com')
    utils.get_test_dirname.returns('dummy_test_dirname')

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files are already downloaded', opts.stdout)
    end

    oj.download_tests(callback)

    -- mock.revert(io)
    mock.revert(io)
    mock.revert(utils)
  end)

  it('download sample tests', function()
    -- arrange
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local cfg = mock(require('online-judge.config'), true)

    io.isdirectory.returns(false)
    utils.get_absolute_path.returns('dummy_path')
    utils.get_problem_url.returns('https://example.com')
    utils.get_test_dirname.returns('dummy_test_dirname')
    utils.async_system.returns({
      code = 0,
      stdout = 'test files downloaded',
    })
    cfg.oj.returns('dummy_oj')

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test files downloaded', opts.stdout)
    end

    -- act
    oj.download_tests(callback)

    -- assert
    assert.stub(utils.async_system).was_called_with({
      'dummy_oj',
      'download',
      'https://example.com',
      '--directory',
      'dummy_test_dirname',
    })

    mock.revert(io)
    mock.revert(utils)
  end)

  it('no problem url error', function()
    -- arrange
    local io = mock(require('online-judge.io'), true)
    local utils = mock(require('online-judge.utils'), true)
    local cfg = mock(require('online-judge.config'), true)

    io.isdirectory.returns(false)
    utils.get_absolute_path.returns('dummy_path')
    utils.get_problem_url.returns('')
    utils.get_test_dirname.returns('dummy_test_dirname')
    utils.async_system.returns({
      code = 0,
      stdout = 'test files downloaded',
    })
    cfg.oj.returns('dummy_oj')

    local callback = function(opts)
      assert.equals(1, opts.code)
      assert.equals('url is not written', opts.stderr)
    end

    -- act
    oj.download_tests(callback)

    -- assert
    assert.stub(utils.async_system).was_not_called_with()

    mock.revert(io)
    mock.revert(utils)
  end)
end)

describe('execute_test', function()
  local oj = require('online-judge')

  it('execute test', function()
    -- arrange
    local utils = mock(require('online-judge.utils'), true)
    local cfg = mock(require('online-judge.config'), true)

    local mle = 1024
    local tle = 5

    utils.async_system.returns({
      code = 0,
      stdout = 'line1\nline2',
    })
    utils.executable.returns(true)
    cfg.oj.returns('dummy_oj')
    cfg.tle.returns(tle)
    cfg.mle.returns(mle)

    local callback = function(opts)
      assert.equals(0, opts.code)
      assert.equals('test result', opts.stdout)
      assert.equals({ 'line1', 'line2' }, opts.result)
    end

    -- act
    oj._execute_test('dummy_test_dirname', 'dummy command', callback)

    -- assert
    assert.stub(utils.async_system).was_called_with({
      'dummy_oj',
      'test',
      '--error',
      '1e-6',
      '--tle',
      tle,
      '--directory',
      'dummy_test_dirname',
      '-c',
      'dummy command',
      '--mle',
      mle,
    })

    mock.revert(utils)
    mock.revert(cfg)
  end)
end)

describe('submission', function()
  local oj = require('online-judge')

  describe('prepare_submit_info', function()
    it('for cpp', function()
      -- arrange
      local utils = mock(require('online-judge.utils'), true)

      local file_path = '/path/to/a.cpp'
      local url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a'
      utils.get_absolute_path.returns(file_path)
      utils.get_problem_url.returns(url)
      utils.get_filetype.returns('cpp')

      -- act
      local res = oj._prepare_submit_info()

      -- assert
      assert.are.same({
        aoj_lang_id = 'C++23',
        atcoder_lang_id = 5028,
        file_path = file_path,
        url = url,
      }, res)

      mock.revert(utils)
    end)

    it('for python', function()
      -- arrange
      local utils = mock(require('online-judge.utils'), true)

      local file_path = '/path/to/a.py'
      local url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a'
      utils.get_absolute_path.returns(file_path)
      utils.get_problem_url.returns(url)
      utils.get_filetype.returns('python')

      -- act
      local res = oj._prepare_submit_info()

      -- assert
      assert.are.same({
        aoj_lang_id = 'PyPy3',
        atcoder_lang_id = 5078,
        file_path = file_path,
        url = url,
      }, res)

      mock.revert(utils)
    end)
  end)

  describe('_submit', function()
    it('submit atcoder', function()
      -- arrange
      local atcoder = mock(require('online-judge.service.atcoder'), true)

      vim.fn.setenv('ONLINE_JUDGE_FORCE_SUBMISSION', '1')
      local path = '/path/to/a.cpp'
      local url = 'https://atcoder.jp/contests/abc380/tasks/abc380_a'
      local atcoder_lang_id = 5028

      -- act
      oj._submit({
        aoj_lang_id = '',
        atcoder_lang_id = atcoder_lang_id,
        file_path = path,
        url = url,
      })

      -- assert
      assert.stub(atcoder.submit).was_called_with(url, path, atcoder_lang_id)

      mock.revert(atcoder)
    end)

    it('submit aoj', function()
      -- arrange
      local aoj = mock(require('online-judge.service.aoj'), true)

      vim.fn.setenv('ONLINE_JUDGE_FORCE_SUBMISSION', '1')
      local path = '/path/to/a.cpp'
      local url = 'https://onlinejudge.u-aizu.ac.jp/courses/lesson/2/ITP1/1/ITP1_1_A'
      local aoj_lang_id = 'C++23'

      -- act
      oj._submit({
        aoj_lang_id = aoj_lang_id,
        atcoder_lang_id = 0,
        file_path = path,
        url = url,
      })

      -- assert
      assert.stub(aoj.submit).was_called_with(url, path, aoj_lang_id)

      mock.revert(aoj)
    end)
  end)
end)
