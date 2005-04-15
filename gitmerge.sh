#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged.
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


if [ "$1" != "-b" ] || [ ! "$2" ]; then
	die "usage: git merge -b BASE_ID FROM_ID"
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

echo $branch >>.git/merging

echo diff-tree $(tree-id "$base") $(tree-id "$branch")
diff-tree $(tree-id "$base") $(tree-id "$branch") | xargs -0 sh -c '
while [ "$1" ]; do
	checkout-cache $(echo "$1" | cut -f 4)
	shift
done
' padding

gitdiff.sh "$base" "$branch" | gitapply.sh

cat >&2 <<__END__
Please inspect the merge in the ,,merge/ subdirectory. Commit from that
directory when you are done. Commits in the current directory are blocked
during the merge.
__END__
