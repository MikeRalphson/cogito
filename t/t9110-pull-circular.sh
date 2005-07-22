#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests circular cg-pull

The base for the test is the following description of Russel King workflow:

        Linus' kernel.org tree --> Local pristine tree
                ^   ^                |            |
                |   |                v            v
                |   |        working tree 1   working tree 2
                |   |                |            |
                |   \`----------------'            |
                \`---------------------------------'

Changes are made in working tree 1, and made available to Linus.  Linus
merges them into his tree.  I pull them into the pristine tree.  Assume
other changes occurred. in Linus' tree.

The pristine tree is obviously a superset of the working tree.

One example of a problem arising from this - after one round, objects which
first appeared in working tree would be overwritten with the same objects
but with newer date."

. ./test-lib.sh

# repo1 == kernel.org, repo2 == pristine tree, repo3 == working tree
# FIXME: Simulate network communication with repo1.

mkdir repo1
date >repo1/brm
test_expect_success 'initialize repo1' \
	"(cd repo1 && cg-init -I && cg-add brm && cg-commit -C -m\"Initial commit\")"
test_expect_success 'clone repo2' \
	"cg-clone repo1 repo2"
test_expect_success 'clone repo3' \
	"cg-clone repo2 repo3"

test_expect_success 'registering repo3 in repo1' \
	"(cd repo1 && cg-branch-add origin ../repo3)"

date >>repo3/brm
test_expect_success 'local commit in repo3' \
		"(cd repo3 && cg-commit -m\"Second commit\")"

test_expect_success 'updating repo1' \
		"(cd repo1 && cg-update origin)"
test_expect_success 'updating repo2' \
		"(cd repo2 && cg-update)"
test_expect_success 'updating repo3' \
		"(cd repo3 && cg-update)"

test_done
