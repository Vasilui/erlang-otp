  {0, "(a*)\\1\\1(a*)\\2\\2\\2", "aaaaaa"},
  {0, "(a*)(a*)\\1\\2", "aaaa"},
  {0, "(a*)\\1(a*)\\2\\2", "aaaa"},
  {0, "(a*)\\1\\1(a*)", "aaaaaa"},
  {0, "(a*)\\1\\1(a*)\\2", "aaaaaa"},
  {0, "(a*)\\1\\1(a*)\\2\\2", "aaaaaa"},
  {0, "(.*)\\1\\1(.*)\\2\\2\\2", "aaaaaa"},
  {0, "(.*)\\1\\1(.*)\\2\\2\\2", "aaaaaaa"},
  {0, "(.*)\\1\\1(.*)\\2\\2\\2", "aaaaaa"},
  {0, "(.*)\\1\\1(.*)\\2\\2\\2", "aaaaaaa"},
  {0, "(.*)\\1\\1(.*)\\2\\2\\2", "aaaaa"},
  {0, "a*a*a*a*", "aaaaaa"},
  {0, "a*a*a*a*a*", "aaaaaa"},
  {0, "a*a*a*a*a*a*", "aaaaaa"},
  {0, "a*a*a*a*a*a*a*", "aaaaaa"},
  {0, "", ""},
  {0, "(a.*bcde|a.*cde|a.*de|a.*e)(a.*b|a.*c|a.*d|a.*e)\\1", "abcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdeabcdf"},
  {0, "b{0,6}", ""},
  {1, "ab{0,0}c", "abc"},
  {1, "ab{1,1}c", "abbc"},
  {1, "ab{3,7}c", "abbbbbbbbc"},
  {1, "ab{3,7}c", "abbbbbbbbbc"},
  {1, "ab{3,7}c", "abbbbbbbbbbc"},
  {1, "ab{3,7}c", "abbbbbbbbbbbc"},
  {0, "b{2,7}", "bb"},
  {1, "b{1,6}", ""},
  {0, "b{1,6}", "b"},
  {1, "b{2,7}", "b"},
  {0, "ab{0,7}c", "ac"},
  {0, "ab{1,7}c", "abc"},
  {0, "ab{2,7}c", "abbc"},
  {0, "ab{3,7}c", "abbbc"},
  {0, "ab{3,7}c", "abbbbc"},
  {0, "ab{3,7}c", "abbbbbc"},
  {0, "ab{3,7}c", "abbbbbbc"},
  {0, "ab{3,7}c", "abbbbbbbc"},
  {1, "ab{3,7}c", "abbbbbbbbc"},
  {1, "ab{3,7}c", "abbc"},
  {1, "ab{3,7}c", "abc"},
  {1, "[]][[.].]][[.right-square-bracket.]]	a]]]", "foo"},
  {0, "a*a*", "aaaaaa"},
  {0, "a*a*a*", "aaaaaa"},
  {0, "(.*)\\1\\1", "aaa"},
  {0, "(a|b)*c|(a|ab)*c", "xc"},
  {0, "(a)*", "b"},
  {0, "(..)*(...)*", "a"},
  {0, "(..)*(...)*", "abc"},
  {0, "(.*)*\\1", "xx"},
  {0, "^", ""},
  {0, "$", ""},
  {0, "^$", ""},
  {0, "^a$", "a"},
  {0, "abc", "abc"},
  {1, "abc", "xbc"},
  {1, "abc", "axc"},
  {1, "abc", "abx"},
  {0, "abc", "xabcy"},
  {0, "abc", "ababc"},
  {0, "ab*c", "abc"},
  {0, "ab*bc", "abc"},
  {0, "ab*bc", "abbc"},
  {0, "ab*bc", "abbbbc"},
  {0, "ab+bc", "abbc"},
  {1, "ab+bc", "abc"},
  {1, "ab+bc", "abq"},
  {0, "ab+bc", "abbbbc"},
  {0, "ab?bc", "abbc"},
  {0, "ab?bc", "abc"},
  {1, "ab?bc", "abbbbc"},
  {0, "ab?c", "abc"},
  {0, "^abc$", "abc"},
  {1, "^abc$", "abcc"},
  {0, "^abc", "abcc"},
  {1, "^abc$", "aabc"},
  {0, "abc$", "aabc"},
  {0, "^", "abc"},
  {0, "$", "abc"},
  {0, "a.c", "abc"},
  {0, "a.c", "axc"},
  {0, "a.*c", "axyzc"},
  {1, "a.*c", "axyzd"},
  {1, "a[bc]d", "abc"},
  {0, "a[bc]d", "abd"},
  {1, "a[b-d]e", "abd"},
  {0, "a[b-d]e", "ace"},
  {0, "a[b-d]", "aac"},
  {0, "a[-b]", "a-"},
  {0, "a[b-]", "a-"},
  {1, "a[b-a]", "-"},
  {2, "a[]b", "-"},
  {2, "a[", "-"},
  {0, "a]", "a]"},
  {0, "a[]]b", "a]b"},
  {0, "a[^bc]d", "aed"},
  {1, "a[^bc]d", "abd"},
  {0, "a[^-b]c", "adc"},
  {1, "a[^-b]c", "a-c"},
  {1, "a[^]b]c", "a]c"},
  {0, "a[^]b]c", "adc"},
  {0, "ab|cd", "abc"},
  {0, "ab|cd", "abcd"},
  {0, "()ef", "def"},
  {0, "()*", "-"},
  {1, "*a", "-"},
  {0, "^*", "-"},
  {0, "$*", "-"},
  {1, "(*)b", "-"},
  {1, "$b", "b"},
  {2, "a\\", "-"},
  {0, "a\\(b", "a(b"},
  {0, "a\\(*b", "ab"},
  {0, "a\\(*b", "a((b"},
  {1, "a\\x", "a\\x"},
  {1, "abc)", "-"},
  {2, "(abc", "-"},
  {0, "((a))", "abc"},
  {0, "(a)b(c)", "abc"},
  {0, "a+b+c", "aabbabc"},
  {0, "a**", "-"},
  {0, "a*?", "-"},
  {0, "(a*)*", "-"},
  {0, "(a*)+", "-"},
  {0, "(a|)*", "-"},
  {0, "(a*|b)*", "-"},
  {0, "(a+|b)*", "ab"},
  {0, "(a+|b)+", "ab"},
  {0, "(a+|b)?", "ab"},
  {0, "[^ab]*", "cde"},
  {0, "(^)*", "-"},
  {0, "(ab|)*", "-"},
  {2, ")(", "-"},
  {1, "abc", ""},
  {1, "abc", ""},
  {0, "a*", ""},
  {0, "([abc])*d", "abbbcd"},
  {0, "([abc])*bcd", "abcd"},
  {0, "a|b|c|d|e", "e"},
  {0, "(a|b|c|d|e)f", "ef"},
  {0, "((a*|b))*", "-"},
  {0, "abcd*efg", "abcdefg"},
  {0, "ab*", "xabyabbbz"},
  {0, "ab*", "xayabbbz"},
  {0, "(ab|cd)e", "abcde"},
  {0, "[abhgefdc]ij", "hij"},
  {1, "^(ab|cd)e", "abcde"},
  {0, "(abc|)ef", "abcdef"},
  {0, "(a|b)c*d", "abcd"},
  {0, "(ab|ab*)bc", "abc"},
  {0, "a([bc]*)c*", "abc"},
  {0, "a([bc]*)(c*d)", "abcd"},
  {0, "a([bc]+)(c*d)", "abcd"},
  {0, "a([bc]*)(c+d)", "abcd"},
  {0, "a[bcd]*dcdcde", "adcdcde"},
  {1, "a[bcd]+dcdcde", "adcdcde"},
  {0, "(ab|a)b*c", "abc"},
  {0, "((a)(b)c)(d)", "abcd"},
  {0, "[A-Za-z_][A-Za-z0-9_]*", "alpha"},
  {0, "^a(bc+|b[eh])g|.h$", "abh"},
  {0, "(bc+d$|ef*g.|h?i(j|k))", "effgz"},
  {0, "(bc+d$|ef*g.|h?i(j|k))", "ij"},
  {1, "(bc+d$|ef*g.|h?i(j|k))", "effg"},
  {1, "(bc+d$|ef*g.|h?i(j|k))", "bcdd"},
  {0, "(bc+d$|ef*g.|h?i(j|k))", "reffgz"},
  {1, "((((((((((a))))))))))", "-"},
  {0, "(((((((((a)))))))))", "a"},
  {1, "multiple words of text", "uh-uh"},
  {0, "multiple words", "multiple words, yeah"},
  {0, "(.*)c(.*)", "abcde"},
  {1, "\\((.*),", "(.*)\\)"},
  {1, "[k]", "ab"},
  {0, "abcd", "abcd"},
  {0, "a(bc)d", "abcd"},
  {0, "a[-]?c", "ac"},
  {0, "(....).*\\1", "beriberi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Qaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mo'ammar Gadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Kaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Qadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moammar El Kadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Gadafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar al-Qadafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moamer El Kazzafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moamar al-Gaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar Al Qathafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Al Qathafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mo'ammar el-Gadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moamar El Kadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar al-Qadhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar al-Qadhdhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar Qadafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moamar Gaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar Qadhdhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Khaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar al-Khaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'amar al-Kadafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghaddafy"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghadafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muamar Kaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Quathafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Gheddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muamar Al-Kaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moammar Khadafy "},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moammar Qudhafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar al-Qaddafi"},
  {0, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mulazim Awwal Mu'ammar Muhammad Abu Minyar al-Qadhafi"},
