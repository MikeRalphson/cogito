#!/bin/bash
#
# This script serves both as a tutorial explaining how to use Cogito and
# as a test for Cogito.  It's uses as part of the testsuite.
#
# This script has a few direct calls to git.  They are used when Cogito
# doesn't provide needed functionality, such as verifying signed tags
# and repacking the repository.
#
# There is anything wrong with this; git and Cogito can interoperate
# just fine, especially if you don't use git for things Cogito can do.


# This function is appended as "&& should_fail" to commands which should
# fail. Readers please pretend that it is not here at all - it is useful
# for executing this script to make sure we did not break it with any
# Cogito changes.
should_fail () {
	echo "Expected failure, got success on line ${BASH_LINENO[0]}" \
	     "- aborting" >&2
	trap - exit
	exit 1
}

# Conversely, if something fails when it shouldn't, report it and exit.
set -e
trap 'echo >&2 "Unexpected error $? on line $LINENO"; exit 1' exit


# Since this script doubles as a test, prefer the local Cogito version
# so it can be tested before installation
TOP=$(pwd)
export PATH=$TOP/../..:$PATH

### Set up the playground
rm -rf Playground
mkdir Playground
cd Playground

# Suppose we have three users: Alice, Bob and Charlie
mkdir Alice Bob Charlie
ALICE=$TOP/Playground/Alice
BOB=$TOP/Playground/Bob
CHARLIE=$TOP/Playground/Charlie

# This function imitates becoming one of the users
switch_user () {
	case $1 in
		Alice) cd "$ALICE";;
		Bob) cd "$BOB";;
		Charlie) cd "$CHARLIE";;
		*) echo "I don't know you, $1"; exit 1;;
	esac
	HOME=$(pwd)
	GIT_AUTHOR_NAME="$1"
	GIT_AUTHOR_EMAIL="$1@example.com"
	GIT_COMMITTER_NAME="$1"
	GIT_COMMITTER_EMAIL="$1@example.com"
}


### Let's start.  Pretend you are Alice
switch_user Alice

# Alice has written an RPN calculator program
tar xf $TOP/0001-alice.tar
cd rpn

# Being a tidy girl, she places it under Cogito
echo "Alice's first version" | cg-init

# Let it be known as version 0.1
cg-tag -m "First ever version of RPN" rpn-0.1

# Alice decides to add the license file to the code
cp $TOP/0002-alice-license.txt osl-2.1.txt

# Cogito should know that it's a new file to be added
cg-add osl-2.1.txt

# Notices should be added to the existing files
patch -p1 -i $TOP/0003-alice-osl.patch

# Alice commits the changes and tags the result as version 0.2
cg-commit -m "Place under OSL-2.1"
cg-tag -m "Place under OSL-2.1" rpn-0.2

# Now Alice creates a public repository for the new toy
cg-admin-setuprepo $ALICE/rpn.git

# Alice will refer to it as the "public" branch
cg-branch-add public "$ALICE/rpn.git"

# Alice pushes her master branch and both tags to the public repository
cg-push public -t rpn-0.1 -t rpn-0.2


### Bob hears about this exciting new program and gets a copy from Alice
switch_user Bob
cg-clone $ALICE/rpn.git
cd rpn

# Bob thinks the declarations for the stack belong to a header file
cp $TOP/0004-bob-stack_h stack.h
patch -p1 -i $TOP/0005-bob-stack_h.patch
cg-add stack.h
cg-commit -m "Place stack declarations in header file" \
          -m "Create stack.h, move declarations of stack manipulation into it" \
          -m "Include stack.h in rpn.c and stack.h"

# Just after commit, Bob realizes he didn't fix the Makefile
patch -p1 -i $TOP/0006-bob-Makefile.patch
cg-commit -m "Update dependencies for stack.h in Makefile"


### Alice has been busy too...
switch_user Alice
cd rpn

# She adds the 'd'rop operation
patch -p1 -i $TOP/0007-alice-drop.patch
cg-commit -m "Add drop command" \
          -m "Change rpn.c to add handling for 'd'rop"

# Then she adds 'C'lear, and a first stab at documentation
patch -p1 -i $TOP/0008-alice-clear.patch
cp $TOP/0009-alice-README.txt README
cg-add README
cg-commit -m "Add clear stack command" \
          -m "Change rpn.c to add handling for 'C'lear" \
          -m "Add README file with fist stab at documentation"

# The result works fine, so she prepares to release it
cg-tag -m "First public release" rpn-0.3
cg-push public -t rpn-0.3
cg-export ../rpn-0.3.tar.bz2


### Bob tells Alice of his changes, Alice prepares to get them.
switch_user Alice
cd rpn

# Alice creates local branch "bob" to integrate Bob's changes.
cg-switch -r master bob

# Now Alice has branches "master", "public" and "bob" ("bob" is active).
cg-status -g

# Remote branch "bobswork" is a shortcut to the Bob's master branch
cg-branch-add bobswork $BOB/rpn

# Remote branches are "public" and "bobswork".
cg-branch-ls

# Alice tries to merge Bob's work to the "bob" branch
cg-update bobswork && should_fail

# There are conflicts in rpn.c. Looking at the file, Alice sees the
# difference between her version and Bob's:

#: ...
#: <<<<<<< bob
#: extern double pop(void);
#: extern void push(double);
#: extern void clear(void);
#:
#: =======
#: >>>>>>> bobswork
#: extern int getsym(void);
#: ...

