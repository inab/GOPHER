#!/bin/bash

# Safety, the first
LC_ALL=C
export LC_ALL

#VAPORDIRS="${HOME}/projects/bioVapor"
#JAVALIBDIRS="${JAVALIBDIRS}/ensembl-exist/dist"
BRANCH="GOPHER"
BASEBRANCHES="/databases/eXist"
EXIST_HOME="${BASEBRANCHES}/eXist-${BRANCH}"
EXISTDATACONF_HOME="${BASEBRANCHES}/dataconf-${BRANCH}"
SERVERXML="${EXISTDATACONF_HOME}/server.xml"
export EXIST_HOME EXISTCONF_HOME

JAVA_OPTIONS="-Xmx768m -Xms384m -Dfile.encoding=UTF-8 -Dserver.xml=${SERVERXML} -Djavax.xml.transform.TrsformerFactory=net.sf.saxon.TransformerFactoryImpl"
export JAVA_OPTIONS

JAVA_HOME="${HOME}/ibm-java-i386-60"
#JAVA_HOME=/usr/lib/jvm/java-6-sun
export JAVA_HOME

# Exist by-passes Java CLASSPATH
# so, let's follow their role.
#ln -sf "${JAVALIBDIRS}"/*.jar "${EXIST_HOME}/lib/user"

#cp "${VAPORDIRS}"/mime-types.xml "${EXIST_HOME}"

if [ $# = 0 ] ; then
	status=start
else
	status="$1"
fi

EXISTPID=$(pgrep -f "exist.home=${EXIST_HOME} ")
case "$status" in
	start)
		if [ -n "$EXISTPID" ] ; then
			echo "eXist instance ${BRANCH} is ALREADY running with pid $EXISTPID" 1>&2
			RETVAL=1
		else
			cp -pf "${EXISTDATACONF_HOME}/conf.xml" "${EXIST_HOME}"
			exec bash "${EXIST_HOME}/bin/server.sh"
		fi
		;;
	stop)
		if [ -n "$EXISTPID" ] ; then
			echo "Trying to kill eXist instance ${BRANCH} with pid $EXISTPID" 1>&2
			kill $EXISTPID
		else
			echo "eXist instance ${BRANCH} is NOT running!!!" 1>&2
			RETVAL=1
		fi
		;;
	kill9)
		if [ -n "$EXISTPID" ] ; then
			echo "Trying to kill (-9) eXist instance ${BRANCH} with pid $EXISTPID" 1>&2
			kill -9 $EXISTPID
		else
			echo "eXist instance ${BRANCH} is NOT running!!!" 1>&2
			RETVAL=1
		fi
		;;
	status)
		if [ -n "$EXISTPID" ] ; then
			echo "eXist instance ${BRANCH} is running with pid $EXISTPID" 1>&2
		else
			echo "eXist instance ${BRANCH} is NOT running!!!" 1>&2
		fi
		;;
	compile)
		cd "${EXIST_HOME}"
		svn update
		ant
		;;
	clean)
		cd "${EXIST_HOME}"
		ant clean
		;;
	client)
		if [ -n "$EXISTPID" ] ; then
			echo "eXist instance ${BRANCH} is ALREADY running with pid $EXISTPID" 1>&2
			RETVAL=1
		else
			cp -pf "${EXISTDATACONF_HOME}/conf.xml" "${EXIST_HOME}"
			CLIENT_JAVA_OPTIONS="$JAVA_OPTIONS"
			export CLIENT_JAVA_OPTIONS
			exec bash "${EXIST_HOME}/bin/client.sh" -l
		fi
		;;
	rclient)
		if [ -n "$EXISTPID" ] ; then
			SERVER_PORT=$(grep -o "port=['\"][0-9]\+" "$SERVERXML" | tr \" \' | cut -d \' -f 2)
			CLIENT_JAVA_OPTIONS="$JAVA_OPTIONS"
			export CLIENT_JAVA_OPTIONS
			exec bash "${EXIST_HOME}/bin/client.sh" -N -ouri=xmldb:exist//localhost:${SERVER_PORT}/xmlrpc -u admin
		else
			echo "eXist instance ${BRANCH} is NOT running!!!" 1>&2
			RETVAL=1
		fi
		;;
	*)
		echo "Usage: $0 {start|stop|status|client|rclient|kill9|compile|clean)" 1>&2
		;;
esac

if [ -n "$RETVAL" ] ; then
	exit "$RETVAL"
fi
