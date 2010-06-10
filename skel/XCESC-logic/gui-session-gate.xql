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

let $path := request:get-path-info()
let $res := if(session:exists()) then (
	let $user-id := session:get-attribute($login:XCESC_USER_ID_KEY)
	return
		if(exists($user-id)) then (
			if($path eq '') then (
				let $logo := util:log-app('error','xcesc.cron',string-join((xmldb:get-current-user(),$user-id,session:get-attribute('user'),session:get-attribute('password'),session:get-attribute-names()),' '))
				return (
					200
					,
					mgmt:getRestrictedInfoFromId($user-id)
				)
			) else if($path eq '/users') then (
				200
				,
				mgmt:getRestrictedUserListFromId($user-id)
			) else (
				400
			)
		) else (
			400
		)
) else if($path eq '/users') then (
	200
	,
	mgmt:user-template()
) else (
	401
)
return
	if(count($res) > 1) then (
		$res[2]
	) else (
		util:declare-option('exist:serialize',"method=text media-type=text/plain process-xsl-pi=no"),
		response:set-status-code($res[1])
	)