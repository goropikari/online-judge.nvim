local async = require('plenary.async')
local system = async.wrap(vim.system, 3)

local M = {}

function M.new()
  ---@class Database
  ---@field database_path string
  local obj = {
    database_path = vim.fn.stdpath('cache') .. '/atcoder.nvim/atcoder.db',
  }
  vim.fn.mkdir(vim.fn.fnamemodify(obj.database_path, ':h'), 'p')

  function obj.open(self)
    vim.cmd('term sqlite3 ' .. self.database_path)
  end

  function obj.update_contest_data(self)
    local database_path = self.database_path
    local problems_csv = os.tmpname()
    async.void(function()
      local out = system({
        'rm',
        '-f',
        database_path,
      })
      if out.code ~= 0 then
        vim.notify(out.stderr, vim.log.levels.WARN)
        return
      end

      local get_res = system({
        'curl',
        '-s',
        '--compressed',
        'https://kenkoooo.com/atcoder/resources/problems.json',
        -- 'cat',
        -- problems.json,
      })
      if get_res.code ~= 0 then
        vim.notify(get_res.stderr, vim.log.levels.WARN)
        return
      end

      local json_to_csv_res = system({
        'jq',
        '-r',
        '.[]|[.id, .contest_id, .problem_index, .name, .title]|@csv',
      }, {
        stdin = get_res.stdout,
      })
      if json_to_csv_res.code ~= 0 then
        vim.notify(json_to_csv_res.stderr, vim.log.levels.WARN)
        return
      end

      local file = io.open(problems_csv, 'w')
      if file ~= nil then
        file:write('"id","contest_id","problem_index","name","title"\n')
        file:write(json_to_csv_res.stdout)
        file:close()
      end

      local import_csv_res = system({
        'sqlite3',
        '-separator',
        ',',
        database_path,
        '.import ' .. problems_csv .. ' problems',
      })
      if import_csv_res.code ~= 0 then
        vim.notify(import_csv_res.stderr, vim.log.levels.WARN)
      end
      vim.notify('finish updating atcoder.db')
    end)()
  end

  ---@return boolean
  function obj.exist_contest_id(self, contest_id)
    local res = vim
      .system({
        'sqlite3',
        self.database_path,
        string.format("SELECT EXISTS (SELECT * FROM problems WHERE contest_id = '%s')", contest_id),
      })
      :wait()
    if res.code ~= 0 then
      vim.notify('failed to read database: ' .. contest_id, vim.log.levels.WARN)
      return false
    end

    return vim.trim(res.stdout) == '1'
  end

  ---@return string|nil
  function obj.get_problem_id(self, contest_id, problem_index)
    local out = vim
      .system({
        'sqlite3',
        self.database_path,
        string.format("SELECT id FROM problems WHERE contest_id = '%s' AND lower(problem_index) = '%s'", contest_id, string.lower(problem_index)),
      })
      :wait()
    if out.code ~= 0 then
      vim.notify('failed to read database: ' .. contest_id, vim.log.levels.WARN)
      return nil
    end

    return vim.trim(out.stdout)
  end

  return obj
end

return M
