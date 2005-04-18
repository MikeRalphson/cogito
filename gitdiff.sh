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

diffqfile () {
	dir=$1; shift
	file=$1; shift

	if [ "$dir" = 1 ]; then
		diff -u -L /dev/null -L "b/$file" /dev/null "$file"
	else
		diff -u -L "b/$file" -L /dev/null "$file" /dev/null
	fi
}

diffqueue () {
	ret=1

	dir=$1; shift
	queue=$1; shift

	if [ "$@" ]; then
		for file in "$@"; do
			fgrep -q "$file" "$queue" && diffqfile $dir "$file" \
				&& ret=
		done
	else
		ret=
		for file in $(cat $queue); do
			diffqfile $dir "$file"
		done
	fi

	return $ret
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


if [ "$id2" = " " ]; then
	if [ "$id1" != " " ]; then
		read-tree $(gitXnormid.sh "$id1")
		update-cache --refresh
	fi

	# FIXME: We should squeeze gitdiff-do-alike output from this.
	# TODO: Show diffs for added/removed files based on the queues.
	ret=
	show-diff -q "$@" || ret=1
	[ -s .git/add-queue ] && diffqueue 1 .git/add-queue "$@" && ret=
	[ -s .git/rm-queue  ] && diffqueue 2 .git/rm-queue  "$@" && ret=

	if [ "$id1" != " " ]; then
		read-tree $(tree-id)
		update-cache --refresh
	fi

	[ "$ret" ] && die "no files matched"
	exit $ret
fi


id1=$(gitXnormid.sh "$id1") || exit 1
id2=$(gitXnormid.sh "$id2") || exit 1

[ "$@" ] && die "diffing individual files is not yet supported"
[ "$id1" = "$id2" ] && die "trying to diff $id1 against itself"

diff-tree -r -z $id1 $id2 | xargs -0 gitdiff-do $id1 $id2
