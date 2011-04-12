xquery version "1.0" encoding "UTF-8";

(:~
 : This module does login to the system, if it is allowed (of course :-))
 : @author José María Fernández
 :)

module namespace login="http://www.cnio.es/scombio/xcesc/1.0/xquery/login";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace util="http://exist-db.org/xquery/util";

import module namespace mgmt = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement' at 'xmldb:exist:///db/XCESC-logic/systemManagement.xqm';


declare variable $login:TOKEN_SEP as xs:string := ', ';
declare variable $login:KEYVAL_SEP as xs:string := '=';
declare variable $login:DIGEST_SEP as xs:string := ':';
declare variable $login:NONCE_KEY as xs:string := 'nonce'; 
declare variable $login:REALM_KEY as xs:string := 'realm'; 
declare variable $login:USER_KEY as xs:string := 'user';
declare variable $login:XCESC_USER_ID_KEY as xs:string := 'xcesc-user';
declare variable $login:RESPONSE_KEY as xs:string := 'response';

declare function login:generate-nonce($realm as xs:string,$nonce as xs:string)
	as xs:integer
{
	(: No session, no party :)
	session:invalidate(),
	session:create(),
	session:set-max-inactive-interval(180),
	session:set-attribute($login:NONCE_KEY,$nonce),
	session:set-attribute($login:REALM_KEY,$realm),
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

declare function login:do-login-digest($user as xs:string, $realm as xs:string, $nonce as xs:string)
	as xs:string?
{
	(: We cannot follow if the user is not confirmed or it is disabled :)
	let $pass := mgmt:getActiveUserFromNickname($user)/@nickpass
	return
		if(exists($pass)) then (
			let $HA1 := util:hash(string-join(($user,$realm,$pass/string()),$login:DIGEST_SEP),'md5')
			return
				util:hash(string-join(($nonce,$HA1),$login:DIGEST_SEP),'md5')
		) else (
		)
};
