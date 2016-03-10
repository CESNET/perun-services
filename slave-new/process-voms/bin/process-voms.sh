#!/bin/bash

# Script for managing user membership in VOs

PROTOCOL_VERSION='3.0.0'

function process {

	EXECSCRIPT="${LIB_DIR}/${SERVICE}/process-voms.pl"

	$EXECSCRIPT -
}
