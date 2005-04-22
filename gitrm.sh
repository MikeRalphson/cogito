#!/usr/bin/env bash
#
# Remove a file from a GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# Takes a list of file names at the command line, and schedules them
# for removal from the GIT repository at the next commit.

if [ ! "$1" ]; then
	echo "gitrm.sh: usage: git rm FILE..." >&2
	exit 1;
fi

rm -f "$@"
update-cache --remove -- "$@"
