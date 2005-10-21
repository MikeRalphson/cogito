#!/bin/sh
#
# FIXME: This script has many GITisms. Some of them are unnecessary, while
# some stem from missing Cogito features (especially no support for pushing
# tags, and consequently no support for remotes/).


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

# Being a tidy girl, she places it under git
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
cg-tag -d "First public release" -s -k Examples rpn-0.3 
cg-push public -t rpn-0.3
cg-export ../rpn-0.3.tar.bz2


### Bob tells Alice of his changes, Alice prepares to get them.
cd $ALICE/rpn

git checkout -b bob
git branch

git fetch $BOB/rpn
git merge "Changes from Bob" HEAD FETCH_HEAD

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

cg-commit -m "Merge in Bob's updates"

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
git format-patch -o .. --mbox --signoff -r rpn-0.3
      # Result is in $TOP/0014-charlie-email


### Alice is busy meanwhile...
cd $ALICE/rpn

git checkout master

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

git checkout master
git checkout -b charlie rpn-0.3
git branch

git apply --stat $TOP/0014-charlie-email
git apply --summary $TOP/0014-charlie-email
git apply --check $TOP/0014-charlie-email

# Everything looks OK
git applymbox $TOP/0014-charlie-email

### Alice integrates the changes in the branches for the next release
cd $ALICE/rpn

git checkout master
git merge "Integrate changes from Bob and Charlie" master bob charlie

# Automatic 3-way merge fails! Have to do it step by step

git merge "Integrate Bob's changes" master bob

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

git commit -a -m "Integrate Bob's changes"

git merge "Integrate Charlie's changes" master charlie

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

git commit -a -m "Integrate Charlie's changes"

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
cg-tag -d "New public release" -s -k Examples rpn-0.4
cg-push public -t rpn-0.4
cg-export ../rpn-0.4.tar.bz2

# Also pack public repository
GIT_DIR=$ALICE/rpn.git git repack
GIT_DIR=$ALICE/rpn.git git prune-packed

### Bob updates his version to Alice's
cd $BOB/rpn

cg-fetch

# Bob has doubts about the latest version...
git verify-tag rpn-0.4

# Everything's OK, integrate the changes
git merge "Merge with 0.4" master origin

# Merge conflicts in Makefile, rpn.c
# Mishandled stack.h
ed Makefile < $TOP/0021-bob-alice-fixup1.ed
ed rpn.c    < $TOP/0022-bob-alice-fixup2.ed
ed stack.h  < $TOP/0023-bob-alice-fixup3.ed

git add stack.h

git update-index

# Now commit the whole
git commit -m "Merge with 0.4"
