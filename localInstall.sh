#!/bin/sh

PROJDIR="$(dirname "$0")"
case "$PROJDIR" in
	/*)
		;;
	*)
		PROJDIR="${PWD}/${PROJDIR}"
esac

EXIST_LOCAL_DIR="${PROJDIR}/external/eXist"

JAVA_TMPHOME="$(\ls -1d /opt/ibm-jdk-bin-1.6* 2> /dev/null |tail -n 1)"
if [ -n "$JAVA_TMPHOME" ] ; then
	JAVA_HOME="$JAVA_TMPHOME"
	export JAVA_HOME
	PATH="${JAVA_HOME}/bin:$PATH"
	export PATH
fi

DEPLOY_EXIST_DATA_DIR_REL=webapp/WEB-INF/data
DEPLOY_EXIST_LOGS_DIR_REL=webapp/WEB-INF/logs
DEPLOY_HOME_DIR="$PROJDIR"/testbed
DEPLOY_EXIST_DIR="${DEPLOY_HOME_DIR}"/eXist

LOCALCLASSPATH="${EXIST_LOCAL_DIR}/lib/core/xmldb.jar" ANT_OPTS="-Djava.endorsed.dirs=${EXIST_LOCAL_DIR}/lib/endorsed" ant \
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
