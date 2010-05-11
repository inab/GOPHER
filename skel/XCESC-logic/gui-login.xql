xquery version "1.0" encoding "UTF-8";

(:~
 : This module does login to the system, if it is allowed (of course :-))
 : @author José María Fernández
 :)

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace login="http://www.cnio.es/scombio/xcesc/1.0/xquery/login";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace mgmt = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement' at 'xmldb:exist:///db/XCESC-logic/systemManagement.xqm';
import module namespace gui = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement' at 'xmldb:exist:///db/XCESC-logic/guiManagement.xqm';


declare variable $login:TOKEN_SEP as xs:string := ',&xD;&xA;';
declare variable $login:KEYVAL_SEP as xs:string := '=';
declare variable $login:DIGEST_SEP as xs:string := ':';
declare variable $login:NONCE_KEY as xs:string := 'nonce'; 
declare variable $login:REALM_KEY as xs:string := 'realm'; 
declare variable $login:USER_KEY as xs:string := 'user';
declare variable $login:RESPONSE_KEY as xs:string := 'response';

declare function login:generate-nonce($realm as xs:string)
	as xs:integer
{
	(: No session, no party :)
	let $nonce := util:uuid()
	return
		session:invalidate(),
		session:create(),
		session:set-atribute($login:NONCE_KEY,$nonce),
		session:set-atribute($login:REALM_KEY,$realm),
		response:set-header('XCESC-auth',
			string-join(
				(
					string-join(($login:NONCE_KEY,$nonce),$login:KEYVAL_SEP)
					,
					string-join(($login:REALM_KEY,$realm),$login:KEYVAL_SEP)
				)
				,
				$login:TOKEN_SEP
			)
		),
		401
};

let $status := if(session:exists()) then (
	let $nonce := session:get-attribute($login:NONCE_KEY)
	let $realm := session:get-attribute($login:REALM_KEY)
	let $auth-header := request:get-header('XCESC-login')
	return if(empty($nonce) or not(contains($auth-header,$login:KEYVAL_SEP))) then (
		(: No nonce, no party and no previous session :)
		login:generate-nonce($gui:realm)
	) else (
		let $emp1:=session:invalidate()
		let $keyvals := ( 
			for $auth-token in tokenize($auth-header,$login:KEYVAL_SEP)
			let $keyval := tokenize($auth-token,$login:KEYVAL_SEP)
			return
				if(count($keyval)>=2) then (
					<pair key='{$keyval[1]}' val='{subsequence($keyval,2)}' />
				) else
					()
		)
		let $incoming-user := $keyvals[@key eq $login:USER_KEY]/@val/string()
		let $incoming-realm := $keyvals[@key eq $login:REALM_KEY]/@val/string()
		let $incoming-nonce := $keyvals[@key eq $login:NONCE_KEY]/@val/string()
		let $incoming-response := $keyvals[@key eq $login:RESPONSE_KEY]/@val/string()
		return
			if(empty($incoming-user) or empty($incoming-realm) or empty($incoming-nonce) or empty($incoming-response)) then (
				(: Not enough parameters :)
				400
			) else (
				if($realm ne $incoming-realm or $nonce ne $incoming-nonce) then (
					(: Invalid parameters :)
					403
				) else (
					let $generated-response := mgmt:do-login-digest($incoming-user,$incoming-realm,$incoming-nonce)
					return
						if(exists($generated-response) and $generated-response eq $incoming-response) then (
							session:create(),
							session:set-attribute($login:USER_KEY,mgmt:getUserIdFromNickname($incoming-user)),
							session:set-current-user($incoming-user,mgmt:getPasswordFromNickname($incoming-user)),
							200
						) else (
							403
						)
				)
			)
	)
) else (
	login:generate-nonce($gui:realm)
)
return
	response:set-status-code($status)