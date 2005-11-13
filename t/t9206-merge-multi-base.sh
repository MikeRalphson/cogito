#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests cg-merge discovering multiple bases

Creates a commit DAG generating multiple bases and checks how does cg-merge
deal with it."

. ./test-lib.sh
rm -rf .git

echo file1 >file1
test_expect_success 'initialize repo' \
	'(cg-init -m"Initial commit" && cg-tag initial)'

# We will create the classic criss-cross scenario.

test_expect_success 'branch A commit 1' \
	'(cg-commit -f -m"branch A commit 1" && cp .git/refs/heads/master .git/refs/heads/branchA)'
test_expect_success 'branch B commit 1' \
	'(cg-object-id -c initial >.git/refs/heads/master &&
	  cg-commit -f -m"branch B commit 1" && cp .git/refs/heads/master .git/refs/heads/branchB)'
test_expect_success 'branch A commit 2' \
	'(cg-object-id -c branchA >.git/refs/heads/master &&
	  cg-object-id -c branchB >.git/merging &&
	  cg-commit -f -m"branch A commit 2" && cp .git/refs/heads/master .git/refs/heads/branchA)'
test_expect_success 'branch B commit 2' \
	'(cg-object-id -c branchB >.git/refs/heads/master &&
	  cg-object-id -p branchA >.git/merging &&
	  cg-commit -f -m"branch B commit 2" && cp .git/refs/heads/master .git/refs/heads/branchB)'

# We end up in branch B
test_expect_failure 'try to merge branch A and B' \
	'cg-merge branchA 2>log'
# If we cut out everything, only the first guide and one empty line stays
test_expect_success 'check cg-merge'\''s proposal' \
	'[ "$(grep -Ev "^$(cg-object-id -p branchA | tr '\''\n'\'' "|")somethingnonsensical\$" log |
	      grep -v ": $(cg-object-id -c initial)\$" | wc -l)" = "2" ]'


test_done
