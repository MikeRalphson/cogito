#!/bin/sh
#
# Mark certain commit by a tag.
# Copyright (c) Petr Baudis, 2005
#
# Creates a tag referencing the given commit (or HEAD). You can then
# use the tag anywhere you specify a commit/tree ID.
#
# Takes the tag's name and optionally the associated ID.

name=$1
id=$2

die () {
	echo gittag.sh: $@ >&2
	exit 1
}

[ "$name" ] || die "usage: git tag TNAME [COMMIT_ID]"
[ "$id" ] || id=$(commit-id)

(echo $name | egrep -qv '[^a-zA-Z0-9_.@!:-]') || \
	die "name contains invalid characters"

mkdir -p .git/tags

[ -s ".git/tags/$name" ] && die "tag already exists ($name)"
[ "$id" ] || id=$(cat .git/HEAD)

echo $id >.git/tags/$name
