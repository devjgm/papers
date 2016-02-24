# Makefile for converting GitHub markdown files into HTML.

PANDOC      = pandoc
FROM_FMT    = markdown_github-hard_line_breaks
TO_FMT      = html5
PANDOC_OPTS = --self-contained --ascii --css resources/style.css

ifeq ($(shell which $(PANDOC) > /dev/null 2>&1; echo $$?), 1)
$(error The '$(PANDOC)' command was not found. See pandoc.org)
endif

draft: $(patsubst %.md, %.html, $(wildcard d*.md))

publish: $(patsubst d%.md, p%.html, $(wildcard d*.md))

p%.html: d%.html
	@echo "### Making PUBLISH HTML..."
	perl -e 's/D(\d{4}R\d)/P$$1/g;' \
	     -e 's/d(\d{4}r\d)/p$$1/g' -p $< > $@
	git --no-pager diff --no-index -U0 --word-diff=color $< $@ || true
	@echo

d%.html: d%.md
	@echo "### Making DRAFT HTML (diffs displayed for visual review)..."
	perl -p -e 's/(d\d{4}r\d).md/$$1.html/g' $< | \
	$(PANDOC) $(PANDOC_OPTS) -f $(FROM_FMT) -t $(TO_FMT) > $@

clean:
	rm -f *.html
