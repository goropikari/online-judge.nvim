local M = {}

local async = require('plenary.async')
local cfg = require('online-judge.config')
local utils = require('online-judge.utils')

local system = function(cmd, cb)
  return vim.system(cmd, { text = true }, cb)
end

local session_file = cfg.cache_to('aoj_session.txt')
local state = {
  user_id = nil,
}

local function user_id()
  return state.user_id
end

local function api_path(path)
  return vim.fs.joinpath('https://judgeapi.u-aizu.ac.jp', path)
end

function M.login()
  local uid = vim.fn.input('user id: ')
  local password = vim.fn.inputsecret('password: ')

  local req = {
    id = uid,
    password = password,
  }

  system({
    'curl',
    '-H',
    'Content-Type: application/json;charset=UTF-8',
    '-c',
    session_file,
    '-d',
    vim.json.encode(req),
    api_path('/session'),
  }, function(out)
    if out.code ~= 0 then
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      vim.fn.setfperm(session_file, 'rw-------')
    end)
    utils.notify('Logged in', vim.log.levels.INFO)
  end)
end

function M.logout()
  system({
    'curl',
    '-X',
    'DELETE',
    '-b',
    session_file,
    api_path('/session'),
  }, function(out)
    if out.code ~= 0 then
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end
    vim.fn.delete(session_file)
  end)
end

function M.submit(url, file_path, lang_id)
  utils.notify('Submitting to AOJ...', vim.log.levels.INFO)
  local problem_id = vim.fn.fnamemodify(url, ':t')
  local req = {
    problemId = problem_id,
    language = lang_id,
    sourceCode = vim.fn.join(vim.fn.readfile(file_path), '\n'),
  }

  async.void(function()
    local out = nil

    local uid = user_id()
    if not uid then
      out = utils.async_system({
        'curl',
        '-b',
        session_file,
        api_path('/self'),
      })
      if out.code ~= 0 then
        utils.notify(out.stderr, vim.log.levels.ERROR)
        return
      end
      local res = vim.json.decode(out.stdout)
      if res.id then
        state.user_id = res.id
        uid = res.id
      else
        utils.notify('Not logged in', vim.log.levels.ERROR)
        return
      end
    end

    out = utils.async_system({
      'curl',
      '-H',
      'Content-Type: application/json;charset=UTF-8',
      '-b',
      session_file,
      '-d',
      vim.json.encode(req),
      api_path('/submissions'),
    })

    if out.code ~= 0 then
      utils.notify(out.stderr, vim.log.levels.ERROR)
      return
    end

    local res = vim.json.decode(out.stdout)
    local token = res.token

    local timer = vim.uv.new_timer()
    timer:start(
      1000,
      1500,
      async.void(function()
        local recent_submissions = utils.async_system({
          'curl',
          '-b',
          session_file,
          api_path('/submission_records/recent'),
        })

        if recent_submissions.code ~= 0 then
          utils.notify(recent_submissions.stderr, vim.log.levels.ERROR)
          return
        end

        local submissions = vim.json.decode(recent_submissions.stdout)
        for _, submission in ipairs(submissions) do
          if submission.token == token then
            if not (submission.status == 5 or submission.status == 9) then
              local status_url = string.format(
                'https://onlinejudge.u-aizu.ac.jp/status/users/%s/submissions/1/%s/judge/%s/%s',
                submission.userId,
                submission.problemId,
                submission.judgeId,
                submission.language
              )

              vim.ui.open(status_url)
              utils.notify('Submitted: ' .. status_url, vim.log.levels.INFO)
              if submission.status == 4 then
                utils.notify('Accepted', vim.log.levels.INFO)
              else
                utils.notify('Failed', vim.log.levels.ERROR)
              end
              timer:close()
            end
          end
        end
      end)
    )
  end)()
end

return M
