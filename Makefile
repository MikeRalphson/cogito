# -DCOLLISION_CHECK if you believe that SHA1's
# 1461501637330902918203684832716283019655932542976 hashes do not give you
# enough guarantees about no collisions between objects ever hapenning.
#
# -DNSEC if you want git to care about sub-second file mtimes and ctimes.
# Note that you need some new glibc (at least >2.2.4) for this, and it will
# BREAK YOUR LOCAL DIFFS! show-diff and anything using it will likely randomly
# break unless your underlying filesystem supports those sub-second times
# (my ext3 doesn't).
CFLAGS=-g -O3 -Wall

CC=gcc
AR=ar


PROG=   update-cache show-diff init-db write-tree read-tree commit-tree \
	cat-file fsck-cache checkout-cache diff-tree rev-tree show-files \
	check-files ls-tree merge-base merge-cache unpack-file

SCRIPT=	parent-id tree-id git gitXnormid.sh gitadd.sh gitaddremote.sh \
	gitcommit.sh gitdiff-do gitdiff.sh gitlog.sh gitls.sh gitlsobj.sh \
	gitmerge.sh gitpull.sh gitrm.sh gittag.sh gittrack.sh gitexport.sh \
	gitapply.sh gitcancel.sh gitXlntree.sh commit-id gitlsremote.sh \
	gitfork.sh gitinit.sh gitseek.sh gitstatus.sh gitpatch.sh

COMMON=	read-cache.o

GEN_SCRIPT= gitversion.sh

VERSION= VERSION

LIB_OBJS=read-cache.o sha1_file.o usage.o object.o commit.o tree.o blob.o
LIB_FILE=libgit.a
LIB_H=cache.h object.h

LIBS= $(LIB_FILE) -lssl -lz


all: $(PROG) $(GEN_SCRIPT)

$(PROG):%: %.o $(LIB_FILE)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

$(LIB_FILE): $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)

%.o: $(LIB_H)

gitversion.sh: $(VERSION)
	@echo Generating gitversion.sh...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@echo "echo \"$(shell cat $(VERSION)) ($(shell commit-id))\"" >> $@
	@chmod +x $@

install: $(PROG) $(GEN_SCRIPT)
	install $(PROG) $(SCRIPT) $(GEN_SCRIPT) $(HOME)/bin/

clean:
	rm -f *.o $(PROG) $(GEN_SCRIPT) $(LIB_FILE)

backup: clean
	cd .. ; tar czvf dircache.tar.gz dir-cache
