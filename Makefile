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


PROG=   update-cache show-diff init-db write-tree read-tree commit-tree \
	cat-file fsck-cache checkout-cache diff-tree rev-tree show-files \
	check-files ls-tree merge-base merge-cache

SCRIPT=	parent-id tree-id git gitXnormid.sh gitadd.sh gitaddremote.sh \
	gitcommit.sh gitdiff-do gitdiff.sh gitlog.sh gitls.sh gitlsobj.sh \
	gitmerge.sh gitpull.sh gitrm.sh gittag.sh gittrack.sh gitexport.sh \
	gitapply.sh gitcancel.sh gitXlntree.sh commit-id gitlsremote.sh \
	gitfork.sh gitinit.sh gitseek.sh gitstatus.sh

COMMON=	read-cache.o

GEN_SCRIPT= gitversion.sh

VERSION= VERSION

all: $(PROG) $(GEN_SCRIPT)

install: $(PROG) $(GEN_SCRIPT)
	install $(PROG) $(SCRIPT) $(GEN_SCRIPT) $(HOME)/bin/

LIBS= -lssl -lz


$(PROG):%: %.o $(COMMON)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

read-cache.o: cache.h
show-diff.o: cache.h

gitversion.sh: $(VERSION)
	@echo Generating gitversion.sh...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@echo "echo \"$(shell cat $(VERSION)) ($(shell commit-id))\"" >> $@
	@chmod +x $@

clean:
	rm -f *.o $(PROG) $(GEN_SCRIPT)

backup: clean
	cd .. ; tar czvf dircache.tar.gz dir-cache
