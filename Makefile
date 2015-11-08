PACKAGE = openssl
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --libdir=lib
CONF_FLAGS = --openssldir=/etc/ssl enable-ec_nistp_64_gcc_128 zlib linux-x86_64 -Wa,--noexecstack
CFLAGS = -static -static-libgcc -Wl,-static -lc

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/OpenSSL_//;s/_/./g')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

ZLIB_VERSION = 1.2.8-1
ZLIB_URL = https://github.com/amylum/zlib/releases/download/$(ZLIB_VERSION)/zlib.tar.gz
ZLIB_TAR = zlib.tar.gz
ZLIB_DIR = /tmp/zlib
ZLIB_PATH = -I$(ZLIB_DIR)/usr/include -L$(ZLIB_DIR)/usr/lib

.PHONY : default submodule manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(ZLIB_DIR) $(ZLIB_TAR)
	mkdir $(ZLIB_DIR)
	curl -sLo $(ZLIB_TAR) $(ZLIB_URL)
	tar -x -C $(ZLIB_DIR) -f $(ZLIB_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -p0 -d $(BUILD_DIR) < patches/no-rpath.patch
	patch -p0 -d $(BUILD_DIR) < patches/ca-dir.patch
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./Configure $(PATH_FLAGS) $(CONF_FLAGS) $(ZLIB_PATH)
	cd $(BUILD_DIR) && INSTALL_PREFIX=$(RELEASE_DIR) MANDIR=/usr/share/man make install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/LICENSE $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

