# atcoder.nvim

A Neovim plugin to streamline AtCoder contest workflows, including test case downloads, execution, and submissions.

**Note**
This plugin has only been tested with past problems. It has not been used or verified during ongoing contests.

https://github.com/user-attachments/assets/71ccb4c6-af46-4e8e-88e6-278e45b790ee


## Features
- **Download test cases** for AtCoder problems.
- **Execute tests** and check against sample cases.
- **Submit code** directly from Neovim.


# Requirements
- Neovim 0.10+
- [online-judge-tools](https://github.com/online-judge-tools/oj)
- sqlite3

## Installation
Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'goropikari/atcoder.nvim',
    opts = {
        ---@class PluginConfig
        ---@field oj {path:string, tle:number, mle:integer}
        ---@field codelldb_path string
        ---@field cpptools_path string
        ---@field define_cmds boolean
        ---@field lang {string:LanguageOption}
    },
}
```

## Prerequisites
- **`online-judge-tools`** (oj): Install it with pip.
```bash
python3 -m venv venv
source venv/bin/activate
pip3 install git+https://github.com/online-judge-tools/oj@v12.0.0
```
- **`time` command** (Optional for memory limit checks):
```bash
sudo apt-get install time
```

## Commands
The plugin provides the following commands:

| Command                        | Description                                |
| -----------------------------  | ------------------------------------       |
| `:AtCoder test`                | Run sample test cases.                     |
| `:AtCoder submit`              | Submit the code.                           |
| `:AtCoder download_tests`      | Download test cases.                       |
| `:AtCoder login`               | Log in to AtCoder. Required for submission |
| `:AtCoder update_contest_data` | Update contest data from database.         |
| `:AtCoder open_database`       | Open contest problem database.             |

## Usage
### Download Test Cases

To download test cases, you need to:
1. Add the problem URL to the first line of your source file **(e.g., `https://atcoder.jp/contests/abc380/tasks/abc380_a`)**.
   - OR -
2. Set the **directory name** to the `contest_id` (e.g., `abc123`) and the **file name** to the `problem_index` (e.g., `a`).

Then run:

```vim
:AtCoder download_tests
```

### Run Sample Tests

If test cases have not been downloaded, they will be downloaded automatically.

Run:
```vim
:AtCoder test
```

### Submit Code
Run the following command to submit:
```vim
:AtCoder submit
```

## Customization
### Language Support
You can extend or customize supported languages in the `setup()` function:

```lua
{
    'goropikari/atcoder.nvim',
    opts = {
        ---@class LanguageOption
        ---@field build fun(cfg:BuildConfig, callback:fun(cfg:BuildConfig))
        ---@field command fun(cfg:BuildConfig): string
        ---@field dap_config fun(cfg:DebugConfig): table
        ---@field id integer

        ---@class BuildConfig
        ---@field file_path string

        ---@class DebugConfig
        ---@field file_path_path string
        ---@field input_test_file_path string

        ---@type {<filetype>:LanguageOption}
        lang = {
            -- e.g.,
            python = {
                build = nil, -- use default fn
                command = function(cfg)
                  return 'python3 ' .. cfg.file_path
                end,
                dap_config = function(cfg)
                  return {
                    name = 'python debug for atcoder',
                    type = 'python',
                    request = 'launch',
                    program = cfg.file_path_path,
                    args = { cfg.input_test_file_path },
                  }
                end,
                id = 5078, -- pypy3
            }
        }
    },
}
```

## Limitations
- This plugin does not support operating systems other than Linux.
- Only Python and C++ language settings are officially supported.

## License
This project is licensed under the MIT License.
