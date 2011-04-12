xquery version "1.0" encoding "UTF-8";

(:~
 : This module sends information about current user session.
 : @author José María Fernández
 :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace mgmt = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement' at 'xmldb:exist:///db/XCESC-logic/systemManagement.xqm';
import module namespace login = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/login' at 'xmldb:exist:///db/XCESC-logic/gui-login.xqm';

declare variable $TEMPLATE_POSTFIX as xs:string := '-template';
declare variable $SERVERS_PATH_KEY as xs:string := '/servers';
declare variable $SERVERS_TEMPLATE_PATH_KEY as xs:string := concat($SERVERS_PATH_KEY,$TEMPLATE_POSTFIX);
declare variable $USERS_PATH_KEY as xs:string := '/users';
declare variable $USERS_TEMPLATE_PATH_KEY as xs:string := concat($USERS_PATH_KEY,$TEMPLATE_POSTFIX);

let $path := request:get-path-info()
let $user-id := session:get-attribute($login:XCESC_USER_ID_KEY)
let $res := if($path eq $SERVERS_TEMPLATE_PATH_KEY) then (
	200
	,
	mgmt:servers-template()
) else if($path eq $USERS_TEMPLATE_PATH_KEY) then (
	200
	,
	mgmt:user-template()
) else if(session:exists() and exists($user-id)) then (
	if($path eq '') then (
		let $logo := util:log-app('error','xcesc.cron',string-join((xmldb:get-current-user(),$user-id,session:get-attribute('user'),session:get-attribute('password'),session:get-attribute-names()),' '))
		return (
			200
			,
			mgmt:getRestrictedInfoFromId($user-id)
		)
	) else if($path eq $USERS_PATH_KEY) then (
		200
		,
		mgmt:getRestrictedUserListFromId($user-id)
	) else if($path eq $SERVERS_PATH_KEY) then (
		200
		,
		mgmt:getRestrictedServerListFromId($user-id)
	) else (
		400
	)
) else if($path eq $USERS_PATH_KEY) then (
	200
	,
	mgmt:empty-user-template()
) else if($path eq $SERVERS_PATH_KEY) then (
	200
	,
	mgmt:empty-servers-template()
) else (
	401
)
return (
	response:set-header('Cache-Control','no-store, must-revalidate')
	,
	if(count($res) > 1) then (
		$res[2]
	) else (
		util:declare-option('exist:serialize',"method=text media-type=text/plain process-xsl-pi=no"),
		response:set-status-code($res[1])
	)
)