#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='Test the very basics part #1.

The rest of the test suite does not check the basic operation of git
plumbing commands to work very carefully.  Their job is to concentrate
on tricky features that caused bugs in the past to detect regression.

This test runs very basic features, like registering things in cache,
writing tree, etc.

Note that this test *deliberately* hard-codes many expected object
IDs.  When object ID computation changes, like in the previous case of
swapping compression and hashing order, the person who is making the
modification *should* take notice and update the test vectors here.
'
. ./test-lib.sh

################################################################
# init-db has been done in an empty repository.
# make sure it is empty.

find .git/objects -type f -print >should-be-empty
test_expect_success \
    '.git/objects should be empty after git-init-db in an empty repo.' \
    'cmp -s /dev/null should-be-empty' 

# also it should have 256 subdirectories.  257 is counting "objects"
find .git/objects -type d -print >full-of-directories
test_expect_success \
    '.git/objects should have 256 subdirectories.' \
    'test $(wc -l < full-of-directories) = 257'

################################################################
# Basics of the basics

# updating a new file without --add should fail.
test_expect_failure \
    'git-update-cache without --add should fail adding.' \
    'git-update-cache should-be-empty'

# and with --add it should succeed, even if it is empty (it used to fail).
test_expect_success \
    'git-update-cache with --add should succeed.' \
    'git-update-cache --add should-be-empty'

test_expect_success \
    'writing tree out with git-write-tree' \
    'tree=$(git-write-tree)'

# we know the shape and contents of the tree and know the object ID for it.
test_expect_success \
    'validate object ID of a known tree.' \
    'test "$tree" = 7bb943559a305bdd6bdee2cef6e5df2413c3d30a'

# Removing paths.
rm -f should-be-empty full-of-directories
test_expect_failure \
    'git-update-cache without --remove should fail removing.' \
    'git-update-cache should-be-empty'

test_expect_success \
    'git-update-cache with --remove should be able to remove.' \
    'git-update-cache --remove should-be-empty'

# Empty tree can be written with recent write-tree.
test_expect_success \
    'git-write-tree should be able to write an empty tree.' \
    'tree=$(git-write-tree)'

test_expect_success \
    'validate object ID of a known tree.' \
    'test "$tree" = 4b825dc642cb6eb9a060e54bf8d69288fbee4904'

# Various types of objects
mkdir path2 path3 path3/subp3
for p in path0 path2/file2 path3/file3 path3/subp3/file3
do
    echo "hello $p" >$p
    ln -s "hello $p" ${p}sym
done
test_expect_success \
    'adding various types of objects with git-update-cache --add.' \
    'find path* ! -type d -print0 | xargs -0 git-update-cache --add'

# Show them and see that matches what we expect.
test_expect_success \
    'showing stage with git-ls-files --stage' \
    'git-ls-files --stage >current'

cat >expected <<\EOF
100644 f87290f8eb2cbbea7857214459a0739927eab154 0	path0
120000 15a98433ae33114b085f3eb3bb03b832b3180a01 0	path0sym
100644 3feff949ed00a62d9f7af97c15cd8a30595e7ac7 0	path2/file2
120000 d8ce161addc5173867a3c3c730924388daedbc38 0	path2/file2sym
100644 0aa34cae68d0878578ad119c86ca2b5ed5b28376 0	path3/file3
120000 8599103969b43aff7e430efea79ca4636466794f 0	path3/file3sym
100644 00fb5908cb97c2564a9783c0c64087333b3b464f 0	path3/subp3/file3
120000 6649a1ebe9e9f1c553b66f5a6e74136a07ccc57c 0	path3/subp3/file3sym
EOF
test_expect_success \
    'validate git-ls-files output for a known tree.' \
    'diff current expected'

test_expect_success \
    'writing tree out with git-write-tree.' \
    'tree=$(git-write-tree)'
