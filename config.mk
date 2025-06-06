# The following tools are used by this file.
# All are assumed to be on the path, but you can override these
# in the environment, or command line.

# xml2rfc (when running locally, this is installed in a virtualenv for you)
XML2RFC_RFC_BASE_URL := https://www.rfc-editor.org/rfc/
XML2RFC_ID_BASE_URL := https://datatracker.ietf.org/doc/html/

# Set sensible defaults for different xml2rfc targets.
# Common options (which are added to $xml2rfc later) so that they can be tweaked further.
XML2RFC_OPTS := -q --rfc-base-url $(XML2RFC_RFC_BASE_URL) --id-base-url $(XML2RFC_ID_BASE_URL) --allow-local-file-access
# Target-specific options.
XML2RFC_TEXT := --text
ifeq (true,$(TEXT_PAGINATION))
XML2RFC_TEXT += --pagination
else
XML2RFC_TEXT += --no-pagination
endif
XML2RFC_CSS := $(LIBDIR)/v3.css
XML2RFC_HTML := --html --css=$(XML2RFC_CSS) --metadata-js-url=/dev/null

# If you are using markdown files use either kramdown-rfc or mmark
#   https://github.com/cabo/kramdown-rfc
# (when running locally, kramdown-rfc is installed for you)
kramdown-rfc ?= kramdown-rfc
# Tell kramdown not to generate targets on references so the above takes effect.
export KRAMDOWN_NO_TARGETS := true
export KRAMDOWN_PERSISTENT := true
ifneq (true,$(VERBOSE))
# Suppress messages about downloading references.
export KRAMDOWN_REFCACHE_QUIET := true
endif

# Use an emoji for the favicon
FAVICON_EMOJI ?=
ifneq (,$(FAVICON_EMOJI))
FAVICON ?= <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>$(FAVICON_EMOJI)</text></svg>">
endif

#  mmark (https://github.com/mmarkdown/mmark)
mmark ?= mmark

# If you are using outline files:
#   https://github.com/Juniper/libslax/tree/master/doc/oxtradoc
oxtradoc ?= oxtradoc.in

# When using rfc2629.xslt extensions:
#   https://greenbytes.de/tech/webdav/rfc2629xslt.html
xsltproc ?= xsltproc

# For sanity checkout your draft:
#   https://github.com/ietf-tools/idnits
idnits ?= idnits

# For diff:
#   https://github.com/ietf-tools/iddiff
iddiff ?= iddiff -c 8

# For generating PDF:
#   https://www.gnu.org/software/enscript/
enscript ?= enscript
#   http://www.ghostscript.com/
ps2pdf ?= ps2pdf

# This is for people running macs
SHELL := bash

# For uploading draft "releases" to the datatracker.
curl ?= curl -sS
DATATRACKER_UPLOAD_URL ?= https://datatracker.ietf.org/api/submission

# The type of index that is created for gh-pages.
# Supported options are 'html' and 'md'.
INDEX_FORMAT ?= html

# For spellchecking: pip install --user codespell
codespell ?= codespell

# Tracing tool
trace := $(LIBDIR)/trace.sh

# Where versioned copies are stored.
VERSIONED ?= versioned

# We can blame this one on some weird configuration.
TMPDIR ?= /tmp

# Set this to "true" to disable caching where possible.
DISABLE_CACHE ?= false
ifeq (true,$(DISABLE_CACHE))
# Disable caching in kramdown-rfc.
KRAMDOWN_REFCACHE_REFETCH := true
export KRAMDOWN_REFCACHE_REFETCH
# xml2rfc caches always, so point it at an empty directory.
TEMP_CACHE := $(shell mktemp -d)
XML2RFC_REFCACHEDIR := $(TEMP_CACHE)
else
# Enable caching for kramdown-rfc and xml2rfc.
ifeq (,$(KRAMDOWN_REFCACHEDIR))
ifeq (true,$(CI))
XML2RFC_REFCACHEDIR := $(realpath .)/.refcache
# In CI, only cache drafts for 5 minutes to pick up on recent updates.
export KRAMDOWN_REFCACHETTL := 300
else
# When running locally, cache drafts for a week.
export KRAMDOWN_REFCACHETTL_RFC := 23673600
# Cache IANA and DOI for 3 months since they change rarely.
export KRAMDOWN_REFCACHETTL := 604800
# Cache RFCs for 9 months since they are immutable.
export KRAMDOWN_REFCACHETTL_DOI_IANA := 7776000
endif
XML2RFC_REFCACHEDIR ?= $(HOME)/.cache/xml2rfc
KRAMDOWN_REFCACHEDIR := $(XML2RFC_REFCACHEDIR)
else
XML2RFC_REFCACHEDIR ?= $(KRAMDOWN_REFCACHEDIR)
endif
ifneq (,$(shell mkdir -p -v $(KRAMDOWN_REFCACHEDIR)))
$(info Created cache directory at $(KRAMDOWN_REFCACHEDIR))
endif
endif # DISABLE_CACHE
XML2RFC_OPTS += --cache=$(XML2RFC_REFCACHEDIR)
export KRAMDOWN_REFCACHEDIR
