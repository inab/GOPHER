#!/bin/bash

# Safety, the first
LC_ALL=C
LANG=C
export LC_ALL LANG

BRANCH="@branch@"
BASEBRANCHES="@basedir@"
EXIST_PORT="@port@"
EXIST_HOME="${BASEBRANCHES}/eXist${BRANCH}"
EXISTDATACONF_HOME="${BASEBRANCHES}/dataconf${BRANCH}"
EXIST_DATADIR="@datadir@"
EXIST_CONFDIR="@confdir@"
EXIST_LOGSDIR="@logsdir@"
SERVERXML="${EXIST_CONFDIR}/server.xml"
SERVERXMLNOREWRITE="${EXIST_CONFDIR}/server.xml.norewrite"
export EXIST_HOME EXISTCONF_HOME

if [ $# = 0 ] ; then
	status=start
else
	status="$1"
fi

JAVA_OPTIONS="-Xmx768m -Xms384m -Dfile.encoding=UTF-8 -Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl"

# Deciding the configuration file to use
case "$status" in
	startnw)
		# JAVA_OPTIONS="$JAVA_OPTIONS -Dserver.xml=${SERVERXMLNOREWRITE}"
		JAVA_OPTIONS="$JAVA_OPTIONS -Djetty.port=${EXIST_PORT} -Djetty.home=${EXIST_CONFDIR}"
		;;
	*)
		# JAVA_OPTIONS="$JAVA_OPTIONS -Dserver.xml=${SERVERXML}"
		JAVA_OPTIONS="$JAVA_OPTIONS -Djetty.port=${EXIST_PORT} -Djetty.home=${EXIST_CONFDIR}"
		;;
esac
# Setting the logs dir through a property
JAVA_OPTIONS="$JAVA_OPTIONS -Dexist.logsdir=${EXIST_LOGSDIR}"
export JAVA_OPTIONS

# And the JVM to use
if [ -d "${HOME}/ibm-java-i386-60" ] ; then
	JAVA_HOME="${HOME}/ibm-java-i386-60"
	#JAVA_HOME=/usr/lib/jvm/java-6-sun
	export JAVA_HOME
else
	if [ -z "${JAVA_HOME}" ] ; then
		if [ -f /usr/bin/java-config ] ; then
			JAVA_HOME="$(/usr/bin/java-config -O)"
		else
			echo "Unable to start eXist with JAVA_HOME variable unset" 1>&2
			exit 1
		fi
	fi
fi

# Exist by-passes Java CLASSPATH
# so, let's follow their role.
#ln -sf "${JAVALIBDIRS}"/*.jar "${EXIST_HOME}/lib/user"

#cp "${VAPORDIRS}"/mime-types.xml "${EXIST_HOME}"

# EXISTPID=$(pgrep -f "exist.home=${EXIST_HOME} ")
EXISTPID=$(ps aux|grep -F "exist.home=${EXIST_HOME} " | grep -vF grep | tr -s ' ' ' '| cut -f 2 -d ' ')
case "$status" in
	start|startnw)
		if [ -n "$EXISTPID" ] ; then
			echo "eXist instance ${BRANCH} is ALREADY running with pid $EXISTPID" 1>&2
			RETVAL=1
		else
			# If data dir is outside eXist, perhaps we have to create the directory just before first startup.
			mkdir -p "$EXIST_DATADIR"
			# and the same happens with logs
			mkdir -p "$EXIST_LOGSDIR"

			if [ "${EXIST_CONFDIR}" != "${EXIST_HOME}" ] ; then
				cp -pf "${EXIST_CONFDIR}/conf.xml" "${EXIST_CONFDIR}/atom-services.xml" "${EXIST_HOME}"
				if [ -f "${EXIST_CONFDIR}/log4j.xml" ] ; then
					cp -pf "${EXIST_CONFDIR}/log4j.xml" "${EXIST_HOME}"
				fi
			fi
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
			if [ "${EXIST_CONFDIR}" != "${EXIST_HOME}" ] ; then
				cp -pf "${EXIST_CONFDIR}/conf.xml" "${EXIST_CONFDIR}/atom-services.xml" "${EXIST_HOME}"
			fi
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
