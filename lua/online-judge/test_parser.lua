local M = {}

local case_name_pattern = '([%a][%w%-_]*%d+)'
local case_pattern = '^%[(%w+)%]%s(' .. case_name_pattern .. ')$'

local function normalize_line(line)
  return ((line or ''):gsub('^%[%u+%]%s+', ''))
end

local function is_summary_line(line)
  line = normalize_line(line)
  return line:match('^slowest:')
    or line:match('^max memory:')
    or line:match('^test success:')
    or line:match('^online%-judge%-tools ')
    or line:match('^%d+ cases found$')
end

---@class ParsedTestCase
---@field name string
---@field status string
---@field raw_lines string[]
---@field details string[]
---@field preview {input:string[], output:string[]}|nil

---@class ParsedTestResult
---@field raw_lines string[]
---@field cases ParsedTestCase[]
---@field summary string[]

---@param stdout string
---@return ParsedTestResult
function M.parse(stdout)
  local raw_lines = vim.split(stdout or '', '\n', { plain = true })
  local cases = {}
  local summary = {}
  local current_case = nil

  for _, line in ipairs(raw_lines) do
    local status, name = line:match(case_pattern)
    if status and name then
      current_case = {
        name = name,
        status = status,
        raw_lines = { line },
        details = {},
        preview = nil,
      }
      table.insert(cases, current_case)
    elseif current_case and not is_summary_line(line) then
      table.insert(current_case.raw_lines, line)
      table.insert(current_case.details, normalize_line(line))
    else
      current_case = nil
      table.insert(summary, normalize_line(line))
    end
  end

  return {
    raw_lines = raw_lines,
    cases = cases,
    summary = summary,
  }
end

return M
