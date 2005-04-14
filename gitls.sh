#!/bin/sh
#
# List contents of a particular tree in a GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# Optionally takes commit or tree id as a parameter, defaulting to HEAD.

id=$(gitXnormid.sh $1) || exit 1

ls-tree "$id"
