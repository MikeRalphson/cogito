#!/bin/sh
#
# Make a diff between two GIT trees.
# Copyright (c) Petr Baudis, 2005
#
# By default compares the current working tree to the state at the
# last commit. You can specify -r rev1:rev2 or -r rev1 -r rev2 to
# tell it to make a diff between the specified revisions.
#
# -p instead of one ID denotes a parent commit to the specified ID
# (which must not be a tree, obviously).
#
# Outputs a diff converting the first tree to the second one.


id1=
id2=
parent=

# FIXME: The commandline parsing is awful.

if [ "$1" = "-p" ]; then
	shift
	parent=1
fi

if [ "$1" = "-r" ]; then
	shift
	id1=$(echo "$1": | cut -d : -f 1)
	id2=$(echo "$1": | cut -d : -f 2)
	shift
fi

if [ "$1" = "-r" ]; then
	shift
	id2="$1"
	shift
fi

if [ "$parent" ]; then
	id2="$id1"
	id1=$(parent-id "$id2" | head -n 1)
fi

if [ ! "$id1" ] && [ ! "$id2" ]; then
	# FIXME: We should squeeze gitdiff-do-alike output from this.
	# TODO: Show diffs for added/removed files based on the queues.
	show-diff -q
	exit
fi

id1=$(gitXnormid.sh "$id1") || exit 1
id2=$(gitXnormid.sh "$id2") || exit 1

if [ "$id1" = "$id2" ]; then
	echo "gitdiff.sh: trying to diff $id1 against itself" >&2
	exit 1
fi

diff-tree -r -z $id1 $id2 | xargs -0 gitdiff-do $id1 $id2
