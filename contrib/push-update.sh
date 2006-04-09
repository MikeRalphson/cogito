#!/usr/bin/env bash
#
# Automatically update working copy of target repository when pushing
# Copyright (c) Petr Baudis, 2006
#
# Sometimes you might want to push to a repository with a working copy
# attached. While this is not a very recommended practice, it is certainly
# possible. However, if you push to the same branch as your current branch
# (usually 'master'), you will get into very big problems since Cogito will
# think your working copy corresponds to a different revision than it really
# corresponds. Use this update hook to update your remote working copy every
# time you push to its current branch.
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
