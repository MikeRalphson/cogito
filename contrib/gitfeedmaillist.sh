#!/bin/bash
#
# Generate a mail feed for a commits list.
#
# Based on 'gitlog.sh' originally written by (c) Ross Vandegrift.
# Adapted to his scripts set by (c) Petr Baudis, 2005.
# Major optimizations by (c) Phillip Lougher.
#
# Takes an id resolving to a commit to start from (HEAD by default).

# regex for parent declarations
PARENTS="^parent [A-Za-z0-9]{40}$"

TMPCL=$(mktemp -t gitmail.XXXXXX)
TMPCM=$(mktemp -t gitmail.XXXXXX)
TMPML=$(mktemp -t gitmail.XXXXXX)
TMPMD=$(mktemp -td gitmail.XXXXXX)

FROM=`whoami`@`hostname`
#SENDMAIL=/usr/lib/sendmail
#MLIST=`whoami`@`hostname`
# Unless configured otherwise, just cat it instead of mailing.
SENDMAIL=tee --append
MLIST=git-commits-mail.out

# takes an object and generates the object's parent(s)
createmails () {
	local parents new_parent
	declare -a new_parent

	new_parent=("$@")
	parents=$#

	while [ $parents -gt 0 ]; do
		parent=${new_parent[$(($parents-1))]}

		echo $parent >> $TMPCL

		parents=0
		ignoredparents=0
		lastparent=
		SUBJECT=

		cat-file commit $parent > $TMPCM

		while read key rest; do
		    case "$key" in
			"")
			    read SUBJECT
			    echo ""
			    echo "$SUBJECT"
			    cat
			    break;
			    ;;

			"parent")
			    echo "parent $rest"
			    if grep -q $rest $TMPCL; then
				ignoredparents=$(($ignoredparents+1))
				lastparent=$rest
			    else
				new_parent[$parents]=$rest
				parents=$(($parents+1))
			    fi
			    ;;

			"author"|"committer")
			    date=(${rest#*> })
			    sec=${date[0]}; tz=${date[1]}
			    dtz=${tz/+/+ }; dtz=${dtz/-/- }
			    pdate="$(date -Rud "1970-01-01 UTC + $sec sec $dtz" 2>/dev/null)"
			    if [ "$pdate" ]; then
				echo $key $rest | sed "s/>.*/> ${pdate/+0000/$tz}/"
			    else
				echo "$key $rest"
			    fi
			    ;;

			*)
			    echo "$key $rest"
			    ;;
		    esac
		done > $TMPML < $TMPCM

		if [ $(($parents+$ignoredparents)) -eq 1 ]; then
		    [ -z "$lastparent" ] && lastparent=${new_parent[0]}
		    # Only one parent; not a merge. Mail this cset
		    ( cat <<EOF 
From: $FROM
To: $MLIST
Subject: $SUBJECT
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
X-Git-Commit: $parent
X-Git-Parent: $lastparent

EOF
		    cat $TMPML
		    echo
		    git diff -r $lastparent -r $parent > $TMPCM
		    diffstat -p1 $TMPCM 2>/dev/null
		    echo 
		    cat $TMPCM
			) > $TMPMD/$parent
		    echo Mail: $SUBJECT
		fi

		i=0
		while [ $i -lt $(($parents-1)) ]; do
			createmails ${new_parent[$i]}
			i=$(($i+1))
		done
	done
}

base=$(gitXnormid.sh -c $1)

if [ -z $2 ]; then
    lastmail=`cat .git/tags/MailDone`
else
    lastmail=$(gitXnormid.sh -c $2)
fi

#if [ -z $3 ]; then
#    tagname=`ls -rt .git/tags | grep -v MailDone | tail -1`
#    release=`cat .git/tags/$tagname`
#else
#    release=$(gitXnormid.sh -c $3)
#fi    

base=$(gitXnormid.sh -c $1) || exit 1


if [ "$base" != "$lastmail" ]; then
    # List the commits at which we should stop following the tree, because
    # we've come back to commits which were already in $lastmail.
    rev-tree --edges $base $lastmail | cut -f2- -d\  |  sed 's/[a-z0-9]*:1//g' >> $TMPCL

    createmails $base
    # No 'git tag -F' -- cheat.
    echo $base > .git/tags/MailDone
    tac $TMPCL | while read commit; do
	if [ -r "$TMPMD/$commit" ]; then
	    $SENDMAIL $MLIST < $TMPMD/$commit
	fi
    done
fi
rm $TMPCL $TMPCM $TMPML
rm -rf $TMPMD
