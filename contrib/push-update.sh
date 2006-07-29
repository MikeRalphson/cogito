#!/bin/sh
#
# Automatically update working copy of target repository when pushing
# Copyright (c) Petr Baudis, 2006
#
# Sometimes you might want to push to a repository with a working copy
# attached. That is certainly possible and if you push into a branch that
# is not checked out at the remote side (e.g. if you push into 'origin'
# in the standard setup created by `cg-clone` when you have 'master' checked
# out and 'origin' represents the remote repository), it works just fine.
#
# HOWEVER, if you push to the same branch as your current branch (usually
# 'master'), you will get into very big problems since Cogito will think your
# working copy suddenly corresponds to the pushed revision, however the
# working copy was not updated yet and still represents the original revision.
# If you run e.g. `cg-diff` then, you will get very funny results. This hook
# script can be used to update your remote working copy every time you push.
#
# Note that you should be careful while deploying this, it can get very
# confusing especially if someone else pushes to your working repository
# in the middle of your work. If you work in a team, you should either
# use a central repository set up using `cg-admin-setuprepo` or fetch from
# each other, not push into someone else's repository.
#
# Also, it is inherently racy and you can end up in an inconsistent state
# in case things go bad enough.
#
# This is designed to run as Git update hook. Add this to your
# '.git/hooks/update':
#
#	/path/to/push-update.sh "$@"
#
# and do not forget to make the hook executable.

# It is totally untested, in case you care. :P

cd ..
if [ "$(git-symbolic-ref HEAD)" == "$1" ]; then
	_cg_orig_head="$2" cg-merge "$3"
fi