# Alice keeps Bob's version, i.e. the one from the "bobswork" branch
ed -s rpn.c < $TOP/0010-alice-bob-fixup.ed

# cg-commit after resolving conflicts from failed merge will autogenerate
# the commit message.
cg-commit </dev/null

# While still on the "bob" branch, Alice fixes up Makefile and stack.h
patch -p1 -i $TOP/0011-alice-cleanup.patch
cg-commit -m "Fix Makefile and stack.h"


### Charlie heard of RPN, and wants to hack too
switch_user Charlie
cg-clone $ALICE/rpn.git rpn
cd rpn

# He hacks around, and messes up rpn.c
echo "Oops!" > rpn.c

# Fortunately, cg-restore can take care of it
cg-restore -f rpn.c

# Finally, Charlie has the changes he wants
cp $TOP/0012-charlie-lexer_h lexer.h
patch -p1 -i $TOP/0013-charlie-lexer.patch
cg-add lexer.h
cg-commit -m "Add proper header file for lexer" \
          -m "Create lexer.h, move lexer declarations into it." \
          -m "Include lexer.h in rpn.c and lexer.c" \
          -m "Update dependencies in Makefile"

# Charlie prepares the patch and sends it to Alice
cg-mkpatch -d ../patches -r rpn-0.3..master

# Well, in real life Charlie is more likely to use e-mail than "cp"
cp -r $CHARLIE/patches $ALICE/patches


### Alice is busy meanwhile...
switch_user Alice
cd rpn

# She returns to master branch, leaving "bob" for later merging
cg-switch master

# The calculator gets a new operator
patch -p1 -i $TOP/0015-alice-mod.patch
cg-commit -m "Add mod operator" \
          -m "Add handling for '%' (fmod(3)) in rpn.c"

# And then another one
patch -p1 -i $TOP/0016-alice-dup.patch
cg-commit -m "Add duplication operator" \
          -m "Add handling for 'D'up in rpn.c"

# Alice publishes her work-in-progress
cg-push public

# Alice gets Charlie's fix and creates a new branch for his changes.
# This time, she starts the branch off the rpn-0.3 tag, which was
# the base version for Charlie's changes.
cg-switch -r rpn-0.3 charlie
cg-patch -d $ALICE/patches

# Alice is going to integrate the changes in the "bob" and "charlie"
# branches into "master" for the next release
cg-switch master

# First, Alice tries to integrate Bob's changes
cg-merge bob && should_fail

# Merge fails:

#: ...
#: <<<<<<< master
#:	$(CC) $(CFLAGS) $^ -lm -o $@
#: =======
#:	$(CC) $(CFLAGS) $^ -o $@
#:	
#: rpn.o: stack.h
#: stack.o: stack.h
#: lexer.o:	
#: >>>>>>> bob

# Alice fixes Makefile and commits the changes
ed -s Makefile < $TOP/0017-alice-bob-fixup.ed
cg-commit -m "Integrate Bob's changes"

# Now it's time to integrate Charlie's changes
cg-merge charlie && should_fail

# Merge fails again!  Makefile needs tweaking

#: ...
#: <<<<<<< master
#:         $(CC) $(CFLAGS) $^ -lm -o $@
#:
#: rpn.o: stack.h
#: stack.o: stack.h
#: lexer.o:
#: =======
#:         $(CC) $(CFLAGS) $^ -o $@
#:
#: rpn.o lexer.o: lexer.h
#:
#: >>>>>>> charlie

# Alice fixes Makefile
ed -s Makefile < $TOP/0018-alice-charlie-fixup1.ed

# rpn.c needs fixing too

#: ...
#: <<<<<<< master
#: extern int getsym(void);
#:
#: =======
#: extern double pop(void);
#: extern void push(double);
#: extern void clear(void);
#:
#: >>>>>> charlie
#: ...

ed -s rpn.c < $TOP/0019-alice-charlie-fixup2.ed

# Finally, Charlie's changes can be committed
cg-commit -m "Integrate Charlie's changes"

# Alice gives proper credits to the contributors
cp $TOP/0020-alice-CONTRIBUTORS.txt CONTRIBUTORS
cg-add CONTRIBUTORS
cg-commit -m "Add CONTRIBUTORS"

# But maybe it's better to call that file CREDITS?
cg-mv CONTRIBUTORS CREDITS
cg-commit -m "Rename CONTRIBUTORS to CREDITS"

# Alice packs the repository so it uses less space
git repack
git prune-packed

# Now it's time for another public release
cg-tag -m "Public release of version 0.4" rpn-0.4
cg-push public -t rpn-0.4
cg-export ../rpn-0.4.tar.bz2

# The public repository needs packing too
GIT_DIR=$ALICE/rpn.git git repack
GIT_DIR=$ALICE/rpn.git git prune-packed


### Bob updates his version to Alice's
switch_user Bob
cd rpn

cg-fetch

# Bob has doubts about the latest version...
# (Note that originally, rpn-0.4 was signed, but that would require you
# to set up a GPG key before running the script... verify-tag on unsigned
# scripts does not make much sense.)
git verify-tag rpn-0.4 && should_fail

# Everything's OK, Bob integrate the changes
cg-merge


### Great, we are done.
trap - exit
echo "Script completed successfully!"
