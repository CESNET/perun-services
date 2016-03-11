#!/bin/bash

# Get version and release from debian changelog
VERSION=`head -n 1 debian/changelog | sed -e 's/^perun-propagate (\([0-9]*.[0-9]*.[0-9]*\)-\([0-9]*.[0-9]*.[0-9]*\)) stable; urgency=low$/\1/'`
RELEASE=`head -n 1 debian/changelog | sed -e 's/^perun-propagate (\([0-9]*.[0-9]*.[0-9]*\)-\([0-9]*.[0-9]*.[0-9]*\)) stable; urgency=low$/\2/'`

TOPDIR=/tmp/perun-propagate-rpm-build

mkdir -p ${TOPDIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# create perun-propagate.tar.gz
tar -czf ${TOPDIR}/SOURCES/perun-propagate.tar.gz ../perun-propagate

cat > perun-propagate.spec <<EOF
Summary: Perun propagate script
Name: perun-propagate
Version: $VERSION
Release: $RELEASE
License: FreeBSD license
Group: Applications/System
BuildArch: noarch

Source0: perun-propagate.tar.gz

BuildRoot: %{_tmppath}/%{name}-%{version}-root
%define perun_home /opt/perun/bin

%description
Perun propagate script., which is used to force user provisioning and service configuration by calling Perun API.

%prep
%setup -q -nperun-propagate

%clean
rm -rf %{buildroot}

%install
mkdir -p %{buildroot}%{perun_home}
install perun_propagate %{buildroot}%{perun_home}
#rsync -arvz *.d %{buildroot}%{perun_home} --exclude=".svn"

%files
%defattr(-,root,root)
%{perun_home}
EOF

rpmbuild --define "_topdir ${TOPDIR}" -ba perun-propagate.spec

cp ${TOPDIR}/RPMS/noarch/*.rpm ../
rm -rf ${TOPDIR}

rm perun-propagate.spec
