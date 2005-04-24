#!/usr/bin/env bash
#
# The help for the git-pasky toolkit.
# Copyright (c) Petr Baudis, 2005

cat <<__END__
The GIT scripted toolkit  $(gitversion.sh)

Usage: git COMMAND [ARG]...

Available commands:
	add		FILE...
	addremote	RNAME RSYNC_URL
	apply				< patch on stdin
	cancel
	ci, commit	[FILE]...	< log message on stdin
	diff		[-p] [-r FROM_ID[:TO_ID]] [FILE]...
	export		DESTDIR [TREE_ID]
	fork		BNAME BRANCH_DIR [COMMIT_ID]
	help
	init		RSYNC_URL
	log		[-c] [COMMIT_ID | COMMIT_ID:COMMIT_ID]
	ls		[TREE_ID]
	lsobj		[OBJTYPE]
	lsremote
	merge		[-c] [-b BASE_ID] FROM_ID
	patch		[COMMIT_ID | COMMIT_ID:COMMIT_ID]
	pull		[RNAME]
	rm		FILE...
	seek		[COMMIT_ID]
	status
	tag		TNAME [COMMIT_ID]
	track		[RNAME]
	version

Note that these expressions can be used interchangably as "ID"s:
	empty string (current HEAD)
	remote name (as registered with git addremote)
	tag name (as registered with git tag)
	shortcut hash (shorted unambiguous hash lead)
	commit object hash (as returned by commit-id)
	tree object hash (accepted only by some commands)
__END__
