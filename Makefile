# Makefile for converting GitHub markdown files into HTML.

PANDOC      = pandoc
FROM_FMT    = markdown_github-hard_line_breaks
TO_FMT      = html5
PANDOC_OPTS = --self-contained --ascii --css resources/style.css

ifeq ($(shell which $(PANDOC) > /dev/null 2>&1; echo $$?), 1)
$(error The '$(PANDOC)' command was not found. See pandoc.org)
endif

all: $(patsubst d%.md, p%.html, $(filter-out README.md, $(wildcard *.md)))
	tar -zcf devjgm-publish.tar.gz $^

p%.html: d%.html
	perl -p -i -e 's/D(\d{4}R\d)/P$$1/g' $<
	perl -p -i -e 's/d(\d{4}r\d)/p$$1/g' $<
	perl -p -i -e 's/(p\d{4}r\d).md/$$1.html/g' $<
	mv $< $(subst d, p, $<)

d%.html: d%.md
	$(PANDOC) $(PANDOC_OPTS) -f $(FROM_FMT) -t $(TO_FMT) $< > $@

clean:
	rm -f *.html *.tar.gz
