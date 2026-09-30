#!/bin/sh
# test/kore/ed.sh -- ed and ex (src/apps/kore/ed.l): the addresses, the commands, g's lists,
# s's forms, undo, files and the shell, and ex's words, counts and registers. held to
# answers read off by hand, not to a host editor: GNU ed is seldom installed, and vim's
# ex carries on past an error where POSIX ends the script.
. "$(dirname "$0")/common.sh"

w=$HO/.ed
rm -rf "$w"; mkdir -p "$w"
# chk NAME EXIT WANT SCRIPT TOOL ARGS..: the tool run in $w over a fresh five-line g,
# SCRIPT on its stdin; stdout and stderr together, then the exit status, must be WANT
chk() { n=$1; x=$2; want=$3; sc=$4; shift 4
        printf 'alpha\nbeta\ngamma\ndelta\nepsilon\n' > "$w/g"
        got=$(cd "$w" && printf "$sc" | LOVE_NO_IMAGE= "$K" kore "$@" 2>&1; echo "[$?]")
        exp=$(printf "$want[$x]")
        [ "$got" = "$exp" ] || fail "kore $n: got
$got
-- wanted
$exp"; }

# -- ed ---------------------------------------------------------------------------------
# the addresses: a search each way, offsets, and , and ; with a side missing
chk "ed addresses" 0 'gamma\nalpha\nalpha\nbeta\ndelta\nepsilon\nepsilon\nalpha\nbeta\ngamma\nbeta\ngamma\n' \
    '/gam/\n?al?\n.,+1p\n$-1,$p\n;p\n,2p\n3,p\n2;+1p\nQ\n' ed -s g
chk "ed %% ^ and a sum" 0 'alpha\nbeta\ngamma\ndelta\nepsilon\ndelta\ndelta\n' '%%p\n$^p\n2 2p\nQ\n' ed -s g
# g over a range and its undo, which takes the whole visit back at once
chk "ed g and u" 0 'alphA\nbetA\ngammA\ndeltA\nepsilon\nalpha\nbeta\ngamma\ndelta\nepsilon\n' \
    'g/a$/s/a$/A/\n,p\nu\n,p\nQ\n' ed -s g
chk "ed m t u" 0 'beta\ngamma\nalpha\ndelta\nepsilon\nalpha\nbeta\ngamma\ndelta\nepsilon\nalpha\n' \
    '2,3m0\n,p\nu\n1t$\n,p\nQ\n' ed -s g
# s: g, the nth match, groups and &, a bare s repeating, and a backslash-newline split
chk "ed s forms" 0 'alXhA\nbeta\ngammA\ndelta\nepsilon\n[ebbe]ta\na\nXhA\n[eb[ebbe]]ta\n' \
    '1s/p/X/g\n,s/a/A/2\n,p\n2s/\\(b\\)\\(e\\)/[\\2\\1&]/p\ns\n1s/l/\\\n/\n1,3p\nQ\n' ed -s g
chk "ed s %% and an open end" 0 'gAmma\ndAlta\n' '3s/a/A\n4s/e/%%/p\nQ\n' ed -s g
# marks, input mode at 0, n, w, the shell, r of a command, f, and e warning once
chk "ed files and the shell" 1 '31\nbeta\ngamma\ndelta\nbeta\n1\tfirst\n2\ttop\n3\tbeta\n4\tgamma\n5\tdelta\n6\tepsilon\n35\nhi\n!\n4\nx\ny\ng\n?\nwarning: buffer modified\n' \
    'H\n2ka\n4kb\n'"'"'a,'"'"'bp\n1d\n'"'"'ap\n0a\ntop\n.\n1i\nfirst\n.\n,n\nw out1\n!echo hi\n$r !printf "x\\\\ny\\\\n"\n$-1,$p\nf\ne out1\n' ed g
chk "ed w landed" 0 'first\ntop\nbeta\ngamma\ndelta\nepsilon\n' ',p\n' ed -s out1
# l's escapes, v, a list over lines with input in it, W appending, wq
printf 'tab\there\\back\001ctl\n' > "$w/lz"
chk "ed l v g-list W wq" 0 'tab\\there\\\\back\\001ctl$\nbeta\ndelta\nepsilon\ntab\there\\back\001ctl\nbeta\ngamma\nadded\nadded\nadded\nadded\n' \
    'r lz\n$l\nv/e/d\n,p\nu\ng/l/d\\\n$a\\\nadded\n,p\n1,2W out2\n2,3wq out3\n' ed -s g
[ "$(cat "$w/out2" "$w/out3")" = "$(printf 'beta\ngamma\ngamma\nadded')" ] || fail "kore ed W/wq files"
# an error ends a script with 1; H says why, and h does after the fact
chk "ed error ends a script" 1 '?\n' '1s/zz/y/\n1p\n' ed -s g
chk "ed H" 1 '?\nno match\n' 'H\n/zz/\n' ed -s g
chk "ed q on a change" 1 '?\n' '1d\nq\n' ed -s g
chk "ed P and -p" 0 '> alpha\n> ' '1p\nQ\n' ed -s -p '> ' g
chk "ed a missing file" 0 'nope: No such file or directory\n2\n' 'a\nx\n.\nw\nq\n' ed nope
chk "ed z" 0 'alpha\nbeta\ngamma\n' '1z3\nQ\n' ed -s g
chk "ed z refuses a stray word" 1 '?\n' 'zz\n' ed -s g
chk "ed j and =" 0 'alphabeta\n4\n1\n' '1,2j\np\n=\n.=\nQ\n' ed -s g
# a big g: the visit resumes where it was, and d under it renumbers as it goes
seq 1 3000 > "$w/big"
chk "ed g over 3000 lines" 0 '2277\n2\n1\n2\n' 'g/0/d\n$=\n2p\ng/^[12]$/s/$/!/\n1,2s/!//\n1,2p\nQ\n' ed -s big

# -- ex ---------------------------------------------------------------------------------
chk "ex nu l = | registers" 0 '     1  alpha\n     2  beta\n     3  gamma\n     4  delta\n     5  epsilon\ngamma\nalpha$\ngamma$\n4\n2\nepsilon\nalpha\ngamma\ndelta\nepsilon\nalpha\ngamma\ndelta\n' \
    '%%nu\n2d|p\n1,2l\n=\n.=\n$\nd a 2\npu a\n%%p\nu\n%%p\nq!\n' ex -s g
chk "ex s counts and g with |" 0 'AlphA\nAlphA\nbeta\ngXmma\ndeltX\nepsilon\nAlphA\nbeta\ngYmma\ndEltY\nepsilon\n' \
    '1s/a/A/g|p\n2,3s/a/X/ 2\n%%p\ng/X/s/X/Y/|s/e/E/\n%%p\nq!\n' ex -s g
chk "ex & co m j > < set k" 0 'delta\nbEta\nalpha\ngamma\ndElta\nepsilon\nalpha\n\t\tbEta alpha\n\\tbEta alpha$\n     1  \t  bEta alpha\n     2    gamma\n     3    dElta\n     4    epsilon\n     5    alpha\nsw=2\n  gamma\nalpha\n' \
    '2s/e/E/\n4\n&\n1co$\n1m2\n%%p\n1,2j\n>>\n.p\n<\nl\nset sw=2 nu\n1,$>\n%%p\nset nonu sw?\nk x\n2\ns/ //g\n'"'"'xs/ //gp\nq!\n' ex -s g
chk "ex filter r! f w x" 0 '"g" 5L, 31B\n3 lines filtered\nalpha\ngamma\ndelta\nbeta\nepsilon\n"g" [Modified] 6 lines --100%%--\n"out4" 6L, 34B\n"g" 6L, 34B\n' \
    '2,4!sort -r\n%%p\nr !echo zz\nf\nw out4\nx\n' ex g
[ "$(tail -n 1 "$w/g")" = zz ] || fail "kore ex x wrote nothing"
chk "ex -c and +" 0 '"g" 5L, 31B\nbeta\ndelta\ndelta\n' 'p\nq\n' ex -c 2 +/delta g
chk "ex -R" 1 'file is read only (add ! to override)\n' 'w\n' ex -R -s g
chk "ex e over a change" 1 '"g" 5L, 31B\nbeta\nno write since last change (add ! to override)\n' '1d\ne out1\n' ex g
chk "ex e! and a new file" 0 '"g" 5L, 31B\n"new2" [New]\n"new2" 1L, 3B\n' 'e! new2\na\nhi\n.\nx\n' ex g
chk "ex colons ahead" 0 'alpha\nbeta\ngamma\n' ':1,2p\n: :3p\n:q\n' ex -s g
chk "ex not a command" 1 'not an editor command: frob\n' 'frob\n' ex -s g
chk "ex ambiguous heads resolve" 0 'alpha\n     1  alpha\n' '1p\n1nu\nq\n' ex -s g
echo "kore: ed and ex (the addresses, the commands, g's lists, s's forms, undo, the files and the shell, ex's words, counts and registers) ok"