test_expect_success \
    'validate object ID for a known tree.' \
    'test "$tree" = 087704a96baf1c2d1c869a8b084481e121c88b5b'

test_expect_success \
    'showing tree with git-ls-tree' \
    'git-ls-tree $tree >current'
cat >expected <<\EOF
100644 blob f87290f8eb2cbbea7857214459a0739927eab154	path0
120000 blob 15a98433ae33114b085f3eb3bb03b832b3180a01	path0sym
040000 tree 58a09c23e2ca152193f2786e06986b7b6712bdbe	path2
040000 tree 21ae8269cacbe57ae09138dcc3a2887f904d02b3	path3
EOF
test_expect_success \
    'git-ls-tree output for a known tree.' \
    'diff current expected'

test_expect_success \
    'showing tree with git-ls-tree -r' \
    'git-ls-tree -r $tree >current'
cat >expected <<\EOF
100644 blob f87290f8eb2cbbea7857214459a0739927eab154	path0
120000 blob 15a98433ae33114b085f3eb3bb03b832b3180a01	path0sym
040000 tree 58a09c23e2ca152193f2786e06986b7b6712bdbe	path2
100644 blob 3feff949ed00a62d9f7af97c15cd8a30595e7ac7	path2/file2
120000 blob d8ce161addc5173867a3c3c730924388daedbc38	path2/file2sym
040000 tree 21ae8269cacbe57ae09138dcc3a2887f904d02b3	path3
100644 blob 0aa34cae68d0878578ad119c86ca2b5ed5b28376	path3/file3
120000 blob 8599103969b43aff7e430efea79ca4636466794f	path3/file3sym
040000 tree 3c5e5399f3a333eddecce7a9b9465b63f65f51e2	path3/subp3
100644 blob 00fb5908cb97c2564a9783c0c64087333b3b464f	path3/subp3/file3
120000 blob 6649a1ebe9e9f1c553b66f5a6e74136a07ccc57c	path3/subp3/file3sym
EOF
test_expect_success \
    'git-ls-tree -r output for a known tree.' \
    'diff current expected'

################################################################
rm .git/index
test_expect_success \
    'git-read-tree followed by write-tree should be idempotent.' \
    'git-read-tree $tree &&
     test -f .git/index &&
     newtree=$(git-write-tree) &&
     test "$newtree" = "$tree"'

cat >expected <<\EOF
:100644 100644 f87290f8eb2cbbea7857214459a0739927eab154 0000000000000000000000000000000000000000 M	path0
:120000 120000 15a98433ae33114b085f3eb3bb03b832b3180a01 0000000000000000000000000000000000000000 M	path0sym
:100644 100644 3feff949ed00a62d9f7af97c15cd8a30595e7ac7 0000000000000000000000000000000000000000 M	path2/file2
:120000 120000 d8ce161addc5173867a3c3c730924388daedbc38 0000000000000000000000000000000000000000 M	path2/file2sym
:100644 100644 0aa34cae68d0878578ad119c86ca2b5ed5b28376 0000000000000000000000000000000000000000 M	path3/file3
:120000 120000 8599103969b43aff7e430efea79ca4636466794f 0000000000000000000000000000000000000000 M	path3/file3sym
:100644 100644 00fb5908cb97c2564a9783c0c64087333b3b464f 0000000000000000000000000000000000000000 M	path3/subp3/file3
:120000 120000 6649a1ebe9e9f1c553b66f5a6e74136a07ccc57c 0000000000000000000000000000000000000000 M	path3/subp3/file3sym
EOF
test_expect_success \
    'validate git-diff-files output for a know cache/work tree state.' \
    'git-diff-files >current && diff >/dev/null -b current expected'

test_expect_success \
    'git-update-cache --refresh should succeed.' \
    'git-update-cache --refresh'

test_expect_success \
    'no diff after checkout and git-update-cache --refresh.' \
    'git-diff-files >current && cmp -s current /dev/null'

test_done
