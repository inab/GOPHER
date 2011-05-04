#!/bin/bash

PROJDIR="$(dirname "$0")"
case "$PROJDIR" in
	/*)
		;;
	*)
		PROJDIR="${PWD}/${PROJDIR}"
esac

exec bash "${PROJDIR}/localInstall.sh" deploy.skel.meta
