#!/usr/bin/env bash
#
# Show status of entries in your working tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes no arguments.

{
	show-files -z -t --others --deleted --unmerged
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
