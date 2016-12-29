PREFIX ?= /usr/local

install:
	[ ! -d $(PREFIX)/lib/bash ] && mkdir $(PREFIX)/lib/bash || true
	cp -f lib.sh $(PREFIX)/lib/bash/lib.sh

uninstall:
	rm -f $(PREFIX)/lib/bash/lib.sh

