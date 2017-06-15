#!/bin/bash

echo "--------------------------------------------"
echo "           GENERATE SPEC FILE"
echo "--------------------------------------------"

TMPDIR="/tmp/perun-slave-rpm-build"
GENERATE_RPM_FOR_SERVICE=$@
SERVICE_NAME=${GENERATE_RPM_FOR_SERVICE#process-}
CONF_SERVICE_NAME=`echo $SERVICE_NAME | tr '-' '_'`
PREFIX="perun-slave-"
CHANGELOG_FILE="$GENERATE_RPM_FOR_SERVICE/changelog"
BIN_DIR="$GENERATE_RPM_FOR_SERVICE/bin/"
CONF_DIR="$GENERATE_RPM_FOR_SERVICE/conf/"
LIB_DIR="$GENERATE_RPM_FOR_SERVICE/lib"
TMPFILES_DIR="$GENERATE_RPM_FOR_SERVICE/tmpfiles.d"
DEPENDENCIES="$GENERATE_RPM_FOR_SERVICE/rpm.dependencies"

if [ ! $GENERATE_RPM_FOR_SERVICE ]; then
  echo "Missing SERVICE directory info, exit without any work!"
	exit 0;
fi

if [ ! -d "$GENERATE_RPM_FOR_SERVICE" ]; then
  echo "Missing directory $GENERATE_RPM_FOR_SERVICE, exit with error!"
	exit 1;
fi

WITH_CONF=0
# If this is process-XY, set config dir (not for base or meta)
if echo ${GENERATE_RPM_FOR_SERVICE} | grep --quiet 'process-'; then
	WITH_CONF=1
fi

WITH_LIB=0
if [ -d "$LIB_DIR" ]; then
	WITH_LIB=1
fi

WITH_TMPFILES=0
if [ -d "$TMPFILES_DIR" ]; then
	WITH_TMPFILES=1
fi

#tar everything in directory of concrete perun-service


mkdir -p ${TMPDIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

tar -zcvf ${TMPDIR}/SOURCES/${GENERATE_RPM_FOR_SERVICE}.tgz ${GENERATE_RPM_FOR_SERVICE}

# prepare variables and constant for creating spec file
VERSION=`head -n 1 $CHANGELOG_FILE | sed -e 's/.*\([0-9]\+[.][0-9]\+[.][0-9]\+\).*/\1/'`
RELEASE='1'
SUMMARY="Perun slave script $GENERATE_RPM_FOR_SERVICE"
LICENSE="Apache License"
GROUP="Applications/System"
SOURCE="${GENERATE_RPM_FOR_SERVICE}.tgz"
REQUIRES=""
BUILDROOT="%{_tmppath}/%{name}-%{version}-build"
DESCRIPTION="Perun slave script $GENERATE_RPM_FOR_SERVICE"

# load dependencies
if [ -f "$DEPENDENCIES" ]; then
	REQUIRES=`sed -e '$ ! s/$/,/' $DEPENDENCIES | tr '\n' ' '`
	REQUIRES="Requires: ${REQUIRES}";
fi

CUSTOM_CONF=""
CUSTOM_FILE_DATA=""
# conf predefined settings
if [ $WITH_CONF == 1 ]; then
	CUSTOM_CONF="mkdir -p %{buildroot}/etc/perun/${CONF_SERVICE_NAME}.d
if ls -A conf/* > /dev/null 2>&1 ; then cp -r conf/* %{buildroot}/etc/perun/${CONF_SERVICE_NAME}.d ;fi"
	CUSTOM_FILE_DATA="/etc/perun/${CONF_SERVICE_NAME}.d"
fi
if [ $WITH_LIB == 1 ]; then
  CUSTOM_CONF="$CUSTOM_CONF
mkdir -p %{buildroot}/opt/perun/lib/${CONF_SERVICE_NAME}/
cp -r lib/* %{buildroot}/opt/perun/lib/${CONF_SERVICE_NAME}/"
  CUSTOM_FILE_DATA="$CUSTOM_FILE_DATA
/opt/perun/lib/${CONF_SERVICE_NAME}/"
fi
# Append /usr/lib/tmpfiles.d/
if [ $WITH_TMPFILES == 1 ]; then
  CUSTOM_CONF="$CUSTOM_CONF
mkdir -p %{buildroot}/usr/lib/tmpfiles.d/
cp tmpfiles.d/perun.conf %{buildroot}/usr/lib/tmpfiles.d/"
  CUSTOM_FILE_DATA="$CUSTOM_FILE_DATA
/usr/lib/tmpfiles.d/perun.conf"
fi

# generate spec file
SPEC_FILE_NAME="${GENERATE_RPM_FOR_SERVICE}.spec"

if [ ${GENERATE_RPM_FOR_SERVICE} = 'meta' ]; then

cat > $SPEC_FILE_NAME <<EOF
Name: ${PREFIX}full
Version: ${VERSION}
Release: ${RELEASE}
Conflicts: perun-slave
Summary: ${SUMMARY}
License: ${LICENSE}
Group: ${GROUP}
BuildArch: noarch
Source: ${SOURCE}
BuildRoot: $BUILDROOT
$REQUIRES

%description
Perun slave scripts

%prep
%setup -q -n${GENERATE_RPM_FOR_SERVICE}

%build

%install

%files
EOF

else

cat > $SPEC_FILE_NAME <<EOF
Name: ${PREFIX}${GENERATE_RPM_FOR_SERVICE}
Version: ${VERSION}
Release: ${RELEASE}
Conflicts: perun-slave
Summary: ${SUMMARY}
License: ${LICENSE}
Group: ${GROUP}
BuildArch: noarch
Source: ${SOURCE}
BuildRoot: $BUILDROOT
$REQUIRES

%description
Perun slave scripts

%prep
%setup -q -n${GENERATE_RPM_FOR_SERVICE}

%build

%install
mkdir -p %{buildroot}/opt/perun/bin/
mkdir -p %{buildroot}/var/lib/perun/${GENERATE_RPM_FOR_SERVICE}/
cp -r bin/* %{buildroot}/opt/perun/bin/
$CUSTOM_CONF

%files
/opt/perun/bin/*
/var/lib/perun/${GENERATE_RPM_FOR_SERVICE}/
$CUSTOM_FILE_DATA
EOF

fi

#generate RPM
rpmbuild --define "_topdir ${TMPDIR}" -ba ${SPEC_FILE_NAME}

cp ${TMPDIR}/RPMS/noarch/*.rpm ./
rm -rf ${TMPDIR}
rm ${SPEC_FILE_NAME}

exit 0
