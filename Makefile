SHELL := /bin/bash
.SHELLFLAGS :=  -o pipefail

.DELETE_ON_ERROR:
.SUFFIXES:

INSTALL_DIR ?= /usr/local/bin

TEST_PROJECT_DIRS := objective-c-test

LOCAL_MAN_DIR = /usr/local/share/man

MAN1_SOURCE = $(wildcard doc/*.1.md)

MAN1_TARGETS = $(patsubst %.md,%,$(MAN1_SOURCE))

all: install

rcel:
	echo 'exec $(PWD)/rcel.rb "$$@"' > $@
	chmod +x $@

install:
	if [ ! -e rcel ]; then \
	echo "run 'make rcel' first"; \
	exit 1; \
	fi
	cp rcel $(INSTALL_DIR)

test:
	find . -name '*_test.rb' | xargs -n 1 ruby

clean:
	-rm -f rcel
	-rm -rf $(TEST_PROJECT_DIRS)
	-find doc -name '*.[0-9]' | xargs rm

install-man: man
	if [ ! -d $(LOCAL_MAN_DIR)/man1 ]; then \
	echo directory does not exist: $(LOCAL_MAN_DIR)/man1; \
	exit 1; \
	fi
	for target in $(MAN1_TARGETS); \
	do \
	cp $$target $(LOCAL_MAN_DIR)/man1; \
	done

# An uninstalled man page can be viewed with the man command:
#
#   man doc/foo.1
#
man: $(MAN1_TARGETS)

doc/%.1: doc/%.1.md
	pandoc -s -s -w man $< -o $@
