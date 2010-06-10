xquery version "1.0" encoding "UTF-8";

(:~
 : This module does login to the system, if it is allowed (of course :-))
 : @author José María Fernández
 :)

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace system="http://exist-db.org/xquery/system";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace mgmt = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement' at 'xmldb:exist:///db/XCESC-logic/systemManagement.xqm';
import module namespace login = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/login' at 'xmldb:exist:///db/XCESC-logic/gui-login.xqm';
import module namespace gui = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement' at 'xmldb:exist:///db/XCESC-logic/guiManagement.xqm';

let $status := if(session:exists()) then (
	if(not(request:get-parameter('doLogout','false') = 'true')) then (
		let $nonce := session:get-attribute($login:NONCE_KEY)
		let $realm := session:get-attribute($login:REALM_KEY)
		let $auth-header := request:get-header('XCESC-login')
		return if(empty($nonce) or not(contains($auth-header,$login:TOKEN_SEP))) then (
			(: No nonce, no party and no previous session :)
			login:generate-nonce($gui:realm,util:uuid())
		) else (
			let $emp1:=session:invalidate()
			let $keyvals := ( 
				for $auth-token in tokenize($auth-header,$login:TOKEN_SEP)
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
						system:as-user($mgmt:adminUser,$mgmt:adminPass,
							let $generated-response := login:do-login-digest($incoming-user,$incoming-realm,$incoming-nonce)
							return
								if(exists($generated-response) and $generated-response eq $incoming-response) then (
									let $auth-tokens := mgmt:getAuthTokensForSessionFromNickname($incoming-user)
									let $jarl := (
										session:create(),
										session:set-attribute($login:XCESC_USER_ID_KEY,mgmt:getUserIdFromNickname($incoming-user)),
										if(session:set-current-user($incoming-user,$auth-tokens[3])) then (
											xmldb:login('/db',$auth-tokens[1],$auth-tokens[2])
										) else
											( )
									)
									return
										200
								) else (
									403
								)
						)
					)
				)
		)
	) else (
		session:invalidate()
		,
		200
	)
) else (
	login:generate-nonce($gui:realm,util:uuid())
)
let $dum2 := util:declare-option('exist:serialize',"method=text media-type=text/plain process-xsl-pi=no")
return
	response:set-status-code($status)