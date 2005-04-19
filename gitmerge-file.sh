#!/bin/sh
#
# Copyright (c) Linus Torvalds, 2005
#
# This is the per-file merge script, called with
#
#   $1 - original file SHA1 (or empty)
#   $2 - file in branch1 SHA1 (or empty)
#   $3 - file in branch2 SHA1 (or empty)
#   $4 - pathname in repository
#
# We are designed to merge $3 _to_ $2, so we will give it
# a preference.
#
#
# Handle some trivial cases.. The _really_ trivial cases have
# been handled already by read-tree, but that one doesn't
# do any merges that migth change the tree layout

case "${1:-.}${2:-.}${3:-.}" in
#
# deleted in both, or deleted in one and unchanged in the other
#
"$1$1.")
	rm -- "$4"; git rm "$4"
	update-cache --remove -- "$4"
	exit 0
	;;
"$1.." | "$1.$1")
	update-cache --remove -- "$4"
	exit 0
	;;

#
# added in one, or added identically in both
#
"..$3")
	# FIXME: Permissions!
	cat-file blob "$3" >"$4"; git add "$4"
	update-cache --add -- "$4"
	exit 0
	;;
".$2." | ".$2$2")
	update-cache --add -- "$4"
	exit 0
	;;

#
# Modified in both, but differently ;(
#
"$1$2$3")
	echo "Auto-merging $4"
	orig=$(unpack-file $1)
	src1=$(unpack-file $2)
	src2=$(unpack-file $3)
	ret=0
	if ! merge "$src2" "$orig" "$src1"; then
		echo Conflicting merge!
		cat "$src2" >"$4"
		ret=1

	elif ! cat "$src2" >"$4" || ! update-cache --add -- "$4"; then
		echo "Choosing $src2 -> $4 failed"
		ret=1
	fi
	rm "$orig" "$src1" "$src2"
	exit $ret
	;;

*)
	echo "Not handling case $1 -> $2 -> $3"
	;;
esac
exit 1
