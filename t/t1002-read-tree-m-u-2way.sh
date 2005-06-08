#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='Two way merge with read-tree -m -u $H $M

This is identical to t1001, but uses -u to update the work tree as well.

'
. ./test-lib.sh

_x40='[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'
_x40="$_x40$_x40$_x40$_x40$_x40$_x40$_x40$_x40"
compare_change () {
	sed >current \
	    -e '/^--- /d; /^+++ /d; /^@@ /d;' \
	    -e 's/^\(.[0-7][0-7][0-7][0-7][0-7][0-7]\) '"$_x40"' /\1 X /' "$1"
	diff -u expected current
}

check_cache_at () {
	clean_if_empty=`git-diff-files "$1"`
	case "$clean_if_empty" in
	'')  echo "$1: clean" ;;
	?*)  echo "$1: dirty" ;;
	esac
	case "$2,$clean_if_empty" in
	clean,)		:     ;;
	clean,?*)	false ;;
	dirty,)		false ;;
	dirty,?*)	:     ;;
	esac
}

test_expect_success \
    setup \
    'echo frotz >frotz &&
     echo nitfol >nitfol &&
     echo bozbar >bozbar &&
     echo rezrov >rezrov &&
     echo yomin >yomin &&
     git-update-cache --add nitfol bozbar rezrov &&
     treeH=`git-write-tree` &&
     echo treeH $treeH &&
     git-ls-tree $treeH &&

     echo gnusto >bozbar &&
     git-update-cache --add frotz bozbar --force-remove rezrov &&
     git-ls-files --stage >M.out &&
     treeM=`git-write-tree` &&
     echo treeM $treeM &&
     git-ls-tree $treeM &&
     sha1sum bozbar frotz nitfol >M.sha1 &&
     git-diff-tree $treeH $treeM'

test_expect_success \
    '1, 2, 3 - no carry forward' \
    'rm -f .git/index &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >1-3.out &&
     cmp M.out 1-3.out &&
     sha1sum -c M.sha1 &&
     check_cache_at bozbar clean &&
     check_cache_at frotz clean &&
     check_cache_at nitfol clean'

echo '+100644 X 0	yomin' >expected

test_expect_success \
    '4 - carry forward local addition.' \
    'rm -f .git/index &&
     git-update-cache --add yomin &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >4.out || exit
     diff --unified=0 M.out 4.out >4diff.out
     compare_change 4diff.out expected &&
     check_cache_at yomin clean &&
     sha1sum -c M.sha1 &&
     echo yomin >yomin1 &&
     diff yomin yomin1 &&
     rm -f yomin1'

test_expect_success \
    '5 - carry forward local addition.' \
    'rm -f .git/index &&
     echo yomin >yomin &&
     git-update-cache --add yomin &&
     echo yomin yomin >yomin &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >5.out || exit
     diff --unified=0 M.out 5.out >5diff.out
     compare_change 5diff.out expected &&
     check_cache_at yomin dirty &&
     sha1sum -c M.sha1 &&
     : dirty index should have prevented -u from checking it out.
     echo yomin yomin >yomin1 &&
     diff yomin yomin1 &&
     rm -f yomin1'

test_expect_success \
    '6 - local addition already has the same.' \
    'rm -f .git/index &&
     git-update-cache --add frotz &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >6.out &&
     diff --unified=0 M.out 6.out &&
     check_cache_at frotz clean &&
     sha1sum -c M.sha1 &&
     echo frotz >frotz1 &&
     diff frotz frotz1 &&
     rm -f frotz1'

test_expect_success \
    '7 - local addition already has the same.' \
    'rm -f .git/index &&
     echo frotz >frotz &&
     git-update-cache --add frotz &&
     echo frotz frotz >frotz &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >7.out &&
     diff --unified=0 M.out 7.out &&
     check_cache_at frotz dirty &&
     if sha1sum -c M.sha1; then false; else :; fi &&
     : dirty index should have prevented -u from checking it out.
     echo frotz frotz >frotz1 &&
     diff frotz frotz1 &&
     rm -f frotz1'

test_expect_success \
    '8 - conflicting addition.' \
    'rm -f .git/index &&
     echo frotz frotz >frotz &&
     git-update-cache --add frotz &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '9 - conflicting addition.' \
    'rm -f .git/index &&
     echo frotz frotz >frotz &&
     git-update-cache --add frotz &&
     echo frotz >frotz &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '10 - path removed.' \
    'rm -f .git/index &&
     echo rezrov >rezrov &&
     git-update-cache --add rezrov &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >10.out &&
     cmp M.out 10.out &&
     sha1sum -c M.sha1'

