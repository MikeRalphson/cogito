#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged.
# Optional "-b base_commit" parameter specifies the base for the
# merge. "-a" parameter may come first to tell git merge
# to check out the full tree to the merge tree.
#
# It creates a new ,,merge/ directory, which is git-controlled
# but has only the changed files checked out. You then have to
# examine it and then do git commit, which will also automatically
# bring your working tree up-to-date.
#
# Alternatively, it will just bring the HEAD forward, if your current
# HEAD is also the merge base.


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

base=
if [ "$1" = "-b" ]; then
	shift
	[ "$1" ] || die "usage: git merge [-a] [-b BASE_ID] FROM_ID"
	base=$(gitXnormid.sh -c "$1") || exit 1; shift
fi

[ "$1" ] || die "usage: git merge [-a] [-b BASE_ID] FROM_ID"
branch=$(gitXnormid.sh -c "$1") || exit 1

[ "$base" ] || base=$(merge-base "$head" "$branch")
[ "$base" ] || die "unable to automatically determine merge base"


[ -e ,,merge ] && die "another merge in progress"
[ -s .git/blocked ] && die "action blocked: $(cat .git/blocked)"


if [ "$head" = "$base" ]; then
	# No need to do explicit merge with a merge commit; just bring
	# the HEAD forward.

	echo "Fast-forwarding $base -> $branch" >&2
	echo -e "\ton top of $head..." >&2
	gitdiff.sh -r "$base":"$branch" | gitapply.sh
	read-tree $(tree-id $branch)
	update-cache --refresh
	echo $branch >.git/HEAD

	exit 0
fi


echo "Merging $base -> $branch" >&2
echo -e "\tto $head..." >&2

echo merging $branch: ,,merge >.git/blocked
gitXlntree.sh ,,merge
echo $(pwd) >,,merge/.git/merging-to
cd ,,merge
read-tree $(tree-id $head)
echo $head >.git/HEAD
echo $branch >>.git/merging

if [ "$checkout_all" ]; then
	checkout-cache -a
else
	diff-tree -r -z $(tree-id "$base") $(tree-id "$branch") | xargs -0 sh -c '
	while [ "$1" ]; do
		checkout-cache $(echo "$1" | cut -f 4)
		shift
	done
	' padding
fi
update-cache --refresh

gitdiff.sh -r "$base":"$branch" | gitapply.sh

cat >&2 <<__END__

Please inspect the merge in the ,,merge/ subdirectory. Commit from that
directory when you are done. Commits in the current directory are blocked
during the merge.
__END__
