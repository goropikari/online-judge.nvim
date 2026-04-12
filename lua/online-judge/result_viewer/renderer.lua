local config = require('online-judge.config')

local M = {}

local function phase_text(phase)
  if phase == nil or phase == 'idle' then
    return 'idle'
  end
  return phase
end

---@param state table
---@return string[], table<integer, table>
function M.render(state)
  local keymaps = state.keymaps or {}
  local lines = {
    'result viewer',
    'phase: ' .. phase_text(state.phase),
    'file_path: ' .. (state.file_path or ''),
    'test_dir: ' .. (state.test_dir_path or ''),
    'command: ' .. (state.command or ''),
    'exact_match: ' .. tostring(config.exact_match()) .. ', ' .. config.precision(),
    '',
    'help',
    string.format('  %s: rerun test cases', keymaps.rerun or 'r'),
    string.format('  %s: submit with test', keymaps.submit or 's'),
    string.format('  %s: view/hide test case', keymaps.preview or '<CR>'),
    string.format('  %s: add test case', keymaps.add_case or 'a'),
    string.format('  %s: edit test case', keymaps.edit_case or 'e'),
    string.format('  %s: copy test case', keymaps.copy_case or 'c'),
    string.format('  %s: delete test case', keymaps.delete_case or 'D'),
    string.format('  %s: debug selected case', keymaps.debug_case or 'd'),
    '',
  }
  local line_map = {}

  if state.error_lines and #state.error_lines > 0 then
    table.insert(lines, 'error')
    for _, line in ipairs(state.error_lines) do
      table.insert(lines, line)
    end
  elseif state.parsed and state.parsed.cases then
    local expanded_cases = state.expanded_cases or {}
    local selected_case = state.selected_case

    for _, case_result in ipairs(state.parsed.cases) do
      local case_name = case_result.name
      local prefix = expanded_cases[case_name] and '▽ ' or '▷ '
      local rendered = prefix .. case_name
      if selected_case == case_name then
        rendered = rendered .. '  <'
      end
      line_map[#lines + 1] = {
        kind = 'case_header',
        case_name = case_name,
      }
      table.insert(lines, rendered)

      for _, detail_line in ipairs(case_result.details or {}) do
        line_map[#lines + 1] = {
          kind = 'case_detail',
          case_name = case_name,
        }
        table.insert(lines, detail_line)
      end

      if expanded_cases[case_name] and case_result.preview then
        table.insert(lines, 'input')
        line_map[#lines] = { kind = 'case_preview', case_name = case_name }
        for _, detail_line in ipairs(case_result.preview.input or {}) do
          table.insert(lines, detail_line)
          line_map[#lines] = { kind = 'case_preview', case_name = case_name }
        end
        table.insert(lines, '')
        line_map[#lines] = { kind = 'case_preview', case_name = case_name }
        table.insert(lines, 'output')
        line_map[#lines] = { kind = 'case_preview', case_name = case_name }
        for _, detail_line in ipairs(case_result.preview.output or {}) do
          table.insert(lines, detail_line)
          line_map[#lines] = { kind = 'case_preview', case_name = case_name }
        end
        table.insert(lines, '')
        line_map[#lines] = { kind = 'case_preview', case_name = case_name }
      end
    end

    for _, line in ipairs(state.parsed.summary or {}) do
      table.insert(lines, line)
    end
  elseif state.raw_lines then
    vim.list_extend(lines, state.raw_lines)
  end

  table.insert(lines, '')
  table.insert(lines, 'Executed at:')
  table.insert(lines, state.executed_at or vim.fn.strftime('%c'))

  return lines, line_map
end

return M
