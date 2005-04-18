#!/bin/sh
#
# Pulls changes from "remote" to the local GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# See gitaddremote.sh for some description.
#
# Takes the remote's name.

name=$1

die () {
	echo gitpull.sh: $@ >&2
	exit 1
}


[ "$name" ] || name=$(cat .git/tracking 2>/dev/null)
[ "$name" ] || die "where to pull from?"
uri=$(grep $(echo -e "^$name\t" | sed 's/\./\\./g') .git/remotes | cut -f 2)
[ "$uri" ] || die "unknown remote"


tracking=
[ -s .git/tracking ] && tracking=$(cat .git/tracking)

orig_head=
if [ "$tracking" ]; then
	[ -s .git/HEAD.tracked ] && orig_head=$(cat .git/HEAD.tracked)
else
	[ -s ".git/heads/$name" ] && orig_head=$(cat ".git/heads/$name")
fi


mkdir -p .git/heads
rsync $RSYNC_FLAGS -Lr "$uri/HEAD" ".git/heads/$name"

[ -d .git/objects ] || mkdir -p .git/objects
# We already saw the MOTD, thank you very much.
rsync $RSYNC_FLAGS --ignore-existing --whole-file \
	-r "$uri/objects/." ".git/objects/." | grep -v '^MOTD:'

# FIXME: Warn about conflicting tag names?
rsync $RSYNC_FLAGS --ignore-existing -r "$uri/tags" ".git" | grep -v '^MOTD:'


new_head=$(cat ".git/heads/$name")

if [ ! "$orig_head" ]; then
	echo "New branch: $new_head"

elif [ "$orig_head" != "$new_head" ]; then
	echo "Tree change: $orig_head:$new_head"
	diff-tree -r $(tree-id $orig_head) $(tree-id $new_head)

else
	echo "Up to date."
	exit
fi


if [ "$tracking" = "$name" ]; then
	echo "Tracked branch, applying changes..."

	head=$(commit-id)
	[ "$orig_head" ] || orig_head=$(merge-base "$head" "$new_head")
	echo "$new_head" >.git/HEAD.tracked

	gitmerge.sh -b "$orig_head" "$new_head"
fi
