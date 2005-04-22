#!/bin/sh
#
# Add new file to a GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# Takes a list of file names at the command line, and schedules them
# for addition to the GIT repository at the next commit.

if [ ! "$1" ]; then
	echo "gitadd.sh: usage: git add FILE..." >&2
	exit 1;
fi

update-cache --add -- "$@"
