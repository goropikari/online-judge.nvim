highlight AtCoderHelp guifg=#FF8000 gui=bold
syntax keyword AtcoderHelp help

highlight AtCoderAccept guifg=#00FF00 gui=bold
syntax keyword AtcoderAccept AC
syntax match AtCoderAccept /test success/

highlight AtCoderFailure guifg=#FF0000 gui=bold
syntax keyword AtCoderFailure WA RE TLE
syntax match AtCoderFailure /test failed/

highlight AtCoderTestFile guifg=#33FFFF gui=bold
syntax match AtCoderTestFile /sample-.*/
syntax match AtCoderTestFile /custom-.*/

highlight AtCoderIO guifg=#FFFF00 gui=bold
syntax keyword AtCoderIO input output expected
