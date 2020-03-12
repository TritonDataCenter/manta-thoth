# Copyright 2020 Joyent, Inc.

UNAME=$(shell uname -s | tr "[:upper:]" "[:lower:]")
VER=$(shell json -f package.json version)
NAME := thoth
RELEASE_TARBALL := $(NAME)-$(UNAME)-$(VER).tar.gz
ROOT := $(shell pwd)

NODE_PREBUILT_VERSION=v8.17.0
NODE_PREBUILT_TAG=gz
NODE_PREBUILT_IMAGE=5417ab20-3156-11ea-8b19-2b66f5e7a439

#
# Skip buildenv validation entirely as it's not happy with the lack of a build
# image etc.
#
ENGBLD_SKIP_VALIDATE_BUILDENV = true
ENGBLD_USE_BUILDIMAGE = false
ENGBLD_REQUIRE := $(shell git submodule update --init deps/eng)
include ./deps/eng/tools/mk/Makefile.defs
TOP ?= $(error Unable to access eng.git submodule Makefiles.)
RELSTAGEDIR := /tmp/$(NAME)-$(STAMP)

ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.defs
else
	NPM=npm
	NODE=node
	NPM_EXEC=$(shell which npm)
endif

.PHONY: all
all: | $(NPM_EXEC)
	$(NPM) install

DISTCLEAN_FILES += ./node_modules

.PHONY: release
release: all
	@echo "Building $(RELEASE_TARBALL)"
	mkdir -p $(RELSTAGEDIR)/opt/custom/thoth
	cp -r \
		$(ROOT)/analyzers \
		$(ROOT)/bin \
		$(ROOT)/lib \
		$(ROOT)/node_modules \
		$(ROOT)/package.json \
		$(RELSTAGEDIR)/opt/custom/thoth
	mkdir -p $(RELSTAGEDIR)/opt/custom/thoth/build/
	cp -r $(ROOT)/build/node $(RELSTAGEDIR)/opt/custom/thoth/build/
	(cd $(RELSTAGEDIR) && $(TAR) -I pigz -cf $(ROOT)/$(RELEASE_TARBALL) .)
	@rm -rf $(RELSTAGEDIR)

.PHONY: publish
publish: release
	mput -f $(ROOT)/$(RELEASE_TARBALL) /thoth/public/$(RELEASE_TARBALL)
	# FIXME: also put as -latest

include ./deps/eng/tools/mk/Makefile.deps

ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.targ
endif
include ./deps/eng/tools/mk/Makefile.targ
