#!/bin/bash
# $Id: build.sh 12387 2010-08-11 16:47:14Z deliriumsky $

if [ "$JAVA_HOME" = "" ] ; then
  echo "ERROR: JAVA_HOME not found in your environment."
  echo
  echo "Please, set the JAVA_HOME variable in your environment to match the"
  echo "location of the Java Virtual Machine you want to use."
  exit 1
fi

if [ ! -d "$JAVA_HOME" ]; then
    JAVA_HOME="%{JAVA_HOME}"
fi

if [ -z "$XCESC_HOME" ]; then
    P="$(dirname "$0")"

    if test "$P" = "." 
    then
        EXIST_HOME="$(pwd)"
    else
        EXIST_HOME="$P"
    fi
fi

ANT_HOME="$XCESC_HOME/tools-ant"

#LOCALCLASSPATH="$ANT_HOME/lib/ant-launcher.jar:$EXIST_HOME/lib/user/svnkit.jar:$EXIST_HOME/lib/user/svnkit-cli.jar"
LOCALCLASSPATH="$ANT_HOME/lib/ant-launcher.jar"

JAVA_ENDORSED_DIRS="$XCESC_HOME"/tools-endorsed

# You must set
# -Djavax.xml.transform.TransformerFactory=org.apache.xalan.processor.TransformerFactoryImpl
# Otherwise Ant will fail to do junitreport with Saxon, as it has a direct dependency on Xalan.
JAVA_OPTS=( "-Dant.home=$ANT_HOME" "-Dant.library.dir=$ANT_HOME/lib" "-Djava.endorsed.dirs=$JAVA_ENDORSED_DIRS" "-Djavax.xml.transform.TransformerFactory=org.apache.xalan.processor.TransformerFactoryImpl" )

echo Starting Ant...
echo

exec "$JAVA_HOME"/bin/java -Xms512m -Xmx512m "${JAVA_OPTS[@]}" -classpath "$LOCALCLASSPATH" org.apache.tools.ant.launch.Launcher "$@"