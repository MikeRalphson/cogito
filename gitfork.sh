#!/usr/bin/env bash
#
# Create a branch sharing the objects database.
# Copyright (c) Petr Baudis, 2005
#
# This script creates a new branch (or revives an unused old branch)
# in a given directory, sharing the same objects database with the
# branch in the current directory, and forking from it at the latest
# commit (in the case of a new branch). You can use the name
# of the branch as an ID in all the other branches sharing the
# objects database.
#
# The new directory has a fresh checkout of the branch.
#
# Takes the desired branch name, its directory name, and potentially
# the head commit ID (for new branch).

name=$1
destdir=$2
head=$(commit-id $3)

die () {
	echo gitfork.sh: $@ >&2
	exit 1
}


([ "$name" ] && [ "$destdir" ]) || die "usage: git fork BNAME DESTDIR [COMMIT_ID]"

if [ "$name" = "this" ] || [ "$name" = "HEAD" ]; then
	die "given branch name is reserved"
fi
if grep -q $(echo -e "^$name\t" | sed 's/\./\\./g') .git/remotes; then
	die "cannot fork remote branch"
fi

[ -e "$destdir" ] && die "$destdir already exists"

gitXlntree.sh "$destdir"
# FIXME: We should allow only forkign unused branches!
[ -s ".git/heads/$name" ] || echo $head >.git/heads/$name
ln -s heads/$name "$destdir/.git/HEAD"

cd "$destdir"
read-tree $(tree-id)
checkout-cache -a
update-cache --refresh

echo "Branch $name ready in $destdir with head $head"
