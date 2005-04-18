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
# and they don't even stack. You track the branch on the top of your
# current HEAD. One good way to set up a tree which will be just
# mirroring a given remote branch could be:
#
#	git fork pasky-l ~/pasky pasky
#	cd ~/pasky
#	git track pasky
#
# BTW, we do the tracking by applying a patch instead of read-tree &&
# checkout-cache since that will destroy all the local changes but
# also not wipe out any stale files. It is going to be much faster
# anyway.
#
# Takes the branch name. No parameter untracks the tree.

name=$1

die () {
	echo gittrack.sh: $@ >&2
	exit 1
}

[ -e .git/remotes ] || >.git/remotes
mkdir -p .git/heads

if [ "$name" ]; then
	grep -q $(echo -e "^$name\t" | sed 's/\./\\./g') .git/remotes || \
		[ -s ".git/heads/$name" ] || \
		die "unknown branch \"$name\""

	echo $name >.git/tracking

else
	[ -s .git/tracking ] || \
		die "not tracking any branch"

	rm .git/tracking
fi
