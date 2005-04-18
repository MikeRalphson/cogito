#!/bin/sh
#
# Show status of entries in your working tree.
# Copyright (c) Petr Baudis, 2005

{
	show-files -z -t --others --deleted --unmerged
	[ -s .git/add-queue ] && cat .git/add-queue | sed 's/^/A /;s/$/\0/'
	[ -s .git/rm-queue ] && cat .git/rm-queue | sed 's/^/D /;s/$/\0/'
} | sort -z -k 2 | xargs -0 sh -c '
while [ "$1" ]; do
	tag=$(echo "$1" | cut -d " " -f 1);
	filename=$(echo "$1" | cut -d " " -f 2-);
	case "$filename" in
	*.o | tags) ;;
	*)   echo "$tag $filename";;
	esac
	shift
done
' padding
