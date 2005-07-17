# Define MOZILLA_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine coming from Mozilla. It is GPL'd and should be fast
# on non-x86 architectures (e.g. PowerPC), while the OpenSSL version (default
# choice) has very fast version optimized for i586.
#
# Define NO_OPENSSL environment variable if you do not have OpenSSL. You will
# miss out git-rev-list --merge-order. This also implies MOZILLA_SHA1.
#
# Define PPC_SHA1 environment variable when running make to make use of
# a bundled SHA1 routine optimized for PowerPC.


# Define COLLISION_CHECK below if you believe that SHA1's
# 1461501637330902918203684832716283019655932542976 hashes do not give you
# sufficient guarantee that no collisions between objects will ever happen.

# DEFINES += -DCOLLISION_CHECK

# Define USE_NSEC below if you want git to care about sub-second file mtimes
# and ctimes. Note that you need recent glibc (at least 2.2.4) for this, and
# it will BREAK YOUR LOCAL DIFFS! show-diff and anything using it will likely
# randomly break unless your underlying filesystem supports those sub-second
# times (my ext3 doesn't).

# DEFINES += -DUSE_NSEC

# Define USE_STDEV below if you want git to care about the underlying device
# change being considered an inode change from the update-cache perspective.

# DEFINES += -DUSE_STDEV

CFLAGS?=-g -O2
CFLAGS+=-Wall $(DEFINES)

# Should be changed to /usr/local
prefix?=$(HOME)

bindir?=$(prefix)/bin
libdir?=$(prefix)/lib/cogito

CC?=gcc
AR?=ar
INSTALL?=install

#
# sparse is architecture-neutral, which means that we need to tell it
# explicitly what architecture to check for. Fix this up for yours..
#
SPARSE_FLAGS=-D__BIG_ENDIAN__ -D__powerpc__

SCRIPTS=git git-apply-patch-script git-merge-one-file-script git-prune-script \
	git-pull-script git-tag-script git-resolve-script git-whatchanged \
	git-fetch-script git-status-script git-commit-script \
	git-log-script git-shortlog git-cvsimport-script git-diff-script \
	git-reset-script git-add-script git-checkout-script git-clone-script \
	gitk git-cherry git-rebase-script git-relink-script git-repack-script

PROG=   git-update-cache git-diff-files git-init-db git-write-tree \
	git-read-tree git-commit-tree git-cat-file git-fsck-cache \
	git-checkout-cache git-diff-tree git-rev-tree git-ls-files \
	git-check-files git-ls-tree git-merge-base git-merge-cache \
	git-unpack-file git-export git-diff-cache git-convert-cache \
	git-http-pull git-ssh-push git-ssh-pull git-rev-list git-mktag \
	git-diff-helper git-tar-tree git-local-pull git-write-blob \
	git-get-tar-commit-id git-apply git-stripspace git-cvs2git \
	git-diff-stages git-rev-parse git-patch-id git-pack-objects \
	git-unpack-objects git-verify-pack git-receive-pack git-send-pack \
	git-prune-packed git-fetch-pack git-upload-pack

SCRIPT=	commit-id tree-id parent-id cg-add cg-admin-lsobj cg-admin-uncommit \
	cg-branch-add cg-branch-ls cg-cancel cg-clone cg-commit cg-diff \
	cg-export cg-help cg-init cg-log cg-merge cg-mkpatch cg-patch \
	cg-pull cg-restore cg-rm cg-seek cg-status cg-tag cg-tag-ls cg-update \
	cg cg-admin-ls cg-push cg-branch-chg

LIB_SCRIPT=cg-Xlib cg-Xmergefile cg-Xnormid

GEN_SCRIPT= cg-version

VERSION= VERSION

COMMON=	read-cache.o

LIB_OBJS=read-cache.o sha1_file.o usage.o object.o commit.o tree.o blob.o \
	 tag.o date.o index.o diff-delta.o patch-delta.o entry.o \
	 epoch.o refs.o csum-file.o pack-check.o pkt-line.o connect.o
LIB_FILE=libgit.a
LIB_H=cache.h object.h blob.h tree.h commit.h tag.h delta.h epoch.h csum-file.h \
	pack.h pkt-line.h refs.h

LIB_H += strbuf.h
LIB_OBJS += strbuf.o

LIB_H += diff.h count-delta.h
DIFF_OBJS = diff.o diffcore-rename.o diffcore-pickaxe.o diffcore-pathspec.o \
	diffcore-break.o diffcore-order.o
LIB_OBJS += $(DIFF_OBJS) count-delta.o

LIB_OBJS += gitenv.o

LIBS = $(LIB_FILE)
LIBS += -lz

ifndef NO_OPENSSL
	LIB_OBJS += epoch.o
	LIB_H += epoch.h
else
	CFLAGS += '-DNO_OPENSSL'
	MOZILLA_SHA1=1
endif
ifdef MOZILLA_SHA1
	SHA1_HEADER="mozilla-sha1/sha1.h"
	LIB_OBJS += mozilla-sha1/sha1.o
