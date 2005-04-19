#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged.
# Optional "-b base_commit" parameter specifies the base for the merge.
#
# You have to examine the tree after the merge and then do git commit.
#
# Alternatively, it will just bring the HEAD forward, if your current
# HEAD is also the merge base.


die () {
	echo gitmerge.sh: $@ >&2
	exit 1
}

head=$(commit-id)


base=
if [ "$1" = "-b" ]; then
	shift
	[ "$1" ] || die "usage: git merge [-b BASE_ID] FROM_ID"
	base=$(gitXnormid.sh -c "$1") || exit 1; shift
fi

[ "$1" ] || die "usage: git merge [-b BASE_ID] FROM_ID"
branch=$(gitXnormid.sh -c "$1") || exit 1

[ "$base" ] || base=$(merge-base "$head" "$branch")
[ "$base" ] || die "unable to automatically determine merge base"


[ -s .git/blocked ] && die "merge blocked: $(cat .git/blocked)"


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


[ "$(show-diff -s)" ] && update-cache --refresh
if [ "$(show-diff -s)" ] || [ -s .git/add-queue ] || [ -s .git/rm-queue ]; then
	die "merge blocked: local changes"
fi

echo "Merging $base -> $branch" >&2
echo -e "\tto $head..." >&2

echo $base >>.git/merge-base
echo $branch >>.git/merging


read-tree -m $(tree-id $base) $(tree-id $head) $(tree-id $branch) || die "read-tree failed"
if ! merge-cache gitmerge-file.sh -a; then
	checkout-cache -f -a
	read-tree $(tree-id)
	update-cache --refresh >/dev/null

	cat >&2 <<__END__

	Conflicts during merge. Do git commit after resolving them.
__END__
	exit 2
fi

echo
readtree=
git commit -C || { readtree=1 ; echo "gitmerge.sh: COMMIT FAILED, retry manually" >&2; }

checkout-cache -f -a
[ "$readtree" ] && read-tree $(tree-id)
update-cache --refresh
