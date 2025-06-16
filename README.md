# online-judge.nvim

A Neovim plugin to streamline AtCoder/AOJ contest workflows, including test case downloads, execution, and submissions.

**Note**
This plugin has only been tested with past problems. It has not been used or verified during ongoing contests.

<https://github.com/user-attachments/assets/47aea616-c5cf-4651-b99d-21d06fab4156>

## Features

- **Download test cases** for AtCoder/AOJ problems.
- **Execute tests** and check against sample cases.
- **Submit code** directly from Neovim.

# Requirements

- Neovim 0.10+
- [online-judge-tools](https://github.com/online-judge-tools/oj)
- curl

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'goropikari/online-judge.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',

       -- optional for debug
      'mfussenegger/nvim-dap',
      'mfussenegger/nvim-dap-python',
    },

    opts = {
        ---@class PluginConfig
        ---@field oj {path:string, tle:number, mle:integer, exact_match:boolean, precision:string}
        ---@field codelldb_path string
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
pip3 install git+https://github.com/goropikari/oj
```

- **`time` command** (Optional for memory limit checks):

```bash
sudo apt-get install time
```

## Commands/API

The plugin provides the following commands:

| Command                       | Description                                |
| ----------------------------- | ------------------------------------       |
| `:OnlineJudge test`           | Run sample test cases.                     |
| `:OnlineJudge submit`         | Submit the code.                           |
| `:OnlineJudge download_tests` | Download test cases.                       |
| `:OnlineJudge atcoder_login`  | Log in to AtCoder. Required for submission |
| `:OnlineJudge aoj_login`      | Log in to AOJ. Required for submission     |
| `:OnlineJudge enable_exact_match` | Enable exact match for test cases.         |
| `:OnlineJudge disable_exact_match` | Disable exact match for test cases.        |
| `:OnlineJudge set_precision <precision>` | Set precision for floating-point comparisons. |

| API                                                 | Description                                                                                                                                                                       |
| -----------------------------                       | ------------------------------------                                                                                                                                              |
| `:lua require('online-judge').test()`               | Run sample test cases.                                                                                                                                                            |
| `:lua require('online-judge').submit()`             | Submit the code.                                                                                                                                                                  |
| `:lua require('online-judge').download_tests()`     | Download test cases.                                                                                                                                                              |
| `:lua require('online-judge').atcoder_login()`      | Log in to AtCoder. Required for submission                                                                                                                                        |
| `:lua require('online-judge').aoj_login()`          | Log in to AOJ. Required for submission                                                                                                                                            |
| `:lua require('online-judge').insert_problem_url()` | Insert AtCoder problem url. The directory name is interpreted as the contest_id. The problem_id is created by concatenating the contest_id, an underscore (_), and the file name. |

## Usage

### Download Test Cases

To download test cases, you need to add the problem URL to the first line of your source file **(e.g., `https://atcoder.jp/contests/abc380/tasks/abc380_a`)**.

Then run:

```vim
:OnlineJudge download_tests
```

### Run Sample Tests

If test cases have not been downloaded, they will be downloaded automatically.

Run:

```vim
:OnlineJudge test
```

### Submit Code

Run the following command to submit:

```vim
:OnlineJudge submit
```

## Customization

### Language Support

You can extend or customize supported languages in the `setup()` function:

```lua
{
    'goropikari/online-judge.nvim',
    opts = {
        oj = {
            path = 'oj',
            tle = 5, -- sec
            mle = 1024, -- mega byte
            exact_match = true,
            precision = '1e-6', -- for floating-point comparisons
        },
        codelldb_path = vim.fn.exepath('codelldb'),

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
                build = nil, -- use default fn if build is nil
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
                atcoder_lang_id = 5078, -- pypy3
                aoj_lang_id = 'PyPy3',
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
