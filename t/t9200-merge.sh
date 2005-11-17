#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests basic cg-merge functionality

Generates two simple branches, and tests fast-forward cg-merge, clean cg-merge,
cg-merge doing automatic merge, cg-merge with conflicts and baseless cg-merge."

. ./test-lib.sh

# branch1 -> branch2

mkdir branch1
# The blank space is to prevent conflicts for automatic merges.
cat >branch1/brm <<__END__
blah










boo
__END__

>branch1/foo
>branch1/bar
>branch1/baz

test_expect_success 'initialize branch1' \
	"(cd branch1 && cg-init -I && cg-add brm foo bar baz && cg-commit -C -m\"Initial commit\")"
test_expect_success 'fork branch2' \
	"cg-clone branch1 branch2"
test_expect_success 'registering branch2 in branch1' \
	"(cd branch1 && cg-branch-add origin ../branch2)"

echo appended >>branch2/foo
echo newinbranch2forfastforward >branch2/quux
test_expect_success 'adding/removing files in branch2' \
		"(cd branch2 && cg-rm -f baz && cg-add quux)"
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-commit -m\"To-be-fastforwarded commit\")"
test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_success 'merging branch2 to branch1 (fast-forward)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for correct merged content' \
		"(cmp branch2/foo branch1/foo)"
test_expect_success 'checking for properly removed file' \
		"(cd branch1 && [ ! -e baz ])"
test_expect_success 'checking for properly added file' \
		"(cd branch1 && [ -e quux ] && git-ls-files | fgrep -x quux)"
test_expect_success 'checking if it was really a fast-forward' \
		"(cmp branch1/.git/refs/heads/origin branch1/.git/refs/heads/master)"

echo justsomedummystuff >>branch1/bar
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Second commit 1\")"
echo appended >>branch2/brm
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-commit -m\"Second commit 2\")"
test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_success 'merging branch2 to branch1 (clean)' \
		"(cd branch1 && cg-merge </dev/null)"
test_expect_success 'checking for correct merged content' \
		"(cmp branch2/brm branch1/brm)"



mv branch1/brm branch1/brm-old
echo prepended >branch1/brm
cat branch1/brm-old >>branch1/brm
rm branch1/brm-old
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Another commit 1\")"

echo appended2 >>branch2/brm
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-commit -m\"Another commit 2\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_success 'merging branch2 to branch1 (automatic)' \
		"(cd branch1 && cg-merge </dev/null)"
cat >expect <<__END__
prepended
blah










boo
appended
appended2
__END__
test_expect_success 'checking for correct merged content' \
		"(cmp branch1/brm expect)"



echo append conflict1 >>branch1/brm
test_expect_success 'local commit in branch1' \
		"(cd branch1 && cg-commit -m\"Yet another commit 1\")"
echo append conflict2 >>branch2/brm
echo append stuff >>branch2/foo
test_expect_success 'local commit in branch2' \
		"(cd branch2 && cg-commit -m\"Yet another commit 2\")"

test_expect_success 'fetching from branch2 to branch1' \
		"(cd branch1 && cg-fetch)"
test_expect_failure 'merging branch2 to branch1 (conflicting)' \
		"(cd branch1 && cg-merge </dev/null)"
cat >expect <<__END__
prepended
blah










boo
appended
appended2
<<<<<<< master
append conflict1
=======
append conflict2
>>>>>>> origin
__END__
sed 's/merge_file.*$/merge_file/' <branch1/brm >brm-cleaned-up
test_expect_success 'checking for correct conflict content' \
		"(cmp brm-cleaned-up expect)"
test_expect_success 'checking for correct automerge result in the conflicting tree' \
		"(cmp branch2/foo branch1/foo)"



# And now for something totally different...
mkdir branch3
echo branch3file >branch3/b3
cp branch3/b3 branch3/b3-
test_expect_success 'initialize branch3' \
	"(cd branch3 && cg-init -I && cg-add b3 && cg-commit -C -m\"Initial commit\")"
mkdir branch4
echo branch4file >branch4/b4
test_expect_success 'initialize branch4' \
	"(cd branch4 && cg-init -I && cg-add b4 && cg-commit -C -m\"Initial commit\")"
test_expect_success 'fetching branch4 from branch3' \
	"(cd branch3 && cg-branch-add origin ../branch4 && cg-fetch)"
test_expect_failure 'baseless merge of branch3 and branch4' \
	"(cd branch3 && cg-merge)"
test_expect_success 'baseless joining merge of branch3 and branch4' \
	"(cd branch3 && cg-merge -j </dev/null)"
test_expect_success 'verifying merge' \
	"(cd branch3 && cmp b3 b3- && cmp b4 ../branch4/b4)"


test_done
