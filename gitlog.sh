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

base=$(gitXnormid.sh -c $1) || exit 1

rev-tree $base | sort -rn | while read time commit parents; do
	echo commit ${commit%:*};
	cat-file commit $commit | \
		while read key rest; do
			case "$key" in
			"author"|"committer")
				date=(${rest#*> })
				sec=${date[0]}; tz=${date[1]}
				dtz=${tz/+/+ }; dtz=${dtz/-/- }
				pdate="$(date -Rud "1970-01-01 UTC + $sec sec $dtz" 2>/dev/null)"
				if [ "$pdate" ]; then
					echo $key $rest | sed "s/>.*/> ${pdate/+0000/$tz}/"
				else
					echo $key $rest
				fi
				;;
			"")
				echo; cat
				;;
			*)
				echo $key $rest
				;;
			esac

		done
	echo -e "\n--------------------------"
done
