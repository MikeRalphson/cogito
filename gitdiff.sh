#!/bin/sh
#
# Make a diff between two GIT trees.
# Copyright (c) Petr Baudis, 2005
#
# By default compares the current working tree to the state at the
# last commit. You can specify -r rev1:rev2 or -r rev1 -r rev2 to
# tell it to make a diff between the specified revisions. If you
# do not specify a revision, the current working tree is implied
# (note that no revision is different from empty revision - -r rev:
# compares between rev and HEAD, while -r rev compares between rev
# and working tree).
#
# -p instead of one ID denotes a parent commit to the specified ID
# (which must not be a tree, obviously).
#
# Outputs a diff converting the first tree to the second one.


id1=" "
id2=" "
parent=


die () {
	echo gitdiff.sh: $@ >&2
	exit 1
}


# FIXME: The commandline parsing is awful.

if [ "$1" = "-p" ]; then
	shift
	parent=1
fi

if [ "$1" = "-r" ]; then
	shift
	id1=$(echo "$1": | cut -d : -f 1)
	[ "$id1" != "$1" ] && id2=$(echo "$1": | cut -d : -f 2)
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


[ "$@" ] && die "diffing individual files is currently not supported, sorry"

if [ "$id2" = " " ]; then
	if [ "$id1" != " " ]; then
		export GIT_INDEX_FILE=$(mktemp -t gitdiff.XXXXXX)
		read-tree $(gitXnormid.sh "$id1")
		update-cache --refresh
		tree=$(gitXnormid.sh "$id1")
	else
		tree=$(tree-id)
	fi

	# FIXME: We should squeeze gitdiff-do-alike output from this.
	# FIXME: Update ret based on what did we match. And take "$@"
	# to account after all.
	ret=
	diff-cache -r -z $tree | xargs -0 gitdiff-do "$tree" uncommitted

	if [ "$id1" != " " ]; then
		rm $GIT_INDEX_FILE
	fi

	[ "$ret" ] && die "no files matched"
	exit $ret
fi


id1=$(gitXnormid.sh "$id1") || exit 1
id2=$(gitXnormid.sh "$id2") || exit 1

[ "$id1" = "$id2" ] && die "trying to diff $id1 against itself"

diff-tree -r -z $id1 $id2 | xargs -0 gitdiff-do $id1 $id2
