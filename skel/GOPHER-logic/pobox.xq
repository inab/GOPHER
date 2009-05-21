xquery version "1.0";

(::pragma exist:output-size-limit -1::)
declare namespace t="http://exist-db.org/xquery/text";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace request="http://exist-db.org/xquery/request";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement" at "xmldb:exist:///db/XCESC-logic/jobManagement.xqm";

(: First, get the path info :)
let $pathInfo := request:get-path-info()
let $jobTokens := tokenize(substring($pathInfo,1),'/')
if (count($jobTokens) >= 2 and request:set-current-user($mgmt:adminUser,$mgmt:adminPass)) then
	response:set-status-code(job:joinResults($jobTokens[0],$jobTokens[1],request:get-data())),
	request:invalidate-session()
else
	response:set-status-code(404)
