#!/bin/sh
#
# Commit into a GIT repository.
# Copyright (c) Petr Baudis, 2005
# Based on an example script fragment sent to LKML by Linus Torvalds.
#
# Ignores any parameters for now, excepts changelog entry on stdin.
#
# FIXME: Gets it wrong for filenames containing spaces.


die () {
	echo gitcommit.sh: $@ >&2
	exit 1
}


if [ "$1" ]; then
	# FIXME: Update the add/rm queues!
	commitfiles="$@"

	merged=
	if [ -s .git/merged ]; then
		cat >&2 <<__END__
gitcommit.sh: warning: will NOT record the performed merge(s) when
gitcommit.sh: warning: a file list was passed in the arguments
__END__
	fi

else
	# We bother with added/removed files here instead of updating
	# the cache at the time of git(add|rm).sh, since we want to
	# have the cache in a consistent state representing the tree
	# as it was the last time we committed. Otherwise, e.g. partial
	# conflicts would be a PITA since added/removed files would
	# be committed along automagically as well.

	addedfiles=
	[ -r .git/add-queue ] && addedfiles=$(cat .git/add-queue)

	remfiles=
	[ -r .git/rm-queue ] && remfiles=$(cat .git/rm-queue)

	changedfiles=$(show-diff -s | cut -d : -f 1)
	commitfiles="$addedfiles $remfiles $changedfiles"

	merged=
	[ -s .git/merged ] && \
		merged=$(cat .git/merged | sed 's/^/-p /')

fi
if [ ! "$commitfiles" ]; then
	echo 'Nothing to commit.' >&2
	exit 2
fi


for file in $commitfiles; do
	# Prepend a letter describing whether it's addition, removal or update.
	echo $file;
done
echo "Enter commit message, terminated by ctrl-D on a separate line:"
LOGMSG=`mktemp -t gitci.XXXXXX`
if [ "$merged" ]; then
	cat .git/merged | sed 's/^/Merging: /' >>$LOGMSG
	cat .git/merged | sed 's/^/Merging: /'
	echo >>$LOGMSG; echo
fi
cat >>$LOGMSG


# TODO: Do the proper separation of adds, removed, and changes.
update-cache --add --remove $commitfiles || die "update-cache failed"


oldhead=$(cat .git/HEAD)
[ "$oldhead" ] && oldhead="-p $oldhead"

treeid=$(write-tree)
[ "$treeid" ] || die "write-tree failed"
if [ "$treeid" = "$(tree-id)" ] && [ ! "$merged" ]; then
	echo "Refusing to make an empty commit - the tree was not modified" >&2
	echo "since the previous commit. If you really want to make the" >&2
	echo "commit, do: commit-tree \`tree-id\` -p \`parent-id\`" >&2
	exit 2;
fi

newhead=$(commit-tree $treeid $oldhead $merged <$LOGMSG)
rm $LOGMSG
rm -f .git/add-queue .git/rm-queue .git/merged

if [ "$newhead" ]; then
	echo $newhead >.git/HEAD
else
	die "error during commit (oldhead $oldhead, treeid $treeid)"
fi
