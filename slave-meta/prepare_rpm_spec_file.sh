#!/bin/bash

# Get version and release from debian changelog
VERSION=`head -n 1 debian/changelog | sed -e 's/^perun-slave-meta (\([0-9]*.[0-9]*.[0-9]*\)-\([0-9]*.[0-9]*.[0-9]*\)) stable; urgency=low$/\1/'`
RELEASE=`head -n 1 debian/changelog | sed -e 's/^perun-slave-meta (\([0-9]*.[0-9]*.[0-9]*\)-\([0-9]*.[0-9]*.[0-9]*\)) stable; urgency=low$/\2/'`

TOPDIR=/tmp/perun-slave-meta-rpm-build

mkdir -p ${TOPDIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# create perun-slave.tar.gz
tar -czf ${TOPDIR}/SOURCES/perun-slave-meta.tar.gz ../slave-meta 

cat > perun-slave-meta.spec <<EOF
Summary: Set of custom Perun pre/post scripts for MetaCentrum
Name: perun-slave-meta
Version: $VERSION
Release: $RELEASE
License: FreeBSD license
Group: Applications/System
BuildArch: noarch

Source0: perun-slave-meta.tar.gz

BuildRoot: %{_tmppath}/%{name}-%{version}-root
%define perun_home /opt/perun/bin

%description
Set of custom Perun pre/post scripts for MetaCentrum

%prep
%setup -q -nslave-meta

%clean
rm -rf %{buildroot}

%install
mkdir -p %{buildroot}%{perun_home}
install perun_propagate %{buildroot}%{perun_home}
rsync -arvz *.d %{buildroot}%{perun_home} --exclude=".svn"

%files
%defattr(-,root,root)
%config(noreplace) %{perun_home}/*.d/*
%{perun_home}
EOF

rpmbuild --define "_topdir ${TOPDIR}" -ba perun-slave-meta.spec

cp ${TOPDIR}/RPMS/noarch/*.rpm ../
rm -rf ${TOPDIR}

rm perun-slave-meta.spec
