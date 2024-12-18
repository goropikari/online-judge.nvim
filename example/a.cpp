// https://atcoder.jp/contests/abc380/tasks/abc380_a
#include <bits/stdc++.h>
using namespace std;

int main()
{
    string N;
    cin >> N;
    sort(N.begin(), N.end());
    string ans = "No";
    if (N == "122333") {
        ans = "Yes";
    }
    cout << ans << endl;
}
