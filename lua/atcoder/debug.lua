local M = {}

local config = require('atcoder.config')
local ok, dap = pcall(require, 'dap')
if not ok then
  return M
end

function M.setup()
  dap.adapters.atcoder_cpptools = {
    id = 'cppdbg', -- must be cppdbg
    type = 'executable',
    command = config.cpptools(),
    ---@param cfg CpptoolsDapConfig
    enrich_config = function(cfg, on_config)
      local final_config = vim.deepcopy(cfg)
      local build_command = cfg.build
      final_config.type = 'cppdbg'
      vim.system(build_command, {}, function(out)
        if out.code ~= 0 then
          vim.print(out.stderr)
          return
        end

        vim.schedule(function()
          on_config(final_config)
        end)
      end)
    end,
  }

  dap.adapters.atcoder_codelldb = {
    id = 'atcoder_codelldb',
    type = 'server',
    port = '${port}',
    executable = {
      command = config.codelldb(),
      args = { '--port', '${port}' },
    },
    ---@param cfg CodelldbDapConfig
    enrich_config = function(cfg, on_config)
      local final_config = vim.deepcopy(cfg)
      local build_command = cfg.build
      vim.system(build_command, {}, function(out)
        if out.code ~= 0 then
          vim.print(out.stderr)
          return
        end

        vim.schedule(function()
          on_config(final_config)
        end)
      end)
    end,
  }
end

return M
