#!/bin/sh

ant \
'-Ddeploy.host=localhost' \
'-Ddeploy.home.dir=/tmp' \
'-Ddeploy.ssh.user=jmfernandez' \
'-Ddeploy.eXist.port=8088' \
'-Ddeploy.eXist.basebranch=' \
'-Ddeploy.eXist.data.dir.rel=webapp/WEB-INF/data' \
'-Ddeploy.eXist.data.dir.conf.xml=\${deploy.eXist.data.dir.rel}' \
'-Ddeploy.eXist.data.dir=\${deploy.eXist.dir}/\${deploy.eXist.data.dir.rel}' \
'-Ddeploy.eXist.startup.confdir=\$EXIST_HOME' \
'-Ddeploy.eXist.startup.datadir=\$EXIST_HOME/\${deploy.eXist.data.dir.rel}' \
deploy.skel.meta

ant \
'-Ddeploy.host=localhost' \
'-Ddeploy.home.dir=/tmp' \
'-Ddeploy.ssh.user=jmfernandez' \
'-Ddeploy.eXist.port=8088' \
'-Ddeploy.eXist.basebranch=' \
'-Ddeploy.eXist.data.dir.rel=webapp/WEB-INF/data' \
'-Ddeploy.eXist.data.dir.conf.xml=\${deploy.eXist.data.dir.rel}' \
'-Ddeploy.eXist.data.dir=\${deploy.eXist.dir}/\${deploy.eXist.data.dir.rel}' \
'-Ddeploy.eXist.startup.confdir=\$EXIST_HOME' \
'-Ddeploy.eXist.startup.datadir=\$EXIST_HOME/\${deploy.eXist.data.dir.rel}' \
deploy