# Define MOZILLA_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine coming from Mozilla. It is GPL'd and should be fast
# on non-x86 architectures (e.g. PowerPC), while the OpenSSL version (default
# choice) has very fast version optimized for i586.
#
# Define PPC_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine optimized for PowerPC.


# Define COLLISION_CHECK below if you believe that SHA1's
# 1461501637330902918203684832716283019655932542976 hashes do not give you
# sufficient guarantee that no collisions between objects will ever happen.

# DEFINES += -DCOLLISION_CHECK

# Define NSEC below if you want git to care about sub-second file mtimes and
# ctimes. Note that you need recent glibc (at least 2.2.4) for this, and it
# will BREAK YOUR LOCAL DIFFS! show-diff and anything using it will likely
# randomly break unless your underlying filesystem supports those sub-second
# times (my ext3 doesn't).

# DEFINES += -DNSEC

CFLAGS?=-g -O2
CFLAGS+=-Wall $(DEFINES)

# Should be changed to /usr/local
prefix?=$(HOME)

bindir?=$(prefix)/bin

CC?=gcc
AR?=ar
INSTALL?=install

SCRIPTS=git-apply-patch-script git-merge-one-file-script git-prune-script \
	git-pull-script git-tag-script git-resolve-script

PROG=   git-update-cache git-diff-files git-init-db git-write-tree \
	git-read-tree git-commit-tree git-cat-file git-fsck-cache \
	git-checkout-cache git-diff-tree git-rev-tree git-ls-files \
	git-check-files git-ls-tree git-merge-base git-merge-cache \
	git-unpack-file git-export git-diff-cache git-convert-cache \
	git-http-pull git-rpush git-rpull git-rev-list git-mktag \
	git-diff-tree-helper git-tar-tree git-local-pull git-write-blob

SCRIPT=	commit-id tree-id parent-id cg-Xdiffdo cg-Xmergefile \
	cg-add cg-admin-lsobj cg-cancel cg-clone cg-commit cg-diff \
	cg-export cg-help cg-init cg-log cg-ls cg-merge cg-mkpatch \
	cg-patch cg-pull cg-branch-add cg-branch-ls cg-rm cg-seek cg-status \
	cg-tag cg-tag-ls cg-update cg-Xlib cg-restore

COMMON=	read-cache.o

GEN_SCRIPT= cg-version

VERSION= VERSION

LIB_OBJS=read-cache.o sha1_file.o usage.o object.o commit.o tree.o blob.o \
	 tag.o date.o
LIB_FILE=libgit.a
LIB_H=cache.h object.h blob.h tree.h commit.h tag.h

LIB_H += strbuf.h
LIB_OBJS += strbuf.o

LIB_H += diff.h
LIB_OBJS += diff.o

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


git-%: %.c $(LIB_FILE)
	$(CC) $(CFLAGS) -o $@ $(filter %.c,$^) $(LIB_FILE) $(LIBS)

git-http-pull: LIBS += -lcurl
git-http-pull: pull.c
git-local-pull: pull.c
git-rpull: pull.c rsh.c
git-rpush: rsh.c

test-date: test-date.c date.o
	$(CC) $(CFLAGS) -o $@ test-date.c date.o


$(LIB_OBJS): $(LIB_H)

$(LIB_FILE): $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)


ifneq (,$(wildcard .git))
cg-version: $(VERSION) .git/HEAD
	@echo Generating cg-version...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@echo "echo \"$(shell cat $(VERSION)) ($(shell cat .git/HEAD))\"" >> $@
	@chmod +x $@
else
cg-version: $(VERSION)
	@echo Generating cg-version...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@echo "echo \"$(shell cat $(VERSION))\"" >> $@
	@chmod +x $@
endif

git.spec: git.spec.in $(VERSION)
	sed -e 's/@@VERSION@@/$(shell cat $(VERSION) | cut -d"-" -f2)/g' < $< > $@


install: $(PROG) $(SCRIPTS) $(SCRIPT) $(GEN_SCRIPT)
	$(INSTALL) -m755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(PROG) $(SCRIPTS) $(SCRIPT) $(GEN_SCRIPT) $(DESTDIR)$(bindir)

uninstall:
	cd $(DESTDIR)$(bindir) && rm $(PROG) $(SCRIPTS) $(SCRIPT) $(GEN_SCRIPT)


clean:
	rm -f *.o mozilla-sha1/*.o ppc/*.o $(PROG) $(GEN_SCRIPT) $(LIB_FILE)

backup: clean
	cd .. ; tar czvf dircache.tar.gz dir-cache
