#!/usr/bin/env bash
#
# Make a patch from a given commit.
# Copyright (c) Petr Baudis, 2005
#
# Takes commit ID, defaulting to HEAD, or id1:id2, forming a range
# (id1;id2]. (Use "id1:" to take just everything from id1 to HEAD.)


showpatch () {
	header=$(mktemp -t gitpatch.XXXXXX)
	id=$1
	cat-file commit $id | while read line; do
		if [ ! "$line" ]; then
			cat
			echo
			echo ---
			echo commit $id
			cat $header
		fi
		echo $line >>$header
	done
	echo
	git diff -p -r $id
	rm $header
}


if echo "$1" | grep -q ':'; then
	id1=$(gitXnormid.sh -c $(echo "$1" | cut -d : -f 1)) || exit 1
	id2=$(gitXnormid.sh -c $(echo "$1" | cut -d : -f 2)) || exit 1

	rev-tree $id2 ^$id1 | sort -n | while read time commit rest; do
		id=$(echo $commit | cut -d : -f 1)
		showpatch $id
		echo
		echo
		echo -e '\014'
		echo '!-------------------------------------------------------------flip-'
		echo
		echo
	done

else
	id=$(gitXnormid.sh -c $1) || exit 1
	showpatch $id
fi
