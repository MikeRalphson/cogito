#!/bin/sh
#
# Make a patch from a given commit.
# Copyright (c) Petr Baudis, 2005
#
# Takes commit ID, defaulting to HEAD.

id=$(gitXnormid.sh -c $1) || exit 1

echo commit $id
cat-file commit $id
echo
git diff -p -r $id
