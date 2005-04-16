#!/bin/sh
#
# Clone a GIT repository from a remote source.
# Copyright (c) Petr Baudis, 2005

uri=$1


die () {
	echo gitclone.sh: $@ >&2
	exit 1
}

[ "$uri" ] || die "usage: git clone RSYNC_URL"

git init || die "init failed"

echo -e "origin\t$uri" >.git/remotes
git pull origin || die "pull failed"

cp .git/heads/origin .git/heads/master
read-tree $(tree-id)
checkout-cache -a
update-cache --refresh

# We are tracked by default
echo origin >.git/tracking

echo "Cloned and tracking branch \"origin\" ($uri)"
