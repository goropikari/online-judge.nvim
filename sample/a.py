# https://atcoder.jp/contests/abc380/tasks/abc380_a
import sys
if len(sys.argv) == 2:
    # for debugpy
    sys.stdin = open(sys.argv[1])

s = ''.join(sorted(input()))
if s == '122333':
    print('Yes')
else:
    print('No')
