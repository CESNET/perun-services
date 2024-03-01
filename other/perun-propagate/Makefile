#!/usr/bin/make -f

INSTALL = install
BINDIR = $(DESTDIR)/etc/init.d/
LOGCONFDIR = $(DESTDIR)/etc/logrotate.d/
SYSTEMDDIR = $(DESTDIR)/lib/systemd/system/

build: ;

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -d -m 755 $(LOGCONFDIR)
	$(INSTALL) -d -m 755 $(SYSTEMDDIR)
	$(INSTALL) ./etc/* $(BINDIR)
	$(INSTALL) -m 644 ./log/* $(LOGCONFDIR)
	$(INSTALL) -m 644 ./systemd/* $(SYSTEMDDIR)