else
ifdef PPC_SHA1
	SHA1_HEADER="ppc/sha1.h"
	LIB_OBJS += ppc/sha1.o ppc/sha1ppc.o
else
	SHA1_HEADER=<openssl/sha.h>
	LIBS += -lcrypto
endif
endif

CFLAGS += '-DSHA1_HEADER=$(SHA1_HEADER)'

.PHONY: all git cogito
all: git cogito
git: $(PROG)
cogito: $(GEN_SCRIPT)

test-delta: test-delta.c diff-delta.o patch-delta.o
	$(CC) $(CFLAGS) -o $@ $^

check:
	for i in *.c; do sparse $(CFLAGS) $(SPARSE_FLAGS) $$i; done

test-date: test-date.c date.o
	$(CC) $(CFLAGS) -o $@ test-date.c date.o

git-%: %.o $(LIB_FILE)
	$(CC) $(CFLAGS) -o $@ $(filter %.o,$^) $(LIBS)

git-rev-list: LIBS += -lssl
git-http-pull: LIBS += -lcurl
git-http-pull: pull.o
git-local-pull: pull.o
git-ssh-pull: pull.o rsh.o
git-ssh-push: rsh.o

$(LIB_OBJS): $(LIB_H)
$(DIFF_OBJS): diffcore.h

$(LIB_FILE): $(LIB_OBJS)
	$(AR) rcs $@ $(LIB_OBJS)


ifneq (,$(wildcard .git))
GIT_HEAD=.git/HEAD
GIT_HEAD_ID=" \($(shell cat $(GIT_HEAD))\)"
endif
cg-version: $(VERSION) $(GIT_HEAD) Makefile
	@echo Generating cg-version...
	@rm -f $@
	@echo "#!/bin/sh" > $@
	@echo "#" >> $@
	@echo "# Show the version of the Cogito toolkit." >> $@
	@echo "# Copyright (c) Petr Baudis, 2005" >> $@
	@echo "#" >> $@
	@echo "# Show which version of Cogito is installed." >> $@
	@echo "# Additionally, the 'HEAD' of the installed Cogito" >> $@
	@echo "# is also shown if this information was available" >> $@
	@echo "# at the build time." >> $@
	@echo >> $@
	@echo "USAGE=\"cg-version\"" >> $@
	@echo >> $@
	@echo "echo \"$(shell cat $(VERSION))$(GIT_HEAD_ID)\"" >> $@
	@chmod +x $@

cogito.spec: cogito.spec.in $(VERSION)
	sed -e 's/@@VERSION@@/$(shell cat $(VERSION) | cut -d"-" -f2)/g' < $< > $@

test: all
	$(MAKE) -C t/ all

doc:
	$(MAKE) -C Documentation/ all

sedlibdir=$(shell echo $(libdir) | sed 's/\//\\\//g')

.PHONY: install install-git install-cogito
install: install-git install-cogito

install-git: $(PROG) $(SCRIPTS)
	$(INSTALL) -m755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(PROG) $(SCRIPTS) $(DESTDIR)$(bindir)

install-cogito: $(SCRIPT) $(LIB_SCRIPT) $(GEN_SCRIPT)
	$(INSTALL) -m755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(SCRIPT) $(GEN_SCRIPT) $(DESTDIR)$(bindir)
	$(INSTALL) -m755 -d $(DESTDIR)$(libdir)
	$(INSTALL) $(LIB_SCRIPT) $(DESTDIR)$(libdir)
	cd $(DESTDIR)$(bindir); \
	for file in $(SCRIPT); do \
		sed -e 's/\$${COGITO_LIB}/\$${COGITO_LIB:-$(sedlibdir)\/}/g' $$file > $$file.new; \
		cat $$file.new > $$file; rm $$file.new; \
	done
	cd $(DESTDIR)$(libdir); \
	for file in $(LIB_SCRIPT); do \
		sed -e 's/\$${COGITO_LIB}/\$${COGITO_LIB:-$(sedlibdir)\/}/g' $$file > $$file.new; \
		cat $$file.new > $$file; rm $$file.new; \
	done

uninstall:
	cd $(DESTDIR)$(bindir) && rm -f $(PROG) $(SCRIPTS) $(SCRIPT) $(GEN_SCRIPT)
	cd $(DESTDIR)$(libdir) && rm -f $(LIB_SCRIPT)

tarname=$(shell cat $(VERSION))
dist: cogito.spec
	cg-export $(tarname).tar
	@mkdir $(tarname)
	@cp cogito.spec $(tarname)
	tar rf $(tarname).tar $(tarname)/cogito.spec
	@rm $(tarname)/cogito.spec
	@rmdir $(tarname)
	gzip -9 $(tarname).tar

clean:
	rm -f *.o mozilla-sha1/*.o ppc/*.o $(PROG) $(GEN_SCRIPT) $(LIB_FILE)
	$(MAKE) -C Documentation/ clean

backup: clean
	cd .. ; tar czvf dircache.tar.gz dir-cache
