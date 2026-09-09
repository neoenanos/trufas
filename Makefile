####################################################################################################
# Configuration
####################################################################################################

# Build configuration

OUTPUT_FILENAME = ACCELERATOR\ -\ trufas
COVER_IMAGE = images/cover.jpg

# If true, build directly from one markdown file.
# If false, split the source into chapters first.
SINGLE_SOURCE ?= true
SPLIT_SRC := chapters/trufas.md

ifeq ($(SINGLE_SOURCE),true)
CHAPTERS := ./chapters/trufas.md
else
# Add many
CHAPTERS += $(addprefix ./chapters/,\
s/trufas.md
)
endif


BUILD = build
MAKEFILE = Makefile
METADATA = metadata.yml

BOOKLET_SIGNATURE = 28

BLANK_TEMPLATE = templates/blank-empty.tex
BLANK_PDF = $(BUILD)/pdf/blank-pages.pdf
BOOKLET_OUTPUT = $(BUILD)/pdf/$(OUTPUT_FILENAME)-book.pdf

TOC = # --toc --toc-depth 5
METADATA_ARGS = --metadata-file $(METADATA)
IMAGES = $(shell find images -type f)
TEMPLATES = $(shell find templates/ -type f)
MATH_FORMULAS = --webtex

# Debugging
QUIET = @
DEBUG_ARGS = # --verbose

# Chapters content
CONTENT = $(QUIET)awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $(CHAPTERS)
CONTENT_FILTERS = tee # Use this to add sed filters or other piped commands

# Pandoc filtes - uncomment the following variable to enable cross references filter. For more
# information, check the "Cross references" section on the README.md file.

# FILTER_ARGS = --filter pandoc-crossref

# Per-format include fragments (use format-appropriate raw snippets)
COMPILE_DATE = $(shell date +"%Y-%m-%d")
DATE_METADATA = --metadata=date:$(COMPILE_DATE)

# Combined arguments

ARGS = $(TOC) $(MATH_FORMULAS) $(METADATA_ARGS) $(DATE_METADATA) $(FILTER_ARGS) $(DEBUG_ARGS)
	
PANDOC_COMMAND = pandoc --lua-filter=filters/verse-sections.lua --lua-filter=filters/center.lua

# Per-format options

DOCX_ARGS = --standalone --reference-doc templates/docx.docx
EPUB_ARGS = --template templates/epub.html --epub-cover-image $(COVER_IMAGE) --css=templates/style.css --include-before=templates/colophon.html
HTML_ARGS = --template templates/html.html --standalone --to html5
PDF_ARGS = --pdf-engine lualatex --lua-filter=filters/page-break.lua --template templates/pdf.tex
# --lua-filter=remove-footnotes.lua

# Per-format file dependencies

BASE_DEPENDENCIES = $(MAKEFILE) $(CHAPTERS) $(METADATA) $(IMAGES) $(TEMPLATES)
DOCX_DEPENDENCIES = $(BASE_DEPENDENCIES)
EPUB_DEPENDENCIES = $(BASE_DEPENDENCIES)
HTML_DEPENDENCIES = $(BASE_DEPENDENCIES)
PDF_DEPENDENCIES = $(BASE_DEPENDENCIES)
BOOKLET_DEPENDENCIES = $(BASE_DEPENDENCIES) $(BLANK_PDF)

# Detected Operating System

OS = $(shell sh -c 'uname -s 2>/dev/null || echo Unknown')

# OS specific commands

ifeq ($(OS),Darwin) # Mac OS X
	COPY_CMD = cp -P
else # Linux
	COPY_CMD = cp --parent
endif

