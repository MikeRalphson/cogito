#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests local cg-fetch

Whether it works at all, basically. ;-) Actually, we will be doing
cg-clones, but that's really just a funny cg-fetch frontend. We will
also test symlinked clone."

. ./test-lib.sh

mkdir repo1
echo file1 >repo1/file1
test_expect_success 'initialize repo1' \
	"(cd repo1 && cg-init -I && cg-add file1 && cg-commit -C -m\"Initial commit\")"
ln -s repo1 repo1.git

test_expect_failure 'clone repo2 from non-existing repo' \
	"cg-clone /.somethingwhichmustnotexist repo2"
touch phantomfile
test_expect_failure 'clone repo2 from repo which is really a file' \
	"cg-clone phantomfile repo2"
test_expect_failure 'clone repo1 from repo1' \
	"cg-clone repo1 repo1"
test_expect_success 'clone repo2 from repo1' \
	"cg-clone repo1 repo2"
test_expect_failure 'clone repo2 in-current-dir from repo1' \
	'cg-clone -s repo1 repo2'
rm -rf repo2
test_expect_failure 'clone now-gone repo2 in-current-dir from repo1' \
	'cg-clone -s repo1 repo2'
test_expect_success 'symlinked clone of repo2 from repo1' \
	'(cd repo2 && cg-clone -l repo1 repo2)'
rm -rf repo2
mkdir repo2
test_expect_success 'clone in-current-dir repo2 from $(pwd)/../repo1/../repo1.git/' \
	'(cd repo2 && cg-clone -s $(pwd)/../repo1/../repo1.git/)'

echo file1v2 >repo1/file1
test_expect_success 'commit in repo1' \
	"(cd repo1 && git-update-index file1 && cg-commit -m\"Second commit\")"
test_expect_success 'incremental fetch in repo2' \
	"(cd repo2 && cg-fetch)"
test_expect_success 'verifying incremental fetch' \
	"(cmp repo1/.git/refs/heads/master repo2/.git/refs/heads/origin &&
	  cd repo2 && git-fsck-objects)"

echo file1v3 >repo1/file1
test_expect_success 'commit in repo1' \
	"(cd repo1 && git-update-index file1 && cg-commit -m\"Third commit\")"
test_expect_success 'rewriting HEAD of repo1 to symbolic' \
	'(rm repo1/.git/HEAD && echo "ref: refs/heads/master" >repo1/.git/HEAD)'
test_expect_success 'incremental fetch in repo2' \
	"(cd repo2 && cg-fetch)"
test_expect_success 'verifying incremental fetch' \
	"(cmp repo1/.git/refs/heads/master repo2/.git/refs/heads/origin &&
	  cd repo2 && git-fsck-objects)"

rm -rf repo2
test_expect_success 'clone -l repo2 from repo1' \
	'cg-clone -l repo1 repo2'
test_expect_success 'incremental fetch in repo2' \
	'(cd repo2 && cg-fetch >blah && [ "$(tail -n 1 blah)" = "Up to date." ])'
test_expect_success 'incremental update in repo2' \
	'(cd repo2 && cg-update)'
test_expect_success 'verifying incremental update' \
	"(cmp repo1/.git/refs/heads/master repo2/.git/refs/heads/master &&
	  cd repo2 && git-fsck-objects)"

test_done
