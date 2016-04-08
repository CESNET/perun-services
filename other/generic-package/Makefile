#!/usr/bin/make -f

INSTALL = install
CONFDIR = $(DESTDIR)/etc/perun/
BINDIR = $(DESTDIR)/opt/perun/bin
LIBDIR = $(DESTDIR)/opt/perun/lib/

build: ;

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) ./bin/* $(BINDIR)
	$(INSTALL) -d -m 755 $(CONFDIR)
	$(INSTALL) ./conf/* $(CONFDIR)
	$(INSTALL) -d -m 755 $(LIBDIR)
	$(INSTALL) ./lib/* $(LIBDIR)
