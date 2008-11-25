(:
	cronjob.xql
:)
xquery version "1.0";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace system="http://exist-db.org/xquery/system";

import module namespace gmod="http://www.cnio.es/scombio/gopher/1.0/javaModule" at "java:org.cnio.scombio.jmfernandez.GOPHER.GOPHERModule";
import module namespace job="http://www.cnio.es/scombio/gopher/1.0/xquery/jobManagement" at "jobManagement.xqm";

(: Network context detection, to avoid external "attacks" :)
if(request:exists()) then
	error((),'The cron job cannot be fired from outside. Quack!')
else (
	(: Write code here! :)
	system:as-user('admin','',util:function(xs:QName('job:doNextRound'),0))
	job:doNextRound()
)