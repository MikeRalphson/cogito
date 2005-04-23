#!/usr/bin/env bash
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

rembranch=master
if echo "$uri" | grep -q '#'; then
	rembranch=$(echo $uri | cut -d '#' -f 2)
	uri=$(echo $uri | cut -d '#' -f 1)
fi


tracking=
[ -s .git/tracking ] && tracking=$(cat .git/tracking)

orig_head=
if [ "$tracking" = "$name" ]; then
	[ -s .git/HEAD.tracked ] && orig_head=$(cat .git/HEAD.tracked)
else
	[ -s ".git/heads/$name" ] && orig_head=$(cat ".git/heads/$name")
fi


mkdir -p .git/heads
rsyncerr=
rsync $RSYNC_FLAGS -Lr "$uri/heads/$rembranch" ".git/heads/$name" 2>/dev/null || rsyncerr=1
if [ "$rsyncerr" ] && [ "$rembranch" = "master" ]; then
	rsyncerr=
	rsync $RSYNC_FLAGS -Lr "$uri/HEAD" ".git/heads/$name" | grep -v '^MOTD:' || rsyncerr=1
fi
[ "$rsyncerr" ] && die "unable to get the head pointer of branch $rembranch"

[ -d .git/objects ] || mkdir -p .git/objects
# We already saw the MOTD, thank you very much.
rsync $RSYNC_FLAGS --ignore-existing --whole-file \
	-v -Lr "$uri/objects/." ".git/objects/." | grep -v '^MOTD:' || die "rsync error"

# FIXME: Warn about conflicting tag names?
# XXX: We now throw stderr to /dev/null since not all repositories
# may have tags/ and users were confused by the harmless errors.
[ -d .git/tags ] || mkdir -p .git/tags
rsync $RSYNC_FLAGS --ignore-existing \
	-v -Lr "$uri/tags/." ".git/tags/." 2>/dev/null | grep -v '^MOTD:' || die "rsync error"


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
	gitmerge.sh "$new_head"
	echo "$new_head" >.git/HEAD.tracked
fi
