#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='Test mode change diffs.

'
. ./test-lib.sh

test_expect_success \
    'setup' \
    'echo frotz >rezrov &&
     git-update-cache --add rezrov &&
     tree=`git-write-tree` &&
     echo $tree'

test_expect_success \
    'chmod' \
    'chmod +x rezrov &&
     git-update-cache rezrov &&
     git-diff-cache $tree >current'

_x40='[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'
_x40="$_x40$_x40$_x40$_x40$_x40$_x40$_x40$_x40"
sed -e 's/\(:100644 100755\) \('"$_x40"'\) \2 /\1 X X /' <current >check
echo ":100644 100755 X X M	rezrov" >expected

test_expect_success \
    'verify' \
    'diff -u expected check'

test_done

