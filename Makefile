INSTALL_DIR ?= /usr/local/bin

TEST_PROJECT_DIRS := objective-c-test

all: install

rcel:
	echo 'exec $(PWD)/rcel.rb' > $@
	chmod +x $@

install: rcel
	cp rcel $(INSTALL_DIR)

test:
	find . -name '*_test.rb' | xargs -n 1 ruby

clean:
	-rm -f rcel
	-rm -rf $(TEST_PROJECT_DIRS)
