highlight AtCoderHelp guifg=#FF8000 gui=bold
syntax keyword AtcoderHelp help

highlight AtCoderAccept guifg=#00FF00 gui=bold
syntax keyword AtcoderAccept AC
syntax match AtCoderAccept /test success/

highlight AtCoderFailure guifg=#FF0000 gui=bold
syntax keyword AtCoderFailure WA RE TLE
syntax match AtCoderFailure /test failed/

highlight AtCoderTestFile guifg=#33FFFF gui=bold
syntax match AtCoderTestFile /sample-\d\+/
syntax match AtCoderTestFile /custom-\d\+/

highlight AtCoderIO guifg=#FFFF00 gui=bold
syntax keyword AtCoderIO input output expected

highlight AtCoderProgram guifg=#6666FF gui=bold
syntax match AtCoderProgram /test_dir/
syntax match AtCoderProgram /source code/
syntax match AtCoderProgram /cmd/
