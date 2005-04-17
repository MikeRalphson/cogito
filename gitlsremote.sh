#!/bin/sh
#
# Lists remote GIT repositories
# Copyright (c) Steven Cole 2005
#
# Takes no parameters

if [ ! -s .git/remotes ]; then
	echo "List of remotes is empty. See git addremote." >&2
	exit 1
fi

cat .git/remotes
