#!/bin/sh
#
# Mark certain commit (or current tree) as a branch.
# Copyright (c) Petr Baudis, 2005
#
# Creates a branch with its head at a given commit. If no commit
# is supplied, the current tree's commit is assumed and the current
# tree is automatically made following the newly created branch.
#
# Takes the branch name and optionally the commit which should be
# set as the branch's head.

name=$1
head=$(gitXnormid.sh -c $2)

die () {
	echo gitbranch.sh: $@ >&2
	exit 1
}

([ "$name" ] && [ "$head" ]) || die "usage: git branch BNAME [COMMIT_ID]"

(echo $name | egrep -qv '[^a-zA-Z0-9_.@!:-]') || \
	die "name contains invalid characters"

echo $head >.git/heads/$name

if [ ! "$2" ]; then
	rm .git/HEAD
	ln -s heads/$name .git/HEAD
	echo "On branch $name"
fi
