#!/bin/sh
#
# Remove a file from a GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# Takes a list of file names at the command line, and schedules them
# for addition to the GIT repository at the next commit.
#
# FIXME: Those files are omitted from show-diff output!

if [ ! "$1" ]; then
	echo "gitrm.sh: usage: git rm FILE..." >&2
	exit 1;
fi

for file in "$@"; do
	[ -e "$file" ] && rm "$file"
	echo $file >>.git/rm-queue
done
