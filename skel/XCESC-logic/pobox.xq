xquery version "1.0" encoding "UTF-8";

(::pragma exist:output-size-limit -1::)
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace session="http://exist-db.org/xquery/session";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement" at "xmldb:exist:///db/XCESC-logic/jobManagement.xqm";

(: First, get the path info :)
let $pathInfo := request:get-path-info()
let $jobTokens := tokenize(substring($pathInfo,1),'/')
return
	if (count($jobTokens) >= 2) then (
		system:as-user($mgmt:adminUser,$mgmt:adminPass,
			util:catch("*",
				(: Write code here! :)
				response:set-status-code(job:joinResults($jobTokens[0],$jobTokens[1],current-dateTime(),request:get-data()))
				, 
				let $emp1 := util:log-app("error","xcesc.cron",<error>An error occurred meanwhile processing the predictions from ({$jobTokens[0]}, {$jobTokens[1]}) job: {$util:exception-message}.</error>)
				return
					response:set-status-code(500)
			)
		)
	) else
		response:set-status-code(400)
