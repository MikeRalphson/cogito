#!/usr/bin/env bash
#
# Copyright (c) 2006 Yann Dirson
#
test_description="Tests various commands with shell-special chars.

Filenames with embedded spaces, quotes, non-ascii letter, you name it."

. ./test-lib.sh

rm -rf .git
cg-init -m .

touch "a space"
test_expect_success 'add file with space' 'cg-add "a space"'
test_expect_success 'commit file with space' 'cg-commit -m . "a space"'

touch "a'quote"
test_expect_success 'add file with quote' "cg-add \"a'quote\""
test_expect_success 'commit file with quote' "cg-commit -m . \"a'quote\""

touch "d\"quote"
test_expect_success 'add file with accent' 'cg-add "d\"quote"'
test_expect_success 'commit file with quote' 'cg-commit -m . "d\"quote"'

touch "back\\slash"
test_expect_success 'add file with accent' 'cg-add "back\\slash"'
test_expect_success 'commit file with quote' 'cg-commit -m . "back\\slash"'

touch "accént"
test_expect_success 'add file with accent' "cg-add accént"
test_expect_success 'commit file with quote' "cg-commit -m . accént"

## same without a file arg to cg-commit

rm -rf * .git
cg-init -m .

touch "a space"
test_expect_success 'add file with space' 'cg-add "a space"'
test_expect_success 'commit file with space' 'cg-commit -m .'

touch "a'quote"
test_expect_success 'add file with quote' "cg-add \"a'quote\""
test_expect_success 'commit file with quote' "cg-commit -m ."

touch "d\"quote"
test_expect_success 'add file with accent' 'cg-add "d\"quote"'
test_expect_success 'commit file with quote' 'cg-commit -m .'

touch "back\\slash"
test_expect_success 'add file with accent' 'cg-add "back\\slash"'
test_expect_success 'commit file with quote' 'cg-commit -m .'

touch "accént"
test_expect_success 'add file with accent' "cg-add accént"
test_expect_success 'commit file with quote' "cg-commit -m ."

test_done
