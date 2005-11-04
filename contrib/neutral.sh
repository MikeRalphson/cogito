#!/usr/bin/env bash
#
# This is experiment on http://revctrl.org/NeutralInterface, implementing
# the interface.

die() {
	echo "$@" >&2
	exit 1
}

if [ ! "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	die http://revctrl.org/NeutralInterface
elif [ "$1" = "identify" ]; then
	echo type:3:git
elif [ "$1" = "changeset" ]; then
	[ "$2" ] || die "missing changeset id"
	commit="$(cg-object-id -c "$2")" || die "bad changeset id"
	echo identifier:40:"$commit"
	for parent in $(cg-object-id -p "$commit"); do
		echo parent:40:$parent
	done
	user="$(git-cat-file commit "$commit" | sed -n 's/^author \([^<]* <[^>]*>\).*/\1/p;/^$/q')"
	echo user:${#user}:"$user"
	desc="$(git-cat-file commit "$commit" | sed -n '/^$/{:a n;p;b a}')"
	echo description:${#desc}:"$desc"
fi
