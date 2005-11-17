#!/usr/bin/env bash
#
# This is experiment on http://revctrl.org/NeutralInterface, implementing
# the interface.

die() {
	echo "$@" >&2
	exit 1
}

# Take a field name as an argument and check in the $interesting[] array
# whether we should output it.
interesting() {
	[ "${interesting[0]}" = '*' ] && return 0
	for field in "${interesting[@]}"; do
		[ "$field" = "$1" ] && return 0
	done
	return 1
}


if [ ! "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	die http://revctrl.org/NeutralInterface
fi

interesting=('*')
if [ "$1" = "-s" ]; then
	shift; interesting=(${1//,/ }); shift
fi

cmd="$1"; shift; args=("$@");
interactive=
[ "$cmd" = "-i" ] && interactive=1

while [ "$cmd" ]; do
	if [ "$cmd" = "-i" ]; then
		: # nothing

	elif [ "$cmd" = "version" ]; then
		interesting "version" && echo "version:1:0"

	elif [ "$cmd" = "identify" ]; then
		interesting "type" && echo "type:3:git"

	elif [ "$cmd" = "changeset" ]; then
		[ "${args[0]}" ] || die "missing changeset id"
		commit="$(git-rev-parse --verify "${args[0]}")" || die "bad changeset id"
		interesting "identifier" && echo "identifier:40:$commit"

		interesting "parent" &&
		for parent in $(git-rev-parse --verify "$commit"^); do
			echo "parent:40:$parent"
		done

		interesting "tag" &&
		grep -r -l "$commit" ${GIT_DIR:-.git}/refs/tags |
			while IFS=$'\n' read tag; do
				tag="${tag##*/}"
				echo "tag:${#tag}:$tag"
			done

		# FIXME: doesn't handle filenames containing newlines
		interesting "file" &&
		echo $commit $(git-rev-parse --verify "$commit"^) |
			git-diff-tree -r -m --stdin | grep ^: | cut -f 2- |
			while IFS=$'\n' read file; do
				echo "file:${#file}:$file"
			done

		if interesting "user" || interesting "date"; then
			author="$(git-cat-file commit "$commit" | sed -n 's/^author //p;/^$/q')"

			if interesting "user"; then
				user="$(echo "$author" | sed 's/\([^<]* <[^>]*>\).*/\1/')"
				echo user:${#user}:"$user"
			fi

			if interesting "date"; then
				date="$(echo "$author" | sed 's/[^<]* <[^>]*> \(.*\)/\1/')"
				echo date:${#date}:"$date"
			fi
		fi

		if interesting "description"; then
			desc="$(git-cat-file commit "$commit" | sed -n '/^$/{:a n;p;b a}')"
			echo description:${#desc}:"$desc"
		fi

	else
		die "unknown command"
	fi

	cmd=
	if [ "$interactive" ]; then
		echo # terminate output
		read cmd
		interesting=('*')
		cmdname="${cmd%%+*}"
		if [ "$cmdname" != "$cmd" ]; then
			fields="${cmd#*+}"
			interesting=(${fields//,/ })
			cmd="$cmdname"
		fi

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
