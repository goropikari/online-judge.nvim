local M = {}

---@class Service
---@field login fun()
---@field download_tests_cmd fun(url:string, test_dirname:string):string[]
---@field submit fun(url:string, file_path:string, filetype:string)
---@field insert_problem_url fun()

---@param url string
---@return Service
function M.resolve(url)
  return require('online-judge.service.common').create_service(url)
end

return M
