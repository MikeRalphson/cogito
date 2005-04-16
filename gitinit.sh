#!/bin/sh
#
# Initialize a GIT repository.
# Copyright (c) Petr Baudis, 2005


die () {
	echo gitinit.sh: $@ >&2
	exit 1
}

[ -e .git ] && die ".git already exists"

init-db
mkdir .git/heads .git/tags
touch .git/heads/master
ln -s heads/master .git/HEAD
