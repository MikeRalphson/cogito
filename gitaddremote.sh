#!/bin/sh
#
# Add new "remote" to the GIT repository.
# Copyright (c) Petr Baudis, 2005
#
# After you add a remote, you can "./gitpull.sh" it whenever you want
# and it will keep your dircache in sync with it. Its latest commit
# is accessible as .git/heads/remotename (or - more conveniently -
# as $(commit-id remotename)). For example, to make a diff between
# Linus (after you added him) and your current tree, do
#
#	gitpull.sh linus
#	gitdiff.sh $(commit-id linus)
#
# (TODO: gitdiff.sh et al should accept remote names as ids.)
#
#
# Only rsync scheme URLs are supported for now. An URL can have a fragment
# part, which identifies a branch inside of the repository. So if you have
# a repository rsync://kernel.org/pub/scm/linux/kernel/mj/linux.git and
# you are interested in its 'testing' branch, you can e.g.
#
#	git addremote mj-testing \
#		rsync://kernel.org/pub/scm/linux/kernel/mj/linux.git#testing
#
# and refer to it as 'mj-testing' anytime later.
#
#
# Takes the remote's name and rsync URL.

name=$1
uri=$2

die () {
	echo gitaddremote.sh: $@ >&2
	exit 1
}

([ "$name" ] && [ "$uri" ]) || die "usage: git addremote NAME URI"
(echo $name | egrep -qv '[^a-zA-Z0-9_.@!:-]') || \
	die "name contains invalid characters"
if [ "$name" = "this" ]; then
	die "given branch name is reserved"
fi
if grep -q $(echo -e "^$name\t" | sed 's/\./\\./g') .git/remotes \
   || [ -s ".git/heads/$name" ]; then
	die "branch already exists"
fi

echo -e "$name\t$uri" >>.git/remotes
