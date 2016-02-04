# Makefile for converting GitHub markdown files into HTML.

PANDOC      = pandoc
FROM_FMT    = markdown_github-hard_line_breaks
TO_FMT      = html5
PANDOC_OPTS = --self-contained
HTML_FILES  = $(patsubst %.md, %.html, $(filter-out README.md, $(wildcard *.md)))

ifeq ($(shell which $(PANDOC) > /dev/null 2>&1; echo $$?), 1)
$(error The '$(PANDOC)' command was not found. See pandoc.org)
endif

.PHONEY: all clean

all: $(HTML_FILES)

%.html: %.md
	$(PANDOC) $(PANDOC_OPTS) -f $(FROM_FMT) -t $(TO_FMT) $< > $@

clean:
	rm -f *.html
