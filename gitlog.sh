#!/usr/bin/env bash
#
# Make a log of changes in a GIT branch.
#
# This script was originally written by (c) Ross Vandegrift.
# Adapted to his scripts set by (c) Petr Baudis, 2005.
# Major optimizations by (c) Phillip Lougher.
# Rendered trivial by Linus Torvalds.
#
# Takes a -c option to add color to the output.
# Currently, the colors are:
#
#	header		Green	
#	author 		Cyan
#	committer	Magenta
#	signoff		Yellow
#
# Takes an id resolving to a commit to start from (HEAD by default),
# or id1:id2 representing an (id1;id2] range of commits to show.

if [ "$1" = "-c" ]; then
	shift
	# See terminfo(5), "Color Handling"
	colheader="$(tput setaf 2)"    # Green
	colauthor="$(tput setaf 6)"    # Cyan
	colcommitter="$(tput setaf 5)" # Magenta
	colsignoff="$(tput setaf 3)"   # Yellow
	coldefault="$(tput op)"        # Restore default
else
	colheader=
	colauthor=
	colcommitter=
	colsignoff=
	coldefault=
fi

if echo "$1" | grep -q ':'; then
	id1=$(gitXnormid.sh -c $(echo "$1" | cut -d : -f 1)) || exit 1
	id2=$(gitXnormid.sh -c $(echo "$1" | cut -d : -f 2)) || exit 1
	rev_tree="$id2 ^$id1"
else
	rev_tree="$(gitXnormid.sh -c $1)" || exit 1
fi

rev-tree $rev_tree | sort -rn | while read time commit parents; do
	echo $colheader""commit ${commit%:*} $coldefault;
	cat-file commit $commit | \
		while read key rest; do
			case "$key" in
			"author"|"committer")
				if [ "$key" = "author" ]; then
					color="$colauthor"
				else
					color="$colcommitter"
				fi

				date=(${rest#*> })
				sec=${date[0]}; tz=${date[1]}
				dtz=${tz/+/+ }; dtz=${dtz/-/- }
				pdate="$(date -Rud "1970-01-01 UTC + $sec sec $dtz" 2>/dev/null)"
				if [ "$pdate" ]; then
					echo -n $color$key $rest | sed "s/>.*/> ${pdate/+0000/$tz}/"
					echo $coldefault
				else
					echo $color$key $rest $coldefault
				fi
				;;
			"")
				echo; sed -re '
					/ *Signed-off-by.*/Is//'$colsignoff'&'$coldefault'/
					s/^/    /
				'
				;;
			*)
				echo $colheader$key $rest $coldefault
				;;
			esac

		done
	echo
done | ${PAGER:-less} ${PAGER_FLAGS:--R}
