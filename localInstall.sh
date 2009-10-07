#!/bin/sh

PROJDIR="$(dirname "$0")"
case "$PROJDIR" in
	/*)
		;;
	*)
		PROJDIR="${PWD}/${PROJDIR}"
esac

DEPLOY_EXIST_DATA_DIR_REL=webapp/WEB-INF/data
DEPLOY_EXIST_LOGS_DIR_REL=webapp/WEB-INF/logs
DEPLOY_HOME_DIR="$PROJDIR"/testbed
DEPLOY_EXIST_DIR=${DEPLOY_HOME_DIR}/eXist

ant \
'-Ddeploy.host=127.0.0.1' \
"-Ddeploy.home.dir=$DEPLOY_HOME_DIR" \
'-Ddeploy.ssh.user=jmfernandez' \
'-Ddeploy.eXist.port=8088' \
'-Ddeploy.eXist.basebranch=' \
"-Ddeploy.eXist.data.dir.rel=$DEPLOY_EXIST_DATA_DIR_REL" \
"-Ddeploy.eXist.data.dir.conf.xml=$DEPLOY_EXIST_DATA_DIR_REL" \
"-Ddeploy.eXist.data.dir=${DEPLOY_EXIST_DIR}/$DEPLOY_EXIST_DATA_DIR_REL" \
"-Ddeploy.eXist.conf.dir.rel=eXist" \
'-Ddeploy.eXist.startup.confdir=\$EXIST_HOME' \
'-Ddeploy.eXist.startup.datadir=\$EXIST_HOME/'"$DEPLOY_EXIST_DATA_DIR_REL" \
'-Ddeploy.eXist.startup.logsdir=\$EXIST_HOME/'"$DEPLOY_EXIST_LOGS_DIR_REL" \
"$@"
