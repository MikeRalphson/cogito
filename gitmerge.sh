#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged, and for now
# compulsory "-b base_commit" parameter specifying the base for the
# merge. Optionally, "-a" parameter may come first to tell git merge
# to check out the full tree to the merge tree.
#
# It creates a new ,,merge/ directory, which is git-controlled
# but has only the changed files checked out. You then have to
# examine it and then do git commit, which will also automatically
# bring your working tree up-to-date.


die () {
	echo gitmerge.sh: $@ >&2
	exit 1
}

head=$(commit-id)


checkout_all=
if [ "$1" = "-a" ]; then
	checkout_all=1
	shift
fi

if [ "$1" != "-b" ] || [ ! "$2" ]; then
	die "usage: git merge [-a] -b BASE_ID FROM_ID"
fi
shift
base=$(gitXnormid.sh -c "$1") || exit 1; shift

[ "$1" ] || die "usage: git merge -b BASE_ID FROM_ID"
branch=$(gitXnormid.sh -c "$1") || exit 1


if [ -e .git/blocked ] || [ -e ,,merge ]; then
	die "another merge in progress"
fi

echo merge >.git/blocked
git lntree ,,merge
echo $(pwd) >,,merge/.git/merging-to
cd ,,merge
read-tree $(tree-id $head)
echo $head >.git/HEAD
echo $branch >>.git/merging

if [ "$checkout_all" ]; then
	checkout-cache -a
else
	diff-tree $(tree-id "$base") $(tree-id "$branch") | xargs -0 sh -c '
	while [ "$1" ]; do
		checkout-cache $(echo "$1" | cut -f 4)
		shift
	done
	' padding
fi
update-cache --refresh

gitdiff.sh "$base" "$branch" | gitapply.sh

cat >&2 <<__END__
Please inspect the merge in the ,,merge/ subdirectory. Commit from that
directory when you are done. Commits in the current directory are blocked
during the merge.
__END__
