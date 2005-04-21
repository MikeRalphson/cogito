#!/usr/bin/env bash
#
# Make a log of changes in a GIT branch.
#
# This script was originally written by (c) Ross Vandegrift.
# Adapted to his scripts set by (c) Petr Baudis, 2005.
# Major optimizations by (c) Phillip Lougher.
# Rendered trivial by Linus Torvalds.
#
# Takes an id resolving to a commit to start from (HEAD by default).

if [ "$1" = "-c" ]; then
	shift
	colheader=$(setterm -foreground green)
	colauthor=$(setterm -foreground cyan)
	colcommitter=$(setterm -foreground magenta)
	colsignoff=$(setterm -foreground yellow)
	coldefault=$(setterm -foreground default)
else
	colheader=
	colauthor=
	colcommitter=
	colsignoff=
	coldefault=
fi

base=$(gitXnormid.sh -c $1) || exit 1

rev-tree $base | sort -rn | while read time commit parents; do
	echo $colheader commit ${commit%:*} $coldefault;
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
					echo -n $color $key $rest | sed "s/>.*/> ${pdate/+0000/$tz}/"
					echo $coldefault
				else
					echo $color $key $rest $coldefault
				fi
				;;
			"")
				echo; sed -re '
					/ *Signed-off-by.*/Is//'$colsignoff'&'$coldefault'/
					s/^/    /
				'
				;;
			*)
				echo $colheader $key $rest $coldefault
				;;
			esac

		done
	echo
done | ${PAGER:-less} ${PAGER_FLAGS:--R}
