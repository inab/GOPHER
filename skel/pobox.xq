xquery version "1.0";

(::pragma exist:output-size-limit -1::)
declare namespace t="http://exist-db.org/xquery/text";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace gopher="http://www.cnio.es/scombio/gopher/1.0";

(: First, get the path info :)
let $pathInfo := request:get-path-info()
let $jobTokens := tokenize(substring($pathInfo,1),'/')
if (count($jobTokens) = 3) then
	
else
	response:set-status-code(404)
