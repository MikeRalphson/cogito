#!/bin/bash
#
# FIXME: This script has some GITisms. They stem from missing Cogito
# features, such as exporting patches to mbox format, applying patches
# from e-mail, merging multiple tags at once, verifying signed tags and
# repacking the repository.
#
# Not that there would be anything wrong per se with this; GIT and Cogito
# can interoperate fine (except few quite special situations; see the README
# for details) and you can mix the commands; Cogito might never provide
# wrappers for some of the GIT features which are nevertheless awesomely
# useful, like `git bisect`.


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


### Set up playground
sh 0000-playground.sh
TOP=$(pwd)
ALICE=$TOP/Playground/Alice
BOB=$TOP/Playground/Bob
CHARLIE=$TOP/Playground/Charlie
cd Playground

### Alice's first version
cd $ALICE
tar xf $TOP/0001-alice.tar
cd rpn

# Being a tidy girl, she places it under Cogito
echo "Alice's first version" | cg-init
cg-tag -d "First ever version of RPN" rpn-0.1
 

# Alice decides on OSL-2.1
cd $ALICE/rpn
cp $TOP/0002-alice-license.txt osl-2.1.txt

# The new file has to be added
cg-add osl-2.1.txt

# Fix up the files
patch -p1 -i $TOP/0003-alice-osl.patch

# Now save all, and tag it for later reference
cg-commit -m "Place under OSL-2.1"
cg-tag -d "Place under OSL-2.1" rpn-0.2

# Alice creates a public repository for the new toy
cg-admin-setuprepo $ALICE/rpn.git
cg-branch-add public "$ALICE/rpn.git" # Shortcut for the public repository
# Alice pushes her master _and_ the two tags to the public repository
cg-push public -t rpn-0.1 -t rpn-0.2

### Bob hears about this exciting new program, gets a copy from Alice
cd $BOB

cg-clone $ALICE/rpn.git

cd rpn

# Bob thinks the declarations for the stack should go in a header file
cp $TOP/0004-bob-stack_h stack.h
patch -p1 -i $TOP/0005-bob-stack_h.patch

cg-add stack.h
cg-commit -m "Place stack declarations in header file" \
          -m "Create stack.h, move declarations of stack manipulation into it" \
          -m "Include stack.h in rpn.c and stack.h" 

# Later, he remembers he didn't fix the Makefile
patch -p1 -i $TOP/0006-bob-Makefile.patch

cg-commit -m "Update dependencies for stack.h in Makefile"


### Alice has been busy too...
cd $ALICE/rpn

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
cg-tag -d "First public release" rpn-0.3
cg-push public -t rpn-0.3
cg-export ../rpn-0.3.tar.bz2


### Bob tells Alice of his changes, Alice prepares to get them.
cd $ALICE/rpn

cg-switch -r master bob
cg-status -g

# Alice needs to register his remote branch
cg-branch-add bobswork $BOB/rpn
# Now try to merge Bob's work to the bob branch
cg-update bobswork && should_fail

# There are conflicts in rpn.c. Looking at the file, Alice sees the
# difference between her version and Bob's:

#: ...
#: <<<<<<< rpn.c
#: extern double pop(void);
#: extern void push(double);
#: extern void clear(void);
#: 
#: =======
#: >>>>>>> .merge_file_5wCNZT
#: extern int getsym(void);
#: ...
 
# Alice keeps Bob's version
ed rpn.c < $TOP/0010-alice-bob-fixup.ed

# cg-commit after resolving conflicts from failed merge will autogenerate
# the commit message.
cg-commit </dev/null

# She fixes up Makefile and stack.h a bit
patch -p1 -i $TOP/0011-alice-cleanup.patch
cg-commit -m "Fix Makefile and stack.h"


## Charlie heard of RPN, and wants to hack too.
cd $CHARLIE

cg-clone $ALICE/rpn.git rpn
cd rpn

# He hacks around, and messes up rpn.c. To restore the saved version:
rm rpn.c
cg-restore rpn.c

# Finally, he has the changes he wants
cp $TOP/0012-charlie-lexer_h lexer.h
patch -p1 -i $TOP/0013-charlie-lexer.patch

cg-add lexer.h
cg-commit -m "Add proper header file for lexer" \
          -m "Create lexer.h, move lexer declarations into it." \
          -m "Include lexer.h in rpn.c and lexer.c" \
          -m "Update dependencies in Makefile"

