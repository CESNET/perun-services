#!/usr/bin/make -f
SHELL=/bin/bash

.PHONY: all generic-package perun-propagate perun-slave-metacentrum clean

all: generic-package perun-propagate perun-slave-metacentrum

perun-slave-metacentrum:
	cd $@ && debuild -us -uc --lintian-opts --profile debian
	@echo "Cleaing after $@ building process..."
	@rm -f *.{build,changes,dsc,tar.gz,tar.xz}
	@rm -rf ./$@/debian/$@*
	@rm -f ./$@/debian/files
	@echo "Generate spec file for $@..."
	@./generate_rpm.sh $@

perun-propagate:
	cd $@ && debuild -us -uc --lintian-opts --profile debian
	@echo "Cleaing after $@ building process..."
	@rm -f *.{build,changes,dsc,tar.gz,tar.xz}
	@rm -rf ./$@/debian/$@*
	@rm -f ./$@/debian/files
	@echo "Generate spec file for $@..."
	@./generate_rpm.sh $@ "etc" "/etc/init.d/"

generic-package:
	cd $@ && debuild -us -uc --lintian-opts --profile debian
	@echo "Cleaing after $@ building process..."
	@rm -f *.{build,changes,dsc,tar.gz,tar.xz}
	@rm -rf ./$@/debian/$@*
	@rm -f ./$@/debian/files
	@echo "Generate spec file for $@..."
	@./generate_rpm.sh $@ bin /opt/perun/bin/ conf /opt/perun/conf/ lib /opt/perun/lib/

clean:
	@rm -f *.{deb,build,changes,dsc,tar.gz,tar.xz,rpm,spec,tgz}
