# 'git' bash completion and library routines used by porcelain completions.
#
# Copyright (c) Paolo Giarrusso, 2005
# Copyright (c) Ben Clifford, 2005
#
# The master version is available at:
#       http://www.hawaga.org.uk/gitcompletion.git

bashdefault="-o bashdefault"
default="-o default"

__git_tags()
{
    REVERTGLOB=`shopt -p nullglob`
    shopt -s nullglob
    if [ -n ".git/refs/tags/*" ] ; then
        for i in $(echo .git/refs/tags/*); do
            echo ${i#.git/refs/tags/}
        done
    fi
    $REVERTGLOB
}

__git_heads()
{
    REVERTGLOB=`shopt -p nullglob`
    shopt -s nullglob
    if [ -n ".git/refs/heads/*" ] ; then
        for i in $(echo .git/refs/heads/*); do
            echo ${i#.git/refs/heads/}
        done
    fi
    $REVERTGLOB
}
 
__git_remotes()
{
    REVERTGLOB=`shopt -p nullglob`
    shopt -s nullglob
    if [ -n ".git/remotes/*" ] ; then
        for i in $(echo .git/remotes/*); do
            echo ${i#.git/remotes/}
        done
    fi
    $REVERTGLOB
}
 
__git_refs()
{
   __git_heads
   __git_tags
    echo HEAD
}

__git_repo_urls()
{
    REVERTGLOB=`shopt -p nullglob`
    shopt -s nullglob
    if [ -n ".git/branches/*" ] ; then
        for i in $(echo .git/branches/*); do
            head -n 1 ${i}
        done
    fi
    $REVERTGLOB
}

