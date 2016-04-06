VERSION = x.x

default: deb rpm

all: deb rpm

deb:
	dpkg-buildpackage -us -uc

rpm:
	./prepare_rpm_spec_file.sh

clean:
	rm -rf debian/tmp
	rm -rf debian/perun-slave-meta*
	rm -f debian/files
	rm -f ../perun-slave-meta*
