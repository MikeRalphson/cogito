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
uri=$(grep $(echo -e "^$name\t") .git/remotes | cut -f 2)
[ "$uri" ] || die "unknown remote"

orig_head=
[ -s ".git/heads/$name" ] && orig_head=$(cat ".git/heads/$name")

mkdir -p .git/heads

rsync -r "$uri/HEAD" ".git/heads/$name"
# We already saw the MOTD, thank you very much.
[ -d .git/objects ] || mkdir -p .git/objects
rsync --ignore-existing --whole-file \
	-r "$uri/objects/." ".git/objects/." >/dev/null
# FIXME: Warn about conflicting tag names?
rsync --ignore-existing -r "$uri/tags" ".git" >/dev/null

new_head=$(cat ".git/heads/$name")

if [ ! "$orig_head" ]; then
	echo "New branch: $new_head"

elif [ "$orig_head" != "$new_head" ]; then
	echo "Tree change: $orig_head $new_head"
	diff-tree $(tree-id $orig_head) $(tree-id $new_head) | tr '\0' '\n'

else
	echo "Up to date."
	exit
fi


tracking=
[ -s .git/tracking ] && tracking=$(cat .git/tracking)
if [ "$tracking" = "$name" ]; then
	echo "Tracked branch, applying changes..."

	head=$(cat .git/HEAD)
	if [ "$head" != "$orig_head" ]; then
		# FIXME: What about filenames starting w/ [+-@]...
		if [ -s ".git/blocked" ]; then
			cat >&2 <<__END__
I wanted to do an automatic merge, however a merge is already in progress.
Please finish it and then execute the merge manually:
	git merge -b $orig_head $new_head
__END__
			exit 2;
		fi

		echo "Merging $orig_head -> $new_head" >&2
		echo -e "\tto $head..." >&2
		gitmerge.sh -b "$orig_head" "$new_head"

	else
		gitdiff.sh "$orig_head" "$new_head" | gitapply.sh
		read-tree $(tree-id $new_head)

		echo $new_head >.git/HEAD
	fi
fi
