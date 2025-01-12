highlight AtCoderHelp guifg=#FF8000 gui=bold
syntax keyword AtcoderHelp help

highlight AtCoderAccept guifg=#00FF00 gui=bold
syntax match AtcoderAccept /^AC$/
syntax match AtCoderAccept /test success/

highlight AtCoderFailure guifg=#FF0000 gui=bold
syntax match AtCoderFailure /^WA$/
syntax match AtCoderFailure /^RE$/
syntax match AtCoderFailure /^TLE$/
syntax match AtCoderFailure /^test failed/

highlight AtCoderTestFile guifg=#33FFFF gui=bold
syntax match AtCoderTestFile /sample-\d\+$/
syntax match AtCoderTestFile /custom-\d\+$/

highlight AtCoderIO guifg=#FFFF00 gui=bold
syntax keyword AtCoderIO input output expected

highlight AtCoderProgram guifg=#66B2FF gui=bold
syntax keyword AtCoderProgram contest_id problem_id test_dir file_path command
