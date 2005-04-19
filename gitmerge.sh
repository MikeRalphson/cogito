#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged.
# Optional "-b base_commit" parameter specifies the base for the merge.
# Optional "-c" parameter specifies that you want to have tree merge
# never autocomitted, but want to review and commit it manually.
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


careful=
if [ "$1" = "-c" ]; then
	shift
	careful=1
fi

base=
if [ "$1" = "-b" ]; then
	shift
	[ "$1" ] || die "usage: git merge [-c] [-b BASE_ID] FROM_ID"
	base=$(gitXnormid.sh -c "$1") || exit 1; shift
fi

[ "$1" ] || die "usage: git merge [-c] [-b BASE_ID] FROM_ID"
branchname="$1"
branch=$(gitXnormid.sh -c "$branchname") || exit 1

[ "$base" ] || base=$(merge-base "$head" "$branch")
[ "$base" ] || die "unable to automatically determine merge base"


[ -s .git/blocked ] && die "merge blocked: $(cat .git/blocked)"


if [ "$base" = "$branch" ]; then
	echo "Branch already fully merged." >&2
	exit 0
fi

if [ "$head" = "$base" ]; then
	# No need to do explicit merge with a merge commit; just bring
	# the HEAD forward.

	echo "Fast-forwarding $base -> $branch" >&2
	echo -e "\ton top of $head..." >&2

	patchfile=$(mktemp -t gitmerge.XXXXXX)
	gitdiff.sh >$patchfile
	read-tree -m $(tree-id $branch)
	checkout-cache -f -a
	patch -p1 <$patchfile
	rm $patchfile

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
echo $branchname >>.git/merging-sym


read-tree -m $(tree-id $base) $(tree-id $head) $(tree-id $branch) || die "read-tree failed"
if ! merge-cache gitmerge-file.sh -a || [ "$careful" ]; then
	checkout-cache -f -a
	read-tree -m $(tree-id)
	update-cache --refresh >/dev/null

	[ ! "$careful" ] && cat >&2 <<__END__

	Conflicts during merge. Do git commit after resolving them.
__END__
	exit 2
fi

echo
readtree=
git commit -C || { readtree=1 ; echo "gitmerge.sh: COMMIT FAILED, retry manually" >&2; }

checkout-cache -f -a
[ "$readtree" ] && read-tree -m $(tree-id)
update-cache --refresh
