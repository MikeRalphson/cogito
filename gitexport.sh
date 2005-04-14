#!/bin/sh
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

[ "$destdir" == "" ] && die "usage: gitexport.sh <DESTDIR> [<ID>]"

[ -e "$destdir" ] && die "$1 already exists."

id=$(gitXnormid.sh $2) || exit 1

read-tree $id

oldpwd="$(pwd)"
dircache="$oldpwd"/.git

mkdir "$destdir" || die "Could not create $destdir"

cd "$destdir" || die "Huh? Could not change directory"

ln -s "$dircache" . || die "Could not link .git"

checkout-cache -a && rm .git

cd "$oldpwd" && read-tree $(tree-id) && update-cache --refresh
