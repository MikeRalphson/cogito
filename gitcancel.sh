#!/bin/sh
#
# Cancels current edits in the working tree.
# Copyright (c) Petr Baudis, 2005
#
# This script reverts the working tree to a consistent state before
# any changes to it (including merges etc) were done.
#
# Basically, this is the opposite of git commit in some sense.
#
# Takes no arguments and the evil changes from the tree.

[ -s ".git/add-queue" ] && rm $(cat .git/add-queue)
rm -f .git/add-queue .git/rm-queue

rm -f .git/blocked .git/merging .git/merging-sym .git/merge-base
read-tree $(tree-id)

checkout-cache -f -a
update-cache --refresh
