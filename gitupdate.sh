#!/bin/sh
#
# Update the working tree to a given commit.
# Copyright (c) Petr Baudis, 2005
#
# This will bring the working tree from its current HEAD to a given
# commit. Note that it changes just the HEAD of the working tree, not
# the branch it is corresponding to. Therefore, for a master tree:
#
#	git up git-pasky-0.1
#	git diff this master # will do the correct thing
#	git up master # will restore what we had before
#
# Takes the target commit ID.

dstcommit=$(gitXnormid.sh -c $1)

die () {
	echo gitupdate.sh: $@ >&2
	exit 1
}


[ "$dstcommit" ] || die "usage: git update COMMIT_ID"

curcommit=$(commit-id)

rm .git/HEAD
if [ -s ".git/heads/$1" ]; then
	ln -s heads/$1 .git/HEAD
else
	echo $dstcommit >.git/HEAD
fi

if [ "$curcommit" != "$dstcommit" ]; then
	read-tree $(tree-id)
	git diff -r $curcommit:$dstcommit | git apply
	update-cache --refresh
fi

echo "On commit $dstcommit"
