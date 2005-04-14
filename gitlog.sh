#!/bin/bash
#
# Make a log of changes in a GIT branch.
#
# This script was originally written by (c) Ross Vandegrift.
# Adapted to his scripts set by (c) Petr Baudis, 2005.
# Major optimizations by (c) Phillip Lougher.
# Rendered trivial by Linus Torvalds.
#
# Takes an id resolving to a commit to start from (HEAD by default).

base=$(gitXnormid.sh -c $1) || exit 1

rev-tree $base | sort -rn | while read time commit parents; do
	echo me ${commit%:*};
	cat-file commit $commit
	echo -e "\n--------------------------"
done
