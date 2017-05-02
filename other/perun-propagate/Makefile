#!/usr/bin/make -f

INSTALL = install
BINDIR = $(DESTDIR)/etc/init.d/
LOGCONFDIR = $(DESTDIR)/etc/logrotate.d/

build: ;

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -d -m 755 $(LOGCONFDIR)
	$(INSTALL) ./etc/* $(BINDIR)
	$(INSTALL) -m 644 ./log/* $(LOGCONFDIR)
