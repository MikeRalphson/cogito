#!/bin/sh
#
# Seek the working tree to a given commit.
# Copyright (c) Petr Baudis, 2005
#
# This will bring the working tree from its current HEAD to a given
# commit. Note that it changes just the HEAD of the working tree, not
# the branch it is corresponding to. It will return to the HEAD of
# the appropriate branch if passed no arguments.
#
# Therefore, for a quick excurse to the past of the 'master' branch:
#
#	git seek git-pasky-0.1
#	git diff this master # will do the correct thing
#	git seek # will restore what we had before
#
# For intiutiveness, specifying the branch name (git seek master) will do
# the right thing too. If you want to migrate your working tree to another
# branch, use git fork.
#
# Takes the target commit ID.

dstcommit=$1

die () {
	echo gitseek.sh: $@ >&2
	exit 1
}


[ -s .git/blocked ] && grep -vq '^seeked from ' .git/blocked && die "action blocked: $(cat .git/blocked)"
if [ -s .git/blocked ]; then
	branch=$(grep '^seeked from ' .git/blocked | sed 's/^seeked from //')
else
	branch=$(basename $(readlink .git/HEAD)) || die "HEAD is not on branch"
fi

curcommit=$(commit-id)

rm .git/HEAD
if [ ! "$dstcommit" ] || [ "$dstcommit" = "$branch" ]; then
	ln -s "heads/$branch" .git/HEAD
	rm .git/blocked
	dstcommit=$(commit-id)
else
	echo $(gitXnormid.sh -c "$dstcommit") >.git/HEAD
	[ -s .git/blocked ] || echo "seeked from $branch" >.git/blocked
fi

if [ "$curcommit" != "$dstcommit" ]; then
	read-tree $(tree-id)
	[ -s .git/add-queue ] && mv .git/add-queue .git/add-queue.orig
	[ -s .git/rm-queue ] && mv .git/rm-queue .git/rm-queue.orig
	git diff -r $curcommit:$dstcommit | git apply
	[ -s .git/add-queue.queue ] && mv .git/add-queue.orig .git/add-queue
	[ -s .git/rm-queue.queue ] && mv .git/rm-queue.orig .git/rm-queue
	update-cache --refresh
fi

echo "On commit $dstcommit"
