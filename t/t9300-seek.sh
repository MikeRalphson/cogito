#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests basic cg-seek functionality

Generate two commits, and test if the seek works properly. That includes the
basic tree changes, keeping of local changes, and removing of directories that
should be gone."

. ./test-lib.sh

echo "identical" >identical
echo "v1" >different

test_expect_success 'initialize repo' \
	"(cg-add identical different && cg-commit -C -m\"Initial commit\")"
commit1=$(cg-object-id -c)

sleep 1 # FIXME: race
echo "v2" >different
mkdir newdir
echo "v2" >newdir/newfile
test_expect_success 'record second commit' \
	"(cg-add newdir/newfile && cg-commit -m\"Second commit\")"
commit2=$(cg-object-id -c)

test_expect_success 'seeking to the first commit' \
	"cg-seek $commit1"
test_expect_success 'we should have .git/head-name == master' \
	"[ $(cat .git/head-name) = master ]"
test_expect_success 'current branch should be cg-seek-point' \
	"[ $(basename $(readlink .git/HEAD)) = cg-seek-point ]"
test_expect_success 'current commit should be commit1' \
	"[ $(cg-object-id -c) = $commit1 ]"

test_expect_success 'newfile should be gone' \
	"[ ! -e newdir/newfile ]"
# Post-GIT-0.99.8
#test_expect_success 'newdir should be gone' \
#	"[ ! -e newdir ]"
test_expect_success 'different should be v1' \
	"[ $(cat different) = v1 ]"
test_expect_success 'identical should be identical' \
	"[ $(cat identical) = identical ]"

test_expect_success 'seeking to the second commit' \
	"cg-seek $commit2"
test_expect_success 'we should not unseeked properly' \
	"([ -e .git/head-name ] && [ $(basename $(readlink .git/HEAD)) = cg-seek-point ])"
test_expect_success 'current commit should be commit2' \
	"[ $(cg-object-id -c) = $commit2 ]"

test_expect_success 'seeking to the last (well, still second) commit' \
	"cg-seek master"
test_expect_success 'we should be unseeked properly' \
	"([ ! -e .git/head-name ] && [ $(basename $(readlink .git/HEAD)) = master ])"
test_expect_success 'current commit should be commit2' \
	"[ $(cg-object-id -c) = $commit2 ]"

test_expect_success 'newdir/newfile should be back' \
	"[ $(cat newdir/newfile) = v2 ]"
test_expect_success 'different should be v2' \
	"[ $(cat different) = v2 ]"
test_expect_success 'identical should be identical' \
	"[ $(cat identical) = identical ]"

test_expect_success 'local change to identical (non-conflicting)' \
	"echo nonconflicting >identical"
test_expect_success 'local change to newdir/newfile (conflicting)' \
	"echo conflicting >newdir/newfile"

test_expect_success 'seeking to the first commit' \
	"cg-seek $commit1"
test_expect_success 'current commit should be commit1' \
	"[ $(cg-object-id -c) = $commit1 ]"

# This doesn't work properly now since newdir _is_ gone and patch won't recreate it.
#test_expect_success 'newdir should not be gone' \
#	"[ -d newdir ]"
#test_expect_success 'newfile should have rejects' \
#	"[ -e newdir/newfile ] && [ -e newdir/newfile.rej ]"
test_expect_success 'different should be v1' \
	"[ $(cat different) = v1 ]"
test_expect_success 'identical should be nonconflicting' \
	"[ $(cat identical) = nonconflicting ]"

test_expect_success 'unseeking' \
	"cg-seek"
test_expect_success 'we should be unseeked properly' \
	"([ ! -e .git/head-name ] && [ $(basename $(readlink .git/HEAD)) = master ])"
test_expect_success 'current commit should be commit2' \
	"[ $(cg-object-id -c) = $commit2 ]"


test_done
