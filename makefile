SUBDIRS = 

all:
	for d in $(SUBDIRS); do ( cd $$d; make all ); done

clean:
	for d in $(SUBDIRS); do ( cd $$d; make clean ); done

install: install51 install53 install54
	for d in $(SUBDIRS); do ( cd $$d; make install ); done

install51:
	lua5.1 ./install.lua -vf files51.txt -d geneas
	
install53:
	lua5.3 ./install.lua -vf files53.txt -d geneas
	
install54:
	lua5.4 ./install.lua -vf files54.txt -d geneas

test:	test51 test53 test54

test51:
	@for f in `grep -v '^#' files51.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.1 test $$f:"; \
			lua5.1 test.lua -mfiles51.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done

test53:
	@for f in `grep -v '^#' files53.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.3 test $$f:"; \
			lua5.3 test.lua -mfiles53.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done

test54:
	@for f in `grep -v '^#' files54.txt|cut -d'.' -f1`; do \
		if [ -f test/$$f.lua ]; then \
			echo "lua5.4 test $$f:"; \
			lua5.4 test.lua -mfiles54.txt $$f; \
			status=$$?; \
			if [ "$${status}" != "0" ]; then exit $${status}; fi; \
		fi \
	done
