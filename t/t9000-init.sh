#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests cg-init

Whether it works, properly does initial commit, and all the options except -N
work properly (-N is not tested since it's weird and I'm lazy)."

. ./test-lib.sh

rm -rf .git

echo file1 >file1
echo file2 >file2
test_expect_success 'initialize w/o the initial commit' \
	'cg-init -I'
test_expect_success 'check if we have the proper repository' \
	'[ -d .git ] && [ -s .git/index ] && [ -d .git/objects ] &&
	 [ $(git-symbolic-ref HEAD) = refs/heads/master ] &&
	 [ -d .git/refs ] && [ -d .git/refs/heads ] && [ -d .git/refs/tags ]'
test_expect_failure 'check if we really have no commit' \
	'[ -s .git/refs/heads/master ] || cg-object-id -c HEAD'
test_expect_failure 'check if we really have empty index' \
	'[ "$(git-ls-files)" ]'
test_expect_success 'try manual initial commit' \
	'(cg-add file1 file2 && cg-commit -C -m"Initial commit")'
test_expect_success 'check if we have a commit' \
	'[ -s .git/refs/heads/master ] && cg-object-id -c HEAD'
test_expect_success 'check if we have populated index' \
	'[ "$(git-ls-files | tr '\''\n'\'' " ")" = "file1 file2 " ]'
test_expect_success 'blow away the repository' \
	'rm -rf .git'

test_expect_success 'initialize with the initial commit' \
	'echo "silly commit message" | cg-init'
test_expect_success 'check if we have a commit' \
	'[ -s .git/refs/heads/master ] && cg-object-id -c HEAD'
test_expect_success 'check if the commit is proper' \
	'[ "$(git-cat-file commit HEAD | sed -n '\''/^parent/q; /^$/{n; :a p; n; b a}'\'')" = "Initial commit
silly commit message" ]'
test_expect_success 'check if we have populated index' \
	'[ "$(git-ls-files | tr '\''\n'\'' " ")" = "file1 file2 " ]'
test_expect_success 'blow away the repository' \
	'rm -rf .git'

test_expect_success 'initialize with the initial commit and -m' \
	'cg-init -m"silly commit message" -m"continued"'
test_expect_success 'check if we have a commit' \
	'[ -s .git/refs/heads/master ] && cg-object-id -c HEAD'
test_expect_success 'check if the commit is proper' \
	'[ "$(git-cat-file commit HEAD | sed -n '\''/^parent/q; /^$/{n; :a p; n; b a}'\'')" = "silly commit message

continued" ]'
test_expect_success 'blow away the repository' \
	'rm -rf .git'

echo file3 >file3
echo file4 >file4
test_expect_success 'initialize with the initial commit and -e' \
	'echo "silly commit message" | cg-init -e "file2" -e "file[34]"'
test_expect_success 'check if we have a commit' \
	'[ -s .git/refs/heads/master ] && cg-object-id -c HEAD'
test_expect_success 'check if we have properly populated index' \
	'[ "$(git-ls-files | tr '\''\n'\'' " ")" = "file1 " ]'
test_expect_success 'blow away the repository' \
	'rm -rf .git'

echo "file[12]" >.gitignore
test_expect_success 'initialize with the initial commit and .gitignore' \
	'echo "silly commit message" | cg-init'
test_expect_success 'check if we have a commit' \
	'[ -s .git/refs/heads/master ] && cg-object-id -c HEAD'
test_expect_success 'check if we have properly populated index' \
	'[ "$(git-ls-files | tr '\''\n'\'' " ")" = ".gitignore file3 file4 " ]'
test_expect_success 'blow away the repository' \
	'rm -rf .git'

test_done
