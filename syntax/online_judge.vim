highlight OnlineJudgeHelp guifg=#FF8000 gui=bold
syntax keyword OnlineJudgeHelp help

highlight OnlineJudgeAccept guifg=#00FF00 gui=bold
syntax match OnlineJudgeAccept /^AC$/
syntax match OnlineJudgeAccept /test success/

highlight OnlineJudgeFailure guifg=#FF0000 gui=bold
syntax match OnlineJudgeFailure /^WA$/
syntax match OnlineJudgeFailure /^RE$/
syntax match OnlineJudgeFailure /^TLE$/
syntax match OnlineJudgeFailure /^test failed/

highlight OnlineJudgeTestFile guifg=#33FFFF gui=bold
syntax match OnlineJudgeTestFile /sample-\d\+$/
syntax match OnlineJudgeTestFile /custom-\d\+$/
syntax match OnlineJudgeTestFile /random-\d\+$/

highlight OnlineJudgeIO guifg=#FFFF00 gui=bold
syntax keyword OnlineJudgeIO input output expected

highlight OnlineJudgeProgram guifg=#66B2FF gui=bold
syntax keyword OnlineJudgeProgram contest_id problem_id test_dir file_path command
