#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests cg-merge done on a tree with local modifications

Under certain conditions, cg-merge can be done even on a tree with local
modifications. This test should ensure that no local changes are lost, while
they also shan't interfere with the committed merge."

. ./test-lib.sh

# branch1 -> branch2

test_add_block()
{
	test_expect_success 'local change on branch1 (add, should block)' \
			"(cd branch1 && echo boo >y && cg-add y)"
	cp branch1/y branch1/y-
	test_expect_failure "merging branch2 to branch1 ($1)" \
			"(cd branch1 && cg-merge </dev/null)"
	test_expect_success 'checking if we still have our local change' \
			'(cd branch1 && cg-status -w | grep -q "^A y" && cmp y y-)'
	test_expect_success 'undoing the local change' \
			'(cd branch1 && cg-rm -f y)'
	test_expect_success 'confirming that we have no uncommitted modifications' \
			'(cd branch1 && [ -z "$(git-diff-index -r $(cg-object-id -t))" ])'
}

commit_and_propagate()
{
	test_expect_success 'local commit in branch2' \
			"(cd branch2 && cg-commit -m\"Some commit\")"
	test_expect_success 'fetching from branch2 to branch1' \
			"(cd branch1 && cg-fetch)"
}

mkdir branch1
# The blank space is to prevent conflicts for automatic merges.
cat >branch1/brm <<__END__
blah










boo
__END__

>branch1/foo
>branch1/bar

test_expect_success 'initialize branch1' \
	"(cd branch1 && cg-init -I && cg-add brm foo bar && cg-commit -C -m\"Initial commit\")"
test_expect_success 'fork branch2' \
	"cg-clone branch1 branch2"
test_expect_success 'registering branch2 in branch1' \
	"(cd branch1 && cg-branch-add origin ../branch2)"

echo appended >>branch2/foo
commit_and_propagate

test_expect_success 'local change on branch1 (should not block)' \
		"(cd branch1 && echo boo >x && cg-add x)"
cp branch1/x branch1/x-
test_expect_success 'merging branch2 to branch1 (fast-forward)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking if we still have our local change' \
		'(cd branch1 && cg-status -w | grep -q "^A x" && cmp x x-)'


test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Branch1 commit\")"


echo appended >>branch2/foo
commit_and_propagate

test_add_block "clean"

test_expect_success 'local change on branch1 (modify in same, should block)' \
		"(cd branch1 && echo appended-too >>foo)"
cp branch1/foo branch1/foo-
test_expect_failure 'merging branch2 to branch1 (clean)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking if we still have our local change' \
		'(cd branch1 && cg-status -w | grep -q "^m foo" && cmp foo foo-)'
# This test is useful if the previous one failed - did it get lost or
# accidentally committed?
test_expect_success 'checking that we didn'\''t commit the local change' \
		'(cd branch1 && cg-admin-cat foo >foo-tree && ! cmp foo- foo-tree)'
test_expect_success 'undoing the local change' \
		'(cd branch1 && cg-restore -f foo)'
test_expect_success 'confirming that we have no uncommitted modifications' \
		'(cd branch1 && [ -z "$(git-diff-index -r $(cg-object-id -t))" ])'

test_expect_success 'local change on branch1 (modify in different, should not block)' \
		"(cd branch1 && echo moo >bar)"
cp branch1/bar branch1/bar-
test_expect_success 'merging branch2 to branch1 (clean)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking if we still have our local change' \
		'(cd branch1 && cg-status -w | grep -q "^M bar" && cmp bar bar-)'
# This test is useful if the previous one failed - did it get lost or
# accidentally committed?
test_expect_success 'checking that we didn'\''t commit the local change' \
		'(cd branch1 && cg-admin-cat bar >bar-tree && ! cmp bar- bar-tree)'


mv branch1/brm branch1/brm-old
echo prepended >branch1/brm
cat branch1/brm-old >>branch1/brm
rm branch1/brm-old
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Branch1 commit\")"


echo appended2 >>branch2/brm
commit_and_propagate

test_add_block "automatic"

test_expect_success 'local change on branch1 (modify in different, should not block)' \
		"(cd branch1 && echo poo >bar)"
cp branch1/bar branch1/bar-
cp branch1/brm branch1/brm-
test_expect_success 'merging branch2 to branch1 (automatic)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking if the working copy was touched by the merge' \
		'(cd branch1 && ! cmp brm brm-)'
test_expect_success 'checking if we still have our local change' \
		'(cd branch1 && cg-status -w | grep -q "^M bar" && cmp bar bar-)'
# This test is useful if the previous one failed - did it get lost or
# accidentally committed?
test_expect_success 'checking that we didn'\''t commit the local change' \
		'(cd branch1 && cg-admin-cat bar >bar-tree && ! cmp bar- bar-tree)'


echo conflicting >>branch1/brm
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Branch1 commit\")"


# Theoretically the following commit should be superfluous, but we would get
# false successful merge if the previous test failed and merge succeeded.

echo appended3 >>branch2/brm
commit_and_propagate

test_add_block "conflicting"

test_expect_success 'local change on branch1 (modify in different, should not block)' \
		"(cd branch1 && echo zoo >bar)"
cp branch1/bar branch1/bar-
cp branch1/brm branch1/brm-
test_expect_failure 'merging branch2 to branch1 (conflicting)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking if the merge caused a conflict' \
		'(cd branch1 && grep "<<<" brm)'
# <now imagine me resolving the conflict>
test_expect_success 'committing "resolved" conflicting merge' \
		'(cd branch1 && cg-commit -m"Resolved conflicting merge")'
test_expect_success 'checking if we still have our local change' \
		'(cd branch1 && cg-status -w | grep -q "^M bar" && cmp bar bar-)'
# This test is useful if the previous one failed - did it get lost or
# accidentally committed?
test_expect_success 'checking that we didn'\''t commit the local change' \
		'(cd branch1 && cg-admin-cat bar >bar-tree && ! cmp bar- bar-tree)'


test_done
