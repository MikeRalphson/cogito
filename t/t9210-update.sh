#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests basic cg-update functionality

This isn't very sophisticated, since if cg-fetch and cg-merge
works all right, this should do so too - so just check if it
does tree merge right, fast-forward right, and the only interesting
and update-specific thing, rebased-fastforward."

. ./test-lib.sh

mkdir branch1
echo file >branch1/file1
test_expect_success 'initialize branch1' \
	"(cd branch1 && cg-init -I && cg-add file1 && cg-commit -C -m\"Initial commit\")"
test_expect_success 'fork branch2' \
	"cg-clone branch1 branch2"
test_expect_success 'registering branch2 in branch1' \
	"(cd branch1 && cg-branch-add origin ../branch2)"

echo "file new in branch1" >branch1/file-b1
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-add file-b1 && cg-commit -m\"Local commit in b1\")"
echo "file new in branch2" >branch2/file-b2
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-add file-b2 &&  cg-commit -m\"Local commit in b2\")"

test_expect_success 'updating from branch2 in branch1' \
		"(cd branch1 && cg-update </dev/null)"
test_expect_success 'checking for correct merged content' \
		"(cmp branch2/file-b2 branch1/file-b2)"
test_expect_success 'checking if it was a tree-merge' \
		"(! cmp branch1/.git/refs/heads/origin branch1/.git/refs/heads/master)"

test_expect_success 'fast-forwarding branch2' \
		"(cd branch2 && cg-update)"
test_expect_success 'checking if it was correct' \
		"(cmp branch1/.git/refs/heads/master branch2/.git/refs/heads/master)"

echo "file changed in b2" >branch2/file-b2
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-commit -m\"Local commit in b2 (to-be-fw)\")"
test_expect_success 'updating from branch2 in branch1' \
		"(cd branch1 && cg-update </dev/null)"
test_expect_success 'checking for correct merged content' \
		"(cmp branch2/file-b2 branch1/file-b2)"
test_expect_success 'checking if it was a fast-forward' \
		"(cmp branch1/.git/refs/heads/origin branch1/.git/refs/heads/master)"

test_expect_success 'uncommitting in branch2' \
		"(cd branch2 && cg-admin-uncommit)"
echo "file changed 2nd time in b2" >branch2/file-b2
test_expect_success 'local commit in branch2 (rebased)' \
		"(cd branch2 && cg-commit -m\"Local commit (rebased) in b2 (to-be-fw)\")"
test_expect_success 'updating from branch2 in branch1' \
		"(cd branch1 && cg-update </dev/null)"
test_expect_success 'checking for correct merged content' \
		"(cmp branch2/file-b2 branch1/file-b2)"
test_expect_success 'checking if it was still a fast-forward' \
		"(cmp branch1/.git/refs/heads/origin branch1/.git/refs/heads/master)"

test_done
