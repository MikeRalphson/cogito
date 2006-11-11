CG_IGNORE=$(wildcard ../cg-X* ../cg-*.*)
CG_SRC=$(filter-out $(CG_IGNORE), $(wildcard ../cg*))

PACKAGE=cogito

MAN1_TXT=$(patsubst ../cg%,cg%.1.txt,$(CG_SRC))
MAN7_TXT=$(PACKAGE).7.txt cg-ref.7.txt

DOC_HTML=$(patsubst %.txt,%.html,$(MAN1_TXT) $(MAN7_TXT)) cg-ref.html introduction.html

DOC_MAN1=$(patsubst %.txt,%,$(MAN1_TXT))
DOC_MAN7=$(patsubst %.txt,%,$(MAN7_TXT))

DOC_PDF=$(patsubst %.txt,%.pdf,$(MAN1_TXT) $(MAN7_TXT)) cg-ref.pdf introduction.pdf

prefix?="$(HOME)"
mandir?=$(prefix)/man
man1=$(mandir)/man1
man7=$(mandir)/man7
docdir=$(prefix)/share/doc/$(PACKAGE)
txtdir=$(docdir)/txt
htmldir=$(docdir)/html

INSTALL?=install

#
# Please note that there is a minor bug in asciidoc.
# The version after 6.0.3 _will_ include the patch found here:
#   http://marc.theaimsgroup.com/?l=git&m=111558757202243&w=2
#
# Until that version is released you may have to apply the patch
# yourself - yes, all 6 characters of it!
#

all: html man txt

html: $(DOC_HTML)

man: man1 man7
man1: $(DOC_MAN1)
man7: $(DOC_MAN7)

pdf: $(DOC_PDF)

txt: txt1 txt7
txt1: $(MAN1_TXT)
txt7: $(MAN7_TXT)


install: man txt
	$(INSTALL) -m755 -d $(DESTDIR)/$(txtdir)
	$(INSTALL) $(MAN1_TXT) $(MAN7_TXT) $(DESTDIR)/$(txtdir)
	$(INSTALL) -m755 -d $(DESTDIR)/$(man1) $(DESTDIR)/$(man7)
	$(INSTALL) $(DOC_MAN1) $(DESTDIR)/$(man1)
	$(INSTALL) $(DOC_MAN7) $(DESTDIR)/$(man7)

install-html: html
	$(INSTALL) -m755 -d $(DESTDIR)/$(htmldir)
	$(INSTALL) $(DOC_HTML) $(DESTDIR)/$(htmldir)

test:
	$(MAKE) -C tutorial-script test

clean:
	$(MAKE) -C tutorial-script clean
	rm -f *.xml *.html *.pdf *.1 *.7 cg*.[17].txt $(PACKAGE).7.txt

.PRECIOUS: cg%.txt introduction.txt

%.1.html : %.1.txt
	asciidoc -b xhtml11 -d manpage -f asciidoc.conf $<

%.7.html : %.7.txt
	asciidoc -b xhtml11 -d manpage -f asciidoc.conf $<

%.html : %.txt
	asciidoc -b xhtml11 -d article -f asciidoc.conf -o $@ $<

%.1.xml : %.1.txt
	asciidoc -b docbook -d manpage -f asciidoc.conf $<

%.7.xml : %.7.txt
	asciidoc -b docbook -d manpage -f asciidoc.conf $<

%.xml : %.txt
	asciidoc -b docbook -d article -f asciidoc.conf $<

%.1 : %.1.xml
	xmlto man $<

%.7 : %.7.xml
	xmlto man $<

%.pdf : %.xml
	docbook2pdf $<

$(PACKAGE).7.txt : make-$(PACKAGE)-asciidoc
	./make-$(PACKAGE)-asciidoc > $@

cg-ref.7.txt : cg-ref.txt make-cg-ref-asciidoc
	CGPACKAGE=$(PACKAGE) ./make-cg-ref-asciidoc $< > $@

# It seems that cg%.txt won't match this so use an explicit rule
cg.1.txt : ../cg make-cg-asciidoc
	CGPACKAGE=$(PACKAGE) ./make-cg-asciidoc $< > $@

cg-%.1.txt : ../cg-% make-cg-asciidoc
	CGPACKAGE=$(PACKAGE) ./make-cg-asciidoc $< > $@

introduction.txt: ../README
	sed -e 's/\([a-zA-Z0-9_-]*\)(\([0-9]\))/gitlink:\1[\2]/g' $< >$@
