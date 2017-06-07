#!/usr/bin/make -f

INSTALL = install
CONFDIR = $(DESTDIR)/etc/perun/$(subst -,_,${NAME}).d
BINDIR = $(DESTDIR)/opt/perun/bin
LIBDIR = $(DESTDIR)/opt/perun/lib/$(subst -,_,${NAME})
CACHEDIR = $(DESTDIR)/var/lib/perun/$(subst -,_,${NAME})
TMPFILESDIR = $(DESTDIR)/usr/lib/tmpfiles.d/

build: ;

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) ./bin/* $(BINDIR)
	$(INSTALL) -d -m 755 $(CACHEDIR)
