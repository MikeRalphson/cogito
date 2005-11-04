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
fi

cmd="$1"; shift; args=("$@");
interactive=
[ "$cmd" = "-i" ] && interactive=1

while [ "$cmd" ]; do
	if [ "$cmd" = "-i" ]; then
		: # nothing

	elif [ "$cmd" = "identify" ]; then
		echo type:3:git

	elif [ "$cmd" = "changeset" ]; then
		[ "${args[0]}" ] || die "missing changeset id"
		commit="$(cg-object-id -c "${args[0]}")" || die "bad changeset id"
		echo identifier:40:"$commit"

		for parent in $(cg-object-id -p "$commit"); do
			echo parent:40:$parent
		done

		grep -r -l "$commit" ${GIT_DIR:-.git}/refs/tags |
		while IFS=$'\n' read tag; do
			tag="${tag##*/}"
			echo tag:${#tag}:"$tag"
		done

		# FIXME: doesn't handle filenames containing newlines
		echo $commit $(cg-object-id -p "$commit") | git-diff-tree -r -m --stdin | grep ^: | cut -f 2- |
		while IFS=$'\n' read file; do
			echo file:${#file}:"$file"
		done

		author="$(git-cat-file commit "$commit" | sed -n 's/^author //p;/^$/q')"

		user="$(echo "$author" | sed 's/\([^<]* <[^>]*>\).*/\1/')"
		echo user:${#user}:"$user"

		date="$(echo "$author" | sed 's/[^<]* <[^>]*> \(.*\)/\1/')"
		echo date:${#date}:"$date"

		desc="$(git-cat-file commit "$commit" | sed -n '/^$/{:a n;p;b a}')"
		echo description:${#desc}:"$desc"

	else
		die "unknown command"
	fi

	cmd=
	if [ "$interactive" ]; then
		echo # terminate output
		read cmd
		args=()
		while true; do
			# do with bash, I guess.
			IFS=$'\n' read arg
			[ "$arg" ] || break
			arglen="${arg%%:*}"
			argval="${arg#*:}"
			while [ "${#argval}" -lt "$arglen" ]; do
				IFS=$'\n' read argvalmore
				argval="$argval
$argvalmore"
			done
			[ "${#argval}" -gt "$arglen" ] &&
				die "announced value length ($arglen) doesn't match what I really snapped (${#argval})"
			args[${#args[@]}]=${arg#*:}
		done
	fi
done
