#!/usr/bin/make -f

INSTALL = install
BINDIR = $(DESTDIR)/etc/init.d/

build: ;

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) ./etc/* $(BINDIR)
