# Should be changed to /usr/local
prefix=$(HOME)

bindir=$(prefix)/bin
libdir=$(prefix)/lib/cogito
sharedir=$(prefix)/share/cogito

INSTALL?=install



### --- END CONFIGURATION SECTION ---



SCRIPT=	cg-object-id cg-add cg-admin-lsobj cg-admin-uncommit \
	cg-branch-add cg-branch-ls cg-reset cg-clone cg-commit cg-diff \
	cg-export cg-help cg-init cg-log cg-merge cg-mkpatch cg-patch \
	cg-fetch cg-restore cg-rm cg-seek cg-status cg-tag cg-tag-ls cg-update \
	cg cg-admin-ls cg-push cg-branch-chg cg-admin-cat cg-clean \
	cg-admin-setuprepo cg-switch

LIB_SCRIPT=cg-Xlib cg-Xmergefile cg-Xfetchprogress

GEN_SCRIPT= cg-version

VERSION= VERSION

SHARE_FILES= default-exclude



### Build rules

.PHONY: all cogito
all: cogito


cogito: $(GEN_SCRIPT)

ifneq (,$(wildcard .git))
GIT_HEAD=.git/$(shell git-symbolic-ref HEAD)
GIT_HEAD_ID=($(shell cat $(GIT_HEAD)))
endif
cg-version: cg-version.in $(VERSION) $(GIT_HEAD)
	@echo Generating cg-version...
	@rm -f $@
	@sed -e 's/@@VERSION@@/$(shell cat $(VERSION))/' \
	     -e 's/@@GIT_HEAD_ID@@/$(GIT_HEAD_ID)/' \
	     < $< > $@ 
	@chmod +x $@

doc:
	$(MAKE) -C Documentation all



### Testing rules

test: all
	$(MAKE) -C t/ all



### Installation rules

sedlibdir=$(shell echo $(libdir) | sed 's/\//\\\//g')
sedsharedir=$(shell echo $(sharedir) | sed 's/\//\\\//g')

.PHONY: install install-cogito install-doc
install: install-cogito

install-cogito: $(SCRIPT) $(LIB_SCRIPT) $(GEN_SCRIPT)
	$(INSTALL) -m755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(SCRIPT) $(GEN_SCRIPT) $(DESTDIR)$(bindir)
	for i in 'cg-cancel:cg-reset' 'commit-id:cg-object-id' \
		'tree-id:cg-object-id' 'parent-id:cg-object-id' \
		'cg-commit-id:cg-object-id' \
		'cg-tree-id:cg-object-id' 'cg-parent-id:cg-object-id' \
		'cg-pull:cg-fetch'; do \
		old=`echo $$i | cut -d : -f 1`; \
		new=`echo $$i | cut -d : -f 2`; \
		rm -f $(DESTDIR)$(bindir)/$$old; \
		ln -s $$new $(DESTDIR)$(bindir)/$$old; \
	done
	$(INSTALL) -m755 -d $(DESTDIR)$(libdir)
	$(INSTALL) $(LIB_SCRIPT) $(DESTDIR)$(libdir)
	cd $(DESTDIR)$(bindir); \
	for file in $(SCRIPT) $(GEN_SCRIPT); do \
		sed -e 's/\$${COGITO_LIB}/\$${COGITO_LIB:-$(sedlibdir)\/}/g; \
		        s/\$${COGITO_SHARE}/\$${COGITO_SHARE:-$(sedsharedir)\/}/g' \
		       $$file > $$file.new; \
		cat $$file.new > $$file; rm $$file.new; \
	done
	cd $(DESTDIR)$(libdir); \
	for file in $(LIB_SCRIPT); do \
		sed -e 's/\$${COGITO_LIB}/\$${COGITO_LIB:-$(sedlibdir)\/}/g; \
		        s/\$${COGITO_SHARE}/\$${COGITO_SHARE:-$(sedsharedir)\/}/g' \
		       $$file > $$file.new; \
		cat $$file.new > $$file; rm $$file.new; \
	done
	$(INSTALL) -m755 -d $(DESTDIR)$(sharedir)
	$(INSTALL) -m644 $(SHARE_FILES) $(DESTDIR)$(sharedir)

install-doc:
	$(MAKE) -C Documentation install

uninstall:
	cd $(DESTDIR)$(bindir) && rm -f $(SCRIPT) $(GEN_SCRIPT)
	cd $(DESTDIR)$(libdir) && rm -f $(LIB_SCRIPT)
	cd $(DESTDIR)$(sharedir) && rm -f $(SHARE_FILES)



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

deb: dist
	tar zxf $(GIT_TARNAME).tar.gz
	dpkg-source -b $(GIT_TARNAME)
	cd $(GIT_TARNAME) && fakeroot debian/rules binary \
		&& cd .. && rm -rf $(GIT_TARNAME)

Portfile: Portfile.in $(VERSION) dist
	sed -e 's/@@VERSION@@/$(shell cat $(VERSION) | cut -d"-" -f2)/g' < Portfile.in > Portfile
	echo "checksums md5 " `md5sum $(GIT_TARNAME).tar.gz | cut -d ' ' -f 1` >> Portfile



### Cleaning rules

clean:
	rm -f $(GEN_SCRIPT)
	rm -f cogito-*.tar.gz cogito.spec
	$(MAKE) -C Documentation/ clean
