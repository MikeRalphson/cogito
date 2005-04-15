#!/bin/sh
#
# Make a diff between two GIT trees.
# Copyright (c) Petr Baudis, 2005
#
# Takes two parameters identifying the two trees/commits to compare.
# Empty string will be substitued to HEAD revision.
#
# -p instead of the first parameter denotes a parent revision
# to the second id (which must not be a tree, obviously).
#
# Outputs a diff converting the first tree to the second one.


id1=$1
id2=$2

if [ "$id1" = "-p" ]; then
	id1=$(parent-id "$id2")
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

diff-tree -r $id1 $id2 | xargs -0 gitdiff-do $id1 $id2
