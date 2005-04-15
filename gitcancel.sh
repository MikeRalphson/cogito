#!/bin/sh
#
# Cancels current edits in the working tree.
# Copyright (c) Petr Baudis, 2005
#
# This script reverts the working tree to a consistent state before
# any changes to it (including merges etc) were done.
#
# Basically, this is the negation of git commit in some sense.
#
# Takes no arguments. Takes the evil changes from the tree.

rm -f .git/add-queue .git/rm-queue
checkout-cache -f -a

update-cache --refresh
