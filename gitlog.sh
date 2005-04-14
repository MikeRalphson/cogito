#!/bin/bash
#
# Make a log of changes in a GIT branch.
#
# This script was originally written by (c) Ross Vandegrift.
# Adapted to his scripts set by (c) Petr Baudis, 2005.
# Major optimizations by (c) Phillip Lougher.
#
# Takes an id resolving to a commit to start from (HEAD by default).

# regex for parent declarations
PARENTS="^parent [A-Za-z0-9]{40}$"

TMPCL=$(mktemp -t gitlog.XXXXXX)
TMPCM=$(mktemp -t gitlog.XXXXXX)

# takes an object and generates the object's parent(s)
changelog () {
	local parents new_parent
	declare -a new_parent

	new_parent=("$@")
	parents=$#

	while [ $parents -gt 0 ]; do
		parent=${new_parent[$(($parents-1))]}
		echo $parent >> $TMPCL

		cat-file commit $parent >$TMPCM

		echo me $parent
		cat $TMPCM
		echo -e "\n--------------------------"

		parents=0
		while read type text; do
			if [ "$type" = "" ]; then
				break;
			elif [ $type = 'parent' ] && ! grep -q $text $TMPCL; then
				new_parent[$parents]=$text
				parents=$(($parents+1))
			fi
		done < $TMPCM

		i=0
		while [ $i -lt $(($parents-1)) ]; do
			changelog ${new_parent[$i]}
			i=$(($i+1))
		done
	done
}

base=$(gitXnormid.sh -c $1) || exit 1

changelog $base
rm $TMPCL $TMPCM
