#!/bin/sh
#
# Internal: Normalize the given ID to a tree ID.
# Copyright (c) Petr Baudis, 2005
#
# Takes an arbitrary ID as a parameter. -c tells it to give
# a commit id rather than tree id.

SHA1="[A-Za-z0-9]{40}"
SHA1ONLY="^$SHA1$"
TREE="^tree $SHA1$"

if [ "$1" = "-c" ]; then
	type="commit"
	shift
else
	type="tree"
fi

id=$1
if [ ! "$id" ]; then
	id=$(cat .git/HEAD)
fi

if (echo $id | egrep -vq "$SHA1ONLY") && [ -r ".git/tags/$id" ]; then
	id=$(cat ".git/tags/$id")
fi

if (echo $id | egrep -vq "$SHA1ONLY") && [ -r ".git/HEAD.$id" ]; then
	id=$(cat ".git/HEAD.$id")
fi

idpref=$(echo "$id" | cut -c -2)
idpost=$(echo "$id" | cut -c 3-)
if [ $(find ".git/objects/$idpref" -name "$idpost*" 2>/dev/null | wc -l) -eq 1 ]; then
	id=$idpref$(basename $(echo .git/objects/$idpref/$idpost*))
fi

if echo $id | egrep -vq "$SHA1ONLY"; then
	echo "Invalid id: $id" >&2
	exit 1
fi

if [ "$type" = "tree" ] && [ $(cat-file -t "$id") = "commit" ]; then
	id=$(cat-file commit $id | egrep "$TREE" | cut -d ' ' -f 2)
fi

if [ $(cat-file -t "$id") != "$type" ]; then
	echo "Invalid id: $id" >&2
	exit 1
fi

echo $id
