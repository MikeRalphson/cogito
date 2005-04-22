#!/usr/bin/env bash
#
# List objects of the GIT repository.
# Copyright (c) Randy Dunlap, 2005
# Copyright (c) Petr Baudis, 2005
#
# Lists IDs of all the objects of a given type (blob, tree, commit) found
# in the dircache.
#
# Example usage:
# Oh, I was messing with my HEADs and lost few commits, where on the earth
# could they be...?
#	for i in `gitlsobj.sh commit | cut -f 1`; do
#		echo -e "\n==================\nme $i"; cat-file commit $i;
#	done
#
# Takes the object type as the first parameter, defaults to all objects.

target=$1


subdir=.git/objects/

for high in 0 1 2 3 4 5 6 7 8 9 a b c d e f ; do
	for low in 0 1 2 3 4 5 6 7 8 9 a b c d e f ; do
		top=$high$low

		for f in $subdir/$top/* ; do
			if [ ! -r $f ]; then
				continue
			fi
			base=`basename $f`
			type=`cat-file -t $top$base`
			if [ ! "$target" ] || [ $target == $type ]; then
				echo -e "$top$base\t$type"
			fi
		done
	done
done
