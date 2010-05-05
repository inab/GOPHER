(:
	cronjobWrapper.xql
	
	This is the cron job wrapper, which elevates its privileges
	in order to call the true cron job.
:)
xquery version "1.0" encoding "UTF-8";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace system="http://exist-db.org/xquery/system";
import module namespace util="http://exist-db.org/xquery/util";

if(request:exists()) then
	error((),'The cron job wrapper cannot be fired from outside. Quack!')
else (
	util:log-app("info","xcesc.cron","Job started"),
	system:as-user($mgmt:adminUser,$mgmt:adminPass,
		util:catch("*",
			(: Write code here! :)
			util:eval(xs:anyURI('cronjob.xql'))
			,
			util:log-app("error","xcesc.cron",<error>An error occurred on XCESC cron job: {$util:exception-message}.</error>)
		)
	),
	util:log-app("info","xcesc.cron","Job finished")
)