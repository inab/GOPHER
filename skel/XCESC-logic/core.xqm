(:
	core.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace core = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/core';

declare namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Bootstraping the configuration collection, based on systemManagement configuration location :)
(:
declare variable $core:managementRoot := collection("/db")//mgmt:systemManagement[1];
:)
declare variable $core:managementRoot := subsequence(collection("/db")//mgmt:systemManagement,1,1);
declare variable $core:configCol as xs:string := util:collection-name($core:managementRoot);
declare variable $core:configColURI as xs:string := xmldb:encode($core:configCol);
declare variable $core:relLogicCol as xs:string := $core:managementRoot/@publicLogicRelURI/string();


