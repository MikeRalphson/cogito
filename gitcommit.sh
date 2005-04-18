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


[ -s .git/blocked ] && die "committing blocked (unfinished merge?)"

if [ "$1" ]; then
	# FIXME: Update the add/rm queues!
	commitfiles="$@"

	[ -s .git/merging ] && die "cannot commit individual files when merging"

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

	merging=
	dsttree=
	if [ -s .git/merging ]; then
		merging=$(cat .git/merging | sed 's/^/-p /')
		dsttree=$(cat .git/merging-to)/
	fi

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
if [ "$merging" ]; then
	cat .git/merging | sed 's/^/Merging: /' >>$LOGMSG
	cat .git/merging | sed 's/^/Merging: /'
	echo >>$LOGMSG; echo
fi
cat >>$LOGMSG


# TODO: Do the proper separation of adds, removed, and changes.
echo $commitfiles | xargs update-cache --add --remove \
	|| die "update-cache failed"


oldhead=
if [ -s "$dsttree.git/HEAD" ]; then
	oldhead=$(cat $dsttree.git/HEAD)
	oldheadstr="-p $oldhead"
fi

treeid=$(write-tree)
[ "$treeid" ] || die "write-tree failed"
if [ ! "$merging" ] && [ "$oldhead" ] && [ "$treeid" = "$(tree-id)" ]; then
	echo "Refusing to make an empty commit - the tree was not modified" >&2
	echo "since the previous commit. If you really want to make the" >&2
	echo "commit, do: commit-tree \`tree-id\` -p \`parent-id\`" >&2
	exit 2;
fi

newhead=$(commit-tree $treeid $oldheadstr $merging <$LOGMSG)
rm $LOGMSG
rm -f .git/add-queue .git/rm-queue

if [ "$newhead" ]; then
	echo "Committed as $newhead."
	if [ "$merging" ]; then
		echo "passed merge" >.git/blocked
		mergetree=$(pwd)
		cd $dsttree
		mv "$mergetree" "$mergetree~$newhead"
	fi
	echo $newhead >.git/HEAD
	if [ "$merging" ]; then
		rm .git/blocked
		# Update the tree with the merged changes
		read-tree $(tree-id $newhead)
		git diff "$oldhead":"$newhead" | git apply
		update-cache --refresh
	fi
else
	die "error during commit (oldhead $oldhead, treeid $treeid)"
fi
