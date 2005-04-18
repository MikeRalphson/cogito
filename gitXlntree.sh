#!/bin/sh
#
# Provide an independent view to the objects database.
# Copyright (c) Petr Baudis, 2005
#
# This script creates a new directory and makes it gitted on the
# same objects database as the current one. It also shares the
# branches and tags information.
#
# The new directory is completely pristine - there's not even
# a directory cache there yet.
#
# Takes the new directory name.

destdir=$1

die () {
	echo gitlntree.sh: $@ >&2
	exit 1
}


[ "$destdir" ] || die "usage: gitXlntree.sh DESTDIR"

srcdir=$(pwd)
dgitdir=$destdir/.git

[ -e "$dgitdir" ] && die "$dgitdir already exists"

mkdir -p "$dgitdir"
ln -s $srcdir/.git/heads $dgitdir/heads
ln -s $srcdir/.git/objects $dgitdir/objects
ln -s $srcdir/.git/remotes $dgitdir/remotes
ln -s $srcdir/.git/tags $dgitdir/tags
