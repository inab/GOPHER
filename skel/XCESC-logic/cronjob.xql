(:
	cronjob.xql
:)
xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace system="http://exist-db.org/xquery/system";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement" at "xmldb:exist:///db/XCESC-logic/jobManagement.xqm";

(: Network context detection, to avoid external "attacks" :)
if(request:exists()) then
	error((),'The cron job cannot be fired from outside. Quack!')
else (
	(: Write code here! :)
	system:as-user($mgmt:adminUser,$mgmt:adminPass,util:function(xs:QName('job:doNextRound'),0))
)