# Charlie emails the patch to Alice:
# cg-mkpatch -d .. -r rpn-0.3..master
git format-patch -o .. --mbox --signoff -r rpn-0.3
# Only git can create mbox formatted output
# Compare the result to 0014-charlie-email


### Alice is busy meanwhile...
cd $ALICE/rpn

cg-switch master

patch -p1 -i $TOP/0015-alice-mod.patch

cg-commit -m "Add mod operator" \
          -m "Add handling for '%' (fmod(3)) in rpn.c"

patch -p1 -i $TOP/0016-alice-dup.patch

cg-commit -m "Add duplication operator" \
          -m "Add handling for 'D'up in rpn.c"
          
# Alice publishes her work-in-progress
cg-push public


### Alice gets Charlie's fix, creates a new branch for his changes
cd $ALICE/rpn

cg-switch -r rpn-0.3 charlie
cg-status -g

# Check what's inside the patch.  There is no Cogito equivalent yet.
git apply --stat $TOP/0014-charlie-email
git apply --summary $TOP/0014-charlie-email
git apply --check $TOP/0014-charlie-email

# Everything looks OK
git applymbox $TOP/0014-charlie-email
# This doesn't work well yet
# cg-patch < $TOP/0014-charlie-email

### Alice integrates the changes in the branches for the next release
cd $ALICE/rpn

cg-switch master
# Alice tries "git merge" instead of "cg-merge" since she wanted to
# merge both branches at once, which "cg-merge" cannot do.
git merge "Integrate changes from Bob and Charlie" master bob charlie \
	&& should_fail

# Automatic 3-way merge fails! Have to do it step by step

cg-merge bob && should_fail

# Merge fails:

#: ...
#: <<<<<<< Makefile
#:	$(CC) $(CFLAGS) $^ -lm -o $@
#: =======
#:	$(CC) $(CFLAGS) $^ -o $@
#:	
#: rpn.o: stack.h
#: stack.o: stack.h
#: lexer.o:	
#: >>>>>>> .merge_file_iNhznP

ed Makefile < $TOP/0017-alice-bob-fixup.ed

cg-commit -m "Integrate Bob's changes"

cg-merge charlie && should_fail

# Merge conflicts!

#: ...
#: <<<<<<< Makefile
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
#: >>>>>>> .merge_file_huuX9C

ed Makefile < $TOP/0018-alice-charlie-fixup1.ed

#: ...
#: <<<<<<< rpn.c
#: extern int getsym(void);
#: 
#: =======
#: extern double pop(void);
#: extern void push(double);
#: extern void clear(void);
#:
#: >>>>>> .merge_file_qtv6VA
#: ...

ed rpn.c    < $TOP/0019-alice-charlie-fixup2.ed

cg-commit -m "Integrate Charlie's changes"

# Give proper credits
cp $TOP/0020-alice-CONTRIBUTORS.txt CONTRIBUTORS

cg-add CONTRIBUTORS
cg-commit -m "Add CONTRIBUTORS"

# Wrong file name...
git rename CONTRIBUTORS CREDITS
cg-commit -m "Rename CONTRIBUTORS to CREDITS"


# Pack it so it uses less space
git repack
git prune-packed

# Second public release
cg-tag -d "New public release" rpn-0.4
cg-push public -t rpn-0.4
cg-export ../rpn-0.4.tar.bz2

# Also pack public repository
GIT_DIR=$ALICE/rpn.git git repack
GIT_DIR=$ALICE/rpn.git git prune-packed

### Bob updates his version to Alice's
cd $BOB/rpn

cg-fetch

# Bob has doubts about the latest version...
# (Note that originally, rpn-0.4 was signed, but that would require you
# to set up a GPG key before running the script... verify-tag on unsigned
# scripts does not make much sense.)
git verify-tag rpn-0.4 && should_fail

# Everything's OK, integrate the changes
echo "Merge with 0.4" | cg-merge && should_fail

# Merge conflicts in Makefile, rpn.c
# Mishandled stack.h
ed Makefile < $TOP/0021-bob-alice-fixup1.ed
ed rpn.c    < $TOP/0022-bob-alice-fixup2.ed
ed stack.h  < $TOP/0023-bob-alice-fixup3.ed
cg-add stack.h

# Now commit the whole
cg-commit -m "Merge with 0.4"

# Great, we are done.
trap - exit
echo "Script completed successfully!"
