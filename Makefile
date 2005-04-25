# Define MOZILLA_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine coming from Mozilla. It is GPL'd and should be fast
# on non-x86 architectures (e.g. PowerPC), while the OpenSSL version (default
# choice) has very fast version optimized for i586.
#
# Define PPC_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine optimized for PowerPC.
#
# -DCOLLISION_CHECK if you believe that SHA1's
# 1461501637330902918203684832716283019655932542976 hashes do not give you
# enough guarantees about no collisions between objects ever hapenning.
#
# -DNSEC if you want git to care about sub-second file mtimes and ctimes.
# Note that you need some new glibc (at least >2.2.4) for this, and it will
# BREAK YOUR LOCAL DIFFS! show-diff and anything using it will likely randomly
# break unless your underlying filesystem supports those sub-second times
# (my ext3 doesn't).
CFLAGS=-g -O2 -Wall

# Should be changed to /usr/local
prefix=$(HOME)

bindir=$(prefix)/bin

CC=gcc
AR=ar


PROG=   update-cache show-diff init-db write-tree read-tree commit-tree \
	cat-file fsck-cache checkout-cache diff-tree rev-tree show-files \
	check-files ls-tree merge-base merge-cache unpack-file git-export \
	diff-cache convert-cache http-pull rpush rpull rev-list

SCRIPT=	commit-id tree-id parent-id cg-Xdiffdo cg-Xmergefile \
	cg-add cg-admin-lsobj cg-cancel cg-commit cg-diff \
	cg-export cg-help cg-init cg-log cg-ls cg-merge cg-mkpatch \
	cg-patch cg-pull cg-branch-add cg-branch-ls cg-rm cg-seek cg-status \
	cg-tag cg-update cg-Xlib

COMMON=	read-cache.o

GEN_SCRIPT= cg-version

VERSION= VERSION

LIB_OBJS=read-cache.o sha1_file.o usage.o object.o commit.o tree.o blob.o
LIB_FILE=libgit.a
LIB_H=cache.h object.h


LIBS = -lz

ifdef MOZILLA_SHA1
	SHA1_HEADER="mozilla-sha1/sha1.h"
	LIB_OBJS += mozilla-sha1/sha1.o
else
ifdef PPC_SHA1
	SHA1_HEADER="ppc/sha1.h"
	LIB_OBJS += ppc/sha1.o ppc/sha1ppc.o
else
	SHA1_HEADER=<openssl/sha.h>
	LIBS += -lssl
endif
endif

CFLAGS += '-DSHA1_HEADER=$(SHA1_HEADER)'


all: $(PROG) $(GEN_SCRIPT)

$(PROG):%: %.c $(LIB_FILE)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

$(LIB_FILE): $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)

%.o: $(LIB_H)
rpush: rsh.c
rpull: rsh.c
http-pull: LIBS += -lcurl


cg-version: $(VERSION)
	@echo Generating cg-version...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@PATH=.:$(PATH) echo "echo \"$(shell cat $(VERSION)) ($(shell commit-id))\"" >> $@
	@chmod +x $@

install: $(PROG) $(GEN_SCRIPT)
	install -m755 -d $(DESTDIR)$(bindir)
	install $(PROG) $(SCRIPT) $(GEN_SCRIPT) $(DESTDIR)$(bindir)

clean:
	rm -f *.o mozilla-sha1/*.o ppc/*.o $(PROG) $(GEN_SCRIPT) $(LIB_FILE)

backup: clean
	cd .. ; tar czvf dircache.tar.gz dir-cache
