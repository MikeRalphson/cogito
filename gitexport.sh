#!/usr/bin/env bash
#
# Exports a particular revision from a GIT repository.
# Copyright (c) Johannes E. Schindelin, 2005
#
# Takes a target directory and optionally an id as a parameter,
# defaulting to HEAD.

die () {
	echo gitexport.sh: $@ >&2
	exit 1
}

destdir=$1
id=$(gitXnormid.sh $2)

([ "$destdir" ] && [ "$id" ]) || die "usage: git export DESTDIR [TREE_ID]"

[ -e "$destdir" ] && die "$destdir already exists."

mkdir -p $destdir || die "cannot create $destdir"
export GIT_INDEX_FILE="$destdir/.git-index"
read-tree $id
checkout-cache "--prefix=$destdir/" -a
rm $GIT_INDEX_FILE
