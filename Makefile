# Should be changed to /usr/local
prefix=$(HOME)

bindir=$(prefix)/bin
libdir=$(prefix)/lib/cogito

INSTALL?=install



### --- END CONFIGURATION SECTION ---



SCRIPT=	commit-id tree-id parent-id cg-add cg-admin-lsobj cg-admin-uncommit \
	cg-branch-add cg-branch-ls cg-reset cg-clone cg-commit cg-diff \
	cg-export cg-help cg-init cg-log cg-merge cg-mkpatch cg-patch \
	cg-pull cg-restore cg-rm cg-seek cg-status cg-tag cg-tag-ls cg-update \
	cg cg-admin-ls cg-push cg-branch-chg

LIB_SCRIPT=cg-Xlib cg-Xmergefile cg-Xnormid

GEN_SCRIPT= cg-version

VERSION= VERSION



### Build rules

.PHONY: all cogito
all: cogito


cogito: $(GEN_SCRIPT)

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

doc:
	$(MAKE) -C Documentation all



### Testing rules

test: all
	$(MAKE) -C t/ all



### Installation rules

sedlibdir=$(shell echo $(libdir) | sed 's/\//\\\//g')

.PHONY: install install-cogito install-doc
install: install-cogito

install-cogito: $(SCRIPT) $(LIB_SCRIPT) $(GEN_SCRIPT)
	$(INSTALL) -m755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(SCRIPT) $(GEN_SCRIPT) $(DESTDIR)$(bindir)
	rm -f $(DESTDIR)$(bindir)/cg-cancel
	ln -s cg-reset $(DESTDIR)$(bindir)/cg-cancel
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

install-doc:
	$(MAKE) -C Documentation install

uninstall:
	cd $(DESTDIR)$(bindir) && rm -f $(SCRIPT) $(GEN_SCRIPT)
	cd $(DESTDIR)$(libdir) && rm -f $(LIB_SCRIPT)



### Maintainer's dist rules

cogito.spec: cogito.spec.in $(VERSION)
	sed -e 's/@@VERSION@@/$(shell cat $(VERSION) | cut -d"-" -f2)/g' < $< > $@

GIT_TARNAME=$(shell cat $(VERSION))
dist: cogito.spec
	cg-export $(GIT_TARNAME).tar
	@mkdir -p $(GIT_TARNAME)
	@cp cogito.spec $(GIT_TARNAME)
	tar rf $(GIT_TARNAME).tar $(GIT_TARNAME)/cogito.spec
	@rm -rf $(GIT_TARNAME)
	gzip -f -9 $(GIT_TARNAME).tar

rpm: dist
	rpmbuild -ta $(GIT_TARNAME).tar.gz

Portfile: Portfile.in $(VERSION) dist
	sed -e 's/@@VERSION@@/$(shell cat $(VERSION) | cut -d"-" -f2)/g' < Portfile.in > Portfile
	echo "checksums md5 " `md5sum $(GIT_TARNAME).tar.gz | cut -d ' ' -f 1` >> Portfile



### Cleaning rules

clean:
	rm -f $(GEN_SCRIPT)
	rm -f cogito-*.tar.gz cogito.spec
	$(MAKE) -C Documentation/ clean
