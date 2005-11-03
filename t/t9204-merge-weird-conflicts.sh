#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests cg-merge 'dealing' with non-trivial conflicts

Generates two simple branches, and tests how cg-merge responds to various
conflicting situations. Basically, if it generated conflict every time
it should do so."

. ./test-lib.sh

# branch1 -> branch2

mkdir branch1
echo "file1" >branch1/file1

test_expect_success 'initialize branch1' \
	"(cd branch1 && cg-init -I && cg-add file1 && cg-commit -C -m\"Initial commit\")"
test_expect_success 'fork branch2' \
	"cg-clone branch1 branch2"
test_expect_success 'registering branch2 in branch1' \
	"(cd branch1 && cg-branch-add origin ../branch2)"


echo "file1 branch1" >branch1/file1
echo "file1 branch1" >branch1/file1-
test_expect_success 'content change in branch1' \
		"(cd branch1 && cg-commit -m\"Content change\")"
chmod a+x branch2/file1
test_expect_success 'mode change in branch2' \
		"(cd branch2 && cg-commit -m\"Mode change\")"
test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_failure 'merging branch2 to branch1 (should conflict)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for defaulting to +x' \
		"([ -x branch1/file1 ])"
test_expect_success 'checking for properly merged content' \
		"(cmp branch1/file1 branch1/file1-)"


echo "new file2" >branch1/file2
test_expect_success 'identical file added in branch1' \
		"(cd branch1 && cg-add file2 && cg-commit -m\"Identical file add\")"
echo "new file2" >branch2/file2
test_expect_success 'identical file added in branch2' \
		"(cd branch2 && cg-add file2 && cg-commit -m\"Identical file add\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_success 'merging branch2 to branch1 (should success)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for the proper file being added' \
		"(cmp branch1/file2 branch2/file2)"


echo "new file3" >branch1/file3
test_expect_success 'identical file added in branch1' \
		"(cd branch1 && cg-add file3 && cg-commit -m\"Identical file add\")"
echo "new file3" >branch2/file3
chmod a+x branch2/file3
test_expect_success 'identical file added in branch2, but with +x' \
		"(cd branch2 && cg-add file3 && cg-commit -m\"+x file add\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_failure 'merging branch2 to branch1 (should conflict)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for the proper file being added...' \
		"(cmp branch1/file3 branch2/file3)"
test_expect_success '...defaulting to +x' \
		"([ -x branch1/file3 ])"


echo "new file4 branch1" >branch1/file4
echo "new file4 branch1" >branch1/file4-
test_expect_success 'different file added in branch1' \
		"(cd branch1 && cg-add file4 && cg-commit -m\"Different file add\")"
echo "new file4 branch2" >branch2/file4
chmod a+x branch2/file4
test_expect_success 'different file added in branch2' \
		"(cd branch2 && cg-add file4 && cg-commit -m\"Different file add\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_failure 'merging branch2 to branch1 (should conflict)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for the proper conflict being generated for branch1' \
		"(cmp branch1/file4~1 branch1/file4-)"
test_expect_success 'checking for the proper conflict being generated for branch2' \
		"(cmp branch1/file4~2 branch2/file4 && [ -x branch2/file4 ])"
test_expect_success 'checking for the proper conflict being generated (no file4)' \
		"([ ! -e branch1/file4 ])"


test_expect_success 'resolving the last conflict' \
		"(cd branch1 && mv file4~1 file4 && cg-commit -m\"Resolved\")"
test_expect_success 'removing branch1/file4' \
		"(cd branch1 && cg-rm -f file4 && cg-commit -m\"Killed file4\")"
test_expect_success 'removing branch2/file4' \
		"(cd branch2 && cg-rm -f file4 && cg-commit -m\"Killed file4\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_success 'merging branch2 to branch1 (should not conflict)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for the proper conflict resolution (file4 gone)' \
		"([ ! -e branch1/file4 ])"


test_expect_success 'removing branch1/file3' \
		"(cd branch1 && cg-rm -f file3 && cg-commit -m\"Killed file3\")"
test_expect_success 'modifying branch2/file3' \
		"(cd branch2 && echo modificaton >>file3 && chmod a+x file3 && cg-commit -m\"Modified file3\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_failure 'merging branch2 to branch1 (should conflict)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for the proper conflict being generated for branch2' \
		"(cmp branch1/file3~2 branch2/file3 && [ -x branch2/file3 ])"
test_expect_success 'checking for the proper conflict being generated (no file3)' \
		"([ ! -e branch1/file3 ])"


test_done
