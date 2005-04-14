#!/bin/sh
#
# Makes your working tree track the given branch.
# Copyright (c) Petr Baudis, 2005
#
# This script will make your tree track the given branch (remote).
# Basically, everytime you pull from it, the changes on that branch
# from the last pull will be applied to your tree, and your tree's
# head pointer will be updated.
#
# You can track only one branch; not multiple branches simultanously,
# and they don't even stack. Your branch before checking (probably
# the local branch) can be referenced to by id "local" until you
# untrack (or try to track "local", which is equivalent).
#
# BTW, we do the tracking by applying a patch instead of read-tree &&
# checkout-cache since that will destroy all the local changes but
# also not wipe out any stale files. It is going to be much faster
# anyway.
#
# If you want to offer people a branch which is tracked by default,
# you do not want any local branch. Just delete .git/HEAD.local.
#
# Takes the branch name. No parameter (or "local") untracks the tree.

name=$1

die () {
	echo gittrack.sh: $@ >&2
	exit 1
}

tracking=""
[ -s .git/tracking ] && tracking=$(cat .git/tracking)

[ "$name" = "local" ] && name=""

if [ "$name" ]; then
	[ "$tracking" ] && \
		die "already tracking branch \"$tracking\""
	[ -s ".git/HEAD.$name" ] || \
		die "unknown branch \"$name\" (did you git pull first?)"
	[ -s ".git/HEAD.local" ] && \
		die "not tracking anything but \"local\" branch exists!"

	mv .git/HEAD .git/HEAD.local
	cp ".git/HEAD.$name" .git/HEAD
	echo $name >.git/tracking

	read-tree $(tree-id "$name")
	gitdiff.sh local "$name" | gitapply.sh

else
	[ "$tracking" ] || \
		die "not tracking a branch"
	[ -s ".git/HEAD.$tracking" ] || \
		die "tracked \"$tracking\" branch missing!"

	if [ -s ".git/HEAD.local" ]; then
		gitdiff.sh "$tracking" local | gitapply.sh
		read-tree $(tree-id local)

		head=$(cat .git/HEAD)
		branchhead=$(cat .git/HEAD.$tracking)
		if [ "$head" != "$branchhead" ]; then
			echo "Warning: Overriding \"$tracking\"'s local microbranch:" >&2
			echo -e "\t$branchhead $head" >&2
			echo -e "Write it down, nothing points at it now!\a" >&2
		fi

		mv .git/HEAD.local .git/HEAD
	else
		echo "First-time untracking (no local branch)." >&2
	fi

	rm .git/tracking
fi