test_expect_success \
    '11 - dirty path removed.' \
    'rm -f .git/index &&
     echo rezrov >rezrov &&
     git-update-cache --add rezrov &&
     echo rezrov rezrov >rezrov &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '12 - unmatching local changes being removed.' \
    'rm -f .git/index &&
     echo rezrov rezrov >rezrov &&
     git-update-cache --add rezrov &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '13 - unmatching local changes being removed.' \
    'rm -f .git/index &&
     echo rezrov rezrov >rezrov &&
     git-update-cache --add rezrov &&
     echo rezrov >rezrov &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

cat >expected <<EOF
-100644 X 0	nitfol
+100644 X 0	nitfol
EOF

test_expect_success \
    '14 - unchanged in two heads.' \
    'rm -f .git/index &&
     echo nitfol nitfol >nitfol &&
     git-update-cache --add nitfol &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >14.out || exit
     diff --unified=0 M.out 14.out >14diff.out
     compare_change 14diff.out expected &&
     check_cache_at nitfol clean &&
     grep -v nitfol M.sha1 | sha1sum -c &&
     if sha1sum -c M.sha1; then false; else :; fi &&
     echo nitfol nitfol >nitfol1 &&
     diff nitfol nitfol1 &&
     rm -f nitfol1'

test_expect_success \
    '15 - unchanged in two heads.' \
    'rm -f .git/index &&
     echo nitfol nitfol >nitfol &&
     git-update-cache --add nitfol &&
     echo nitfol nitfol nitfol >nitfol &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >15.out || exit
     diff --unified=0 M.out 15.out >15diff.out
     compare_change 15diff.out expected &&
     check_cache_at nitfol dirty &&
     grep -v nitfol M.sha1 | sha1sum -c &&
     if sha1sum -c M.sha1; then false; else :; fi &&
     echo nitfol nitfol nitfol >nitfol1 &&
     diff nitfol nitfol1 &&
     rm -f nitfol1'

test_expect_success \
    '16 - conflicting local change.' \
    'rm -f .git/index &&
     echo bozbar bozbar >bozbar &&
     git-update-cache --add bozbar &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '17 - conflicting local change.' \
    'rm -f .git/index &&
     echo bozbar bozbar >bozbar &&
     git-update-cache --add bozbar &&
     echo bozbar bozbar bozbar >bozbar &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

test_expect_success \
    '18 - local change already having a good result.' \
    'rm -f .git/index &&
     echo gnusto >bozbar &&
     git-update-cache --add bozbar &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >18.out &&
     diff --unified=0 M.out 18.out &&
     check_cache_at bozbar clean &&
     sha1sum -c M.sha1'

test_expect_success \
    '19 - local change already having a good result, further modified.' \
    'rm -f .git/index &&
     echo gnusto >bozbar &&
     git-update-cache --add bozbar &&
     echo gnusto gnusto >bozbar &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >19.out &&
     diff --unified=0 M.out 19.out &&
     check_cache_at bozbar dirty &&
     grep -v bozbar M.sha1 | sha1sum -c &&
     if sha1sum -c M.sha1; then false; else :; fi &&
     echo gnusto gnusto >bozbar1 &&
     diff bozbar bozbar1 &&
     rm -f bozbar1'

test_expect_success \
    '20 - no local change, use new tree.' \
    'rm -f .git/index &&
     echo bozbar >bozbar &&
     git-update-cache --add bozbar &&
     git-read-tree -m -u $treeH $treeM &&
     git-ls-files --stage >20.out &&
     diff --unified=0 M.out 20.out &&
     check_cache_at bozbar clean &&
     sha1sum -c M.sha1'

test_expect_success \
    '21 - no local change, dirty cache.' \
    'rm -f .git/index &&
     echo bozbar >bozbar &&
     git-update-cache --add bozbar &&
     echo gnusto gnusto >bozbar &&
     if git-read-tree -m -u $treeH $treeM; then false; else :; fi'

# Also make sure we did not break DF vs DF/DF case.
test_expect_success \
    'DF vs DF/DF case setup.' \
    'rm -f .git/index &&
     echo DF >DF &&
     git-update-cache --add DF &&
     treeDF=`git-write-tree` &&
     echo treeDF $treeDF &&
     git-ls-tree $treeDF &&

     rm -f DF &&
     mkdir DF &&
     echo DF/DF >DF/DF &&
     git-update-cache --add --remove DF DF/DF &&
     treeDFDF=`git-write-tree` &&
     echo treeDFDF $treeDFDF &&
     git-ls-tree $treeDFDF &&
     git-ls-files --stage >DFDF.out'

test_expect_success \
    'DF vs DF/DF case test.' \
    'rm -f .git/index &&
     rm -fr DF &&
     echo DF >DF &&
     git-update-cache --add DF &&
     git-read-tree -m -u $treeDF $treeDFDF &&
     git-ls-files --stage >DFDFcheck.out &&
     diff --unified=0 DFDF.out DFDFcheck.out &&
     check_cache_at DF/DF clean'

test_done
