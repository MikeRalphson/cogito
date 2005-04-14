#!/bin/sh
#
# Merge a branch to the current tree.
# Copyright (c) Petr Baudis, 2005
#
# Takes a parameter identifying the branch to be merged.
# In front of it, -b base_for_merge must appear. This will
# be made optional in the future.
#
# Outputs rejects to the working tree. ;-)


die () {
	echo gitmerge.sh: $@ >&2
	exit 1
}

if [ "$1" != "-b" ] || [ ! "$2" ]; then
	die "usage: git merge -b base_for_merge merged_branch"
fi

shift
base=$(gitXnormid.sh -c "$1") || exit 1; shift

[ "$1" ] || die "usage: git merge -b base_for_merge merged_branch"

branch=$(gitXnormid.sh -c "$1") || exit 1

gitdiff.sh "$base" "$branch" | gitapply.sh

echo $branch >>.git/merged
