#!/bin/sh
#
# Create a branch sharing the objects database.
# Copyright (c) Petr Baudis, 2005
#
# This script creates a new branch in a given directory, sharing
# the same objects database with the branch in the current directory,
# and forking from it at the latest commit. You can use the name
# of the branch as an ID in all the other branches sharing the
# objects database.
#
# The new directory has a fresh checkout of the current tree.
#
# Takes the new branch name and its directory name.

name=$1
destdir=$2

die () {
	echo gitfork.sh: $@ >&2
	exit 1
}


([ "$name" ] && [ "$destdir" ]) || die "usage: git fork BNAME DESTDIR"

if [ "$name" = "local" ] || [ "$name" = "this" ]; then
	die "given branch name is reserved"
fi
if grep -q $(echo -e "^$name\t" | sed 's/\./\\./g') .git/remotes \
   || [ -s ".git/heads/$name" ]; then
	die "branch already exists"
fi

[ -e "$destdir" ] && die "$destdir already exists"

git lntree "$destdir"
cat .git/HEAD >.git/heads/$name
ln -s heads/$name "$destdir/.git/HEAD"

cd "$destdir"
read-tree $(tree-id)
checkout-cache -a
update-cache --refresh

echo "Branch $name ready in $destdir"
