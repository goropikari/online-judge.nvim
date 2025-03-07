local M = {}

---@class Service
---@field login fun()
---@field download_tests_cmd fun(url:string, test_dirname:string):string[]
---@field submit fun(url:string, file_path:string, filetype:string)
---@field insert_problem_url fun()

---@return Service
function M.create_service(url)
  if string.match(url, 'atcoder.jp') then
    return require('online-judge.service.atcoder')
  elseif string.match(url, 'u-aizu.ac.jp') then
    return require('online-judge.service.aoj')
  elseif string.match(url, 'judge.yosupo.jp') or string.match(url, 'localhost:5173') then
    return require('online-judge.service.yosupo')
  else
    return require('online-judge.service.null')
  end
end

return M
