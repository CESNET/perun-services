#!/bin/bash

echo "--------------------------------------------"
echo "           GENERATE SPEC FILE"
echo "--------------------------------------------"

TMPDIR="/tmp/package-rpm-build"
SERVICE_NAME=$1
CHANGELOG_FILE="$SERVICE_NAME/debian/changelog"

SOURCE_DIR1="$2"
SOURCE_DIR2="$4"
SOURCE_DIR3="$6"

echo $3
echo "'$4'"

DEST_DIR1="$3"
DEST_DIR2="$5"
DEST_DIR3="$7"

DEPENDENCIES="$SERVICE_NAME/rpm.dependencies"

if [ ! $SERVICE_NAME ]; then
  echo "Missing SERVICE directory info, exit without any work!"
	exit 0;
fi

if [ ! -d "$SERVICE_NAME" ]; then
  echo "Missing directory $SERVICE_NAME, exit with error!"
	exit 1;
fi

if [ -z "$SOURCE_DIR1" -o -z "$DEST_DIR1" ]; then
	echo "We need to know at least one directory with files.";
	exit 1;
fi

if [ ! -d "$SERVICE_NAME/$SOURCE_DIR1" ]; then
	echo "Need at least one directory!"
	exit 1;
fi

WITH_DIR2=0;
if [ ! -z "$SOURCE_DIR2" -a -d "$SERVICE_NAME/$SOURCE_DIR2" ]; then
	if [ -z "$DEST_DIR2" ]; then
		echo "It is defined second source directory but missing path to second destination directory!"
		exit 1;
	fi
	WITH_DIR2=1
fi

WITH_DIR3=0
if [ ! -z "$SOURCE_DIR3" -a -d "$SERVICE_NAME/$SOURCE_DIR3" ]; then
	if [ -z "$DEST_DIR3" ]; then
		echo "It is defined third source directory but missing path to third destination directory!"
		exit 1;
	fi
	WITH_DIR3=1
fi

#tar everything in directory of concrete perun-service


mkdir -p ${TMPDIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

tar -zcvf ${TMPDIR}/SOURCES/${SERVICE_NAME}.tgz ${SERVICE_NAME}

# prepare variables and constant for creating spec file
VERSION=`head -n 1 $CHANGELOG_FILE | sed -e 's/.*\([0-9]\+[.][0-9]\+[.][0-9]\+\).*/\1/'`
RELEASE='1'
SUMMARY="Package for $SERVICE_NAME"
LICENSE="Apache License"
GROUP="Applications/System"
SOURCE="${SERVICE_NAME}.tgz"
REQUIRES=""
BUILDROOT="%{_tmppath}/%{name}-%{version}-build"
DESCRIPTION=`grep '^Description:' "$SERVICE_NAME/debian/control" | sed -e 's/^Description: //'`

# load dependencies
if [ -f "$DEPENDENCIES" ]; then 
	REQUIRES=`sed -e '$ ! s/$/,/' $DEPENDENCIES | tr '\n' ' '`
	if [ ! -z "$REQUIRES" ]; then
		REQUIRES="Requires: ${REQUIRES}";
	else
		REQUIRES=""
	fi
fi

echo 'ABRAKADABRA: ' . $REQUIRES

CUSTOM_CONF=""
CUSTOM_FILE_DATA=""
# conf predefined settings
if [ $WITH_DIR2 == 1 ]; then
	CUSTOM_CONF="mkdir -p %{buildroot}/$DEST_DIR2
cp -r ./$SOURCE_DIR2/* %{buildroot}/$DEST_DIR2"
	CUSTOM_FILE_DATA="/$DEST_DIR2/*"
fi

if [ $WITH_DIR3 == 1 ]; then
  CUSTOM_CONF="$CUSTOM_CONF
mkdir -p %{buildroot}/$DEST_DIR3/
cp -r ./$SOURCE_DIR3/* %{buildroot}/$DEST_DIR3/"
  CUSTOM_FILE_DATA="$CUSTOM_FILE_DATA
/$DEST_DIR3/*"
fi

# generate spec file
SPEC_FILE_NAME="${SERVICE_NAME}.spec"

cat > $SPEC_FILE_NAME <<EOF
Name: ${SERVICE_NAME}
Version: ${VERSION}
Release: ${RELEASE}
Conflicts: some-conflict-package
Summary: ${SUMMARY}
License: ${LICENSE}
Group: ${GROUP}
BuildArch: noarch
Source: ${SOURCE}
BuildRoot: $BUILDROOT
$REQUIRES

%description
$DESCRIPTION

%prep
%setup -q -n${SERVICE_NAME}

%build

%install
mkdir -p %{buildroot}/$DEST_DIR1/
cp -r ./$SOURCE_DIR1/* %{buildroot}/$DEST_DIR1/
$CUSTOM_CONF

%files
/$DEST_DIR1/*
$CUSTOM_FILE_DATA
EOF

#generate RPM
rpmbuild --define "_topdir ${TMPDIR}" -ba ${SPEC_FILE_NAME}

cp ${TMPDIR}/RPMS/noarch/*.rpm ./
rm -rf ${TMPDIR}
rm ${SPEC_FILE_NAME}

exit 0