MKDIR_CMD = $(QUIET)mkdir -p
RMDIR_CMD = rm -r
ECHO_BUILDING = @echo "building $@..."
ECHO_BUILT = @echo "$@ was built"
RENAME_CHAPTERS = rename -f 's/ /_/g' chapters/*

####################################################################################################
# Basic actions
####################################################################################################

.PHONY: all book clean clean-tmp copy epub html pdf docx booklet split blank-pdf

all:	book

book:	split epub html blank-pdf pdf docx booklet clean-tmp

clean:
	$(RMDIR_CMD) $(BUILD)

clean-tmp:
	rm -f $(BUILD)/pdf/$(OUTPUT_FILENAME)-with-blank.pdf $(BLANK_PDF) $(BUILD)/pdf/blank-pages.aux $(BUILD)/pdf/blank-pages.log $(BUILD)/pdf/blank-pages.out


####################################################################################################
# File builders
####################################################################################################

epub:	split $(BUILD)/epub/$(OUTPUT_FILENAME).epub

html:	split $(BUILD)/html/$(OUTPUT_FILENAME).html

pdf:	split $(BUILD)/pdf/$(OUTPUT_FILENAME).pdf

docx:	split $(BUILD)/docx/$(OUTPUT_FILENAME).docx

booklet: $(BOOKLET_OUTPUT)

blank-pdf: $(BLANK_PDF)

$(BUILD)/epub/$(OUTPUT_FILENAME).epub:	$(EPUB_DEPENDENCIES)
	$(ECHO_BUILDING)
	$(MKDIR_CMD) $(BUILD)/epub
	$(CONTENT) | $(CONTENT_FILTERS) | $(PANDOC_COMMAND) $(ARGS) $(EPUB_ARGS) -o "$@"
	$(ECHO_BUILT)

$(BUILD)/html/$(OUTPUT_FILENAME).html:	$(HTML_DEPENDENCIES)
	$(ECHO_BUILDING)
	$(MKDIR_CMD) $(BUILD)/html
	$(CONTENT) | $(CONTENT_FILTERS) | $(PANDOC_COMMAND) $(ARGS) $(HTML_ARGS) -o "$@"
	$(QUIET)$(COPY_CMD) $(IMAGES) $(BUILD)/html/
	$(ECHO_BUILT)

$(BUILD)/pdf/$(OUTPUT_FILENAME).pdf:	$(PDF_DEPENDENCIES)
	$(ECHO_BUILDING)
	$(MKDIR_CMD) $(BUILD)/pdf
	$(CONTENT) | $(CONTENT_FILTERS) | $(PANDOC_COMMAND) $(ARGS) $(PDF_ARGS) -o "$@"
	$(ECHO_BUILT)

$(BUILD)/docx/$(OUTPUT_FILENAME).docx:	$(DOCX_DEPENDENCIES)
	$(ECHO_BUILDING)
	$(MKDIR_CMD) $(BUILD)/docx
	$(CONTENT) | $(CONTENT_FILTERS) | $(PANDOC_COMMAND) $(ARGS) $(DOCX_ARGS) -o "$@"
	$(ECHO_BUILT)

$(BOOKLET_OUTPUT): $(BOOKLET_DEPENDENCIES) $(BUILD)/pdf/$(OUTPUT_FILENAME).pdf
	$(ECHO_BUILDING)
	pdfunite $(BLANK_PDF) $(BUILD)/pdf/$(OUTPUT_FILENAME).pdf $(BUILD)/pdf/$(OUTPUT_FILENAME)-with-blank.pdf
	pdfbook2 \
		--signature $(BOOKLET_SIGNATURE) \
		--paper=letterpaper \
		--short-edge \
		--no-crop \
		$(BUILD)/pdf/$(OUTPUT_FILENAME)-with-blank.pdf
	mv $(BUILD)/pdf/$(OUTPUT_FILENAME)-with-blank-book.pdf "$@"
	$(ECHO_BUILT)

$(BLANK_PDF): $(BLANK_TEMPLATE) $(TEMPLATES)
	$(ECHO_BUILDING)
	$(MKDIR_CMD) $(BUILD)/pdf
	lualatex -interaction=batchmode -output-directory=$(BUILD)/pdf -jobname=blank-pages $(BLANK_TEMPLATE)
	$(ECHO_BUILT)

####################################################################################################
# Split book.md into chapters
####################################################################################################

SPLIT_DIR := chapters/s

ifeq ($(SINGLE_SOURCE),true)

split:
	@:

else

split:
	@echo "Splitting $(SPLIT_SRC) into H1 sections..."
	@rm -f $(SPLIT_DIR)/*.md
	@mkdir -p $(SPLIT_DIR)
	@awk '/^# / { \
		if (out) close(out); \
		title = $$0; \
		sub(/^# /, "", title); \
		gsub(/\r/, "", title); \
		filename = title; \
		gsub(/ /, "_", filename); \
		out = "$(SPLIT_DIR)/" filename ".md"; \
	} \
	{ print >> out }' $(SPLIT_SRC)
	@echo "Done."

endif