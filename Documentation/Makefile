CG_IGNORE=$(wildcard ../cg-X*)
CG_SRC=$(filter-out $(CG_IGNORE), $(wildcard ../cg-*))

MAN1_TXT=$(patsubst ../cg-%,cg-%.txt,$(CG_SRC))
MAN7_TXT=cogito.txt

DOC_HTML=$(patsubst %.txt,%.html,$(MAN1_TXT) $(MAN7_TXT)) introduction.html

DOC_MAN1=$(patsubst %.txt,%.1,$(MAN1_TXT))
DOC_MAN7=$(patsubst %.txt,%.7,$(MAN7_TXT))

prefix=$(HOME)
bin=$(prefix)/bin
mandir=$(prefix)/man
man1=$(mandir)/man1
man7=$(mandir)/man7
docdir=$(prefix)/share/doc/cogito
txtdir=$(docdir)/txt
htmldir=$(docdir)/html

INSTALL=install

#
# Please note that there is a minor bug in asciidoc.
# The version after 6.0.3 _will_ include the patch found here:
#   http://marc.theaimsgroup.com/?l=git&m=111558757202243&w=2
#
# Until that version is released you may have to apply the patch
# yourself - yes, all 6 characters of it!
#

all: html man

html: $(DOC_HTML)


man: man1 man7
man1: $(DOC_MAN1)
man7: $(DOC_MAN7)

install: man
	$(INSTALL) -m755 -d $(DESTDIR)/$(txtdir)
	$(INSTALL) $(MAN1_TXT) $(MAN7_TXT) $(DESTDIR)/$(txtdir)
	$(INSTALL) -m755 -d $(DESTDIR)/$(man1) $(DESTDIR)/$(man7)
	$(INSTALL) $(DOC_MAN1) $(DESTDIR)/$(man1)
	$(INSTALL) $(DOC_MAN7) $(DESTDIR)/$(man7)

install-html: html
	$(INSTALL) -m755 -d $(DESTDIR)/$(htmldir)
	$(INSTALL) $(DOC_HTML) $(DESTDIR)/$(htmldir)

clean:
	rm -f *.xml *.html *.1 *.7 cg-*.txt cogito.txt

.PRECIOUS: %.txt

introduction.html: ../README
	asciidoc -b xhtml11 -d article -f asciidoc.conf -o $@ $<

%.html : %.txt
	asciidoc -b xhtml11 -d manpage -f asciidoc.conf $<

%.1 %.7 : %.xml
	xmlto man $<

%.xml : %.txt
	asciidoc -b docbook -d manpage -f asciidoc.conf $<

cogito.txt : make-cogito-asciidoc
	./make-cogito-asciidoc > $@

cg-%.txt : ../cg-% make-cg-asciidoc
	./make-cg-asciidoc $< > $@
