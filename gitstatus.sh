#!/bin/sh
#
# Show status of entries in your working tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes no arguments.

{
	show-files -z -t --others --deleted --unmerged
	[ -s .git/add-queue ] && cat .git/add-queue | sed 's/^/A /' | { read x; echo -ne $x'\0'; }
	[ -s .git/rm-queue ] && cat .git/rm-queue | sed 's/^/D /' | { read x; echo -ne $x'\0'; }
} | sort -z -k 2 | xargs -0 sh -c '
while [ "$1" ]; do
	tag=${1% *};
	filename=${1#* };
	case "$filename" in
	*.[ao] | tags | ,,merge*) ;;
	*)   echo "$tag $filename";;
	esac
	shift
done
' padding
