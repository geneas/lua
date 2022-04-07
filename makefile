SUBDIRS = 
VERSION ?= 5.1 5.3 5.4

all:
	for v in $(VERSION); do for d in $(SUBDIRS); do make -C $$d LUAVERSION=$$v all; done; done

clean:
	for v in $(VERSION); do for d in $(SUBDIRS); do make -C $$d LUAVERSION=$$v clean; done; done

install: install51 install53 install54 installsubs

installsubs:
	for v in $(VERSION); do for d in $(SUBDIRS); do make -C $$d LUAVERSION=$$v install; done; done

install51:
	lua5.1 ./install.lua -vf files51.txt -d geneas
	
install53:
	lua5.3 ./install.lua -vf files53.txt -d geneas
	
install54:
	lua5.4 ./install.lua -vf files54.txt -d geneas

test:	test51 test53 test54

test51: all
	@for f in `grep -v '^#' files51.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.1 test $$f:"; \
			lua5.1 test.lua $(TEST_OPT) -mfiles51.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done

test53: all
	@for f in `grep -v '^#' files53.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.3 test $$f:"; \
			lua5.3 test.lua $(TEST_OPT) -mfiles53.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done

test54: all
	@for f in `grep -v '^#' files54.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.4 test $$f:"; \
			lua5.4 test.lua $(TEST_OPT) -mfiles54.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done
