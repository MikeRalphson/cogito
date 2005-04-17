#!/bin/sh
#
# Initialize a GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# Takes an optional parameter which will make it "clone" a specified
# remote repository by pulling it and then making the current tree
# tracking it.

uri=$1


die () {
	echo gitinit.sh: $@ >&2
	exit 1
}

[ -e .git ] && die ".git already exists"

init-db
mkdir .git/heads .git/tags
touch .git/heads/master
ln -s heads/master .git/HEAD

if [ "$uri" ]; then
	echo -e "origin\t$uri" >.git/remotes
	git pull origin || die "pull failed"

	cp .git/heads/origin .git/heads/master
	read-tree $(tree-id)
	checkout-cache -a
	update-cache --refresh

	# We are tracked by default
	echo origin >.git/tracking

	echo "Cloned and tracking branch \"origin\" ($uri)"
fi
