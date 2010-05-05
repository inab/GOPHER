(:
	cronjobAssess.xql
	
	This module can only be run with elevated privileges,
	but it is the caller's task to reach those privileges,
	not ours!
:)
xquery version "1.0" encoding "UTF-8";

import module namespace request="http://exist-db.org/xquery/request";

import module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement" at "xmldb:exist:///db/XCESC-logic/jobManagement.xqm";

(: Network context detection, to avoid external "attacks" :)
if(request:exists()) then
	error((),'The assessment cron job cannot be fired from outside. Quack!')
else (
	job:issueAssessments()
)
