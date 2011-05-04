(:
	systemManagement.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement";

declare namespace meta="http://www.cnio.es/scombio/xcesc/1.0/xquery/metaManagement";
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace core = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/core' at 'xmldb:exist:///db/XCESC-logic/core.xqm';
import module namespace mailcore = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/mailCore' at 'xmldb:exist:///db/XCESC-logic/mailCore.xqm';

import module namespace upd = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/XQueryUpdatePrimitives' at 'xmldb:exist:///db/XCESC-logic/XQueryUpdatePrimitives.xqm';

(:
declare variable $mgmt:configRoot as element(mgmt:systemManagement) := collection($core:configColURI)//mgmt:systemManagement[1];
:)
declare variable $mgmt:configRoot as element(mgmt:systemManagement) := subsequence(collection($core:configColURI)//mgmt:systemManagement,1,1);

declare variable $mgmt:partServer as xs:string := 'participant';
declare variable $mgmt:evalServer as xs:string := 'evaluator';

declare variable $mgmt:projectName as xs:string := $mgmt:configRoot/@projectName/string();

(:
declare variable $mgmt:adminUser as xs:string := $mgmt:configRoot/mgmt:admin[1]/@user/string();
declare variable $mgmt:adminPass as xs:string := $mgmt:configRoot/mgmt:admin[1]/@password/string();
declare variable $mgmt:adminMail as xs:string := $mgmt:configRoot/mgmt:admin[1]/@mail/string();
:)
declare variable $mgmt:adminUser as xs:string := subsequence($mgmt:configRoot/mgmt:admin,1,1)/@user/string();
declare variable $mgmt:adminPass as xs:string := subsequence($mgmt:configRoot/mgmt:admin,1,1)/@password/string();
declare variable $mgmt:adminMail as xs:string := subsequence($mgmt:configRoot/mgmt:admin,1,1)/@mail/string();

declare variable $mgmt:roles as element(mgmt:role)+ := $mgmt:configRoot/mgmt:availableRoles/mgmt:role;

declare variable $mgmt:xcescGroup as xs:string := $mgmt:configRoot/@group/string();

declare variable $mgmt:mgmtCol as xs:string := $mgmt:configRoot/@collection/string();
declare variable $mgmt:mgmtColURI as xs:string := xmldb:encode($mgmt:mgmtCol);
declare variable $mgmt:mgmtDoc as xs:string := $mgmt:configRoot/@managementDoc/string();
declare variable $mgmt:mgmtDocURI as xs:string := xmldb:encode($mgmt:mgmtDoc);

declare variable $mgmt:publicServerPort as xs:string := $mgmt:configRoot/@publicServerPort/string();
declare variable $mgmt:publicBasePath as xs:string := $mgmt:configRoot/@publicBasePath/string();
declare variable $mgmt:publicBaseURI as xs:string := concat(
	if($mgmt:publicServerPort eq '443') then 'https' else 'http',
	'://',
	$mgmt:configRoot/@publicServerName/string(),
	if($mgmt:publicServerPort ne '80' and $mgmt:publicServerPort ne '443') then concat(':',$mgmt:publicServerPort) else '',
	$mgmt:publicBasePath
	);

declare variable $mgmt:mgmtDocPath as xs:string := string-join(($mgmt:mgmtCol,$mgmt:mgmtDoc),'/');
declare variable $mgmt:mgmtDocPathURI as xs:string := xmldb:encode($mgmt:mgmtDocPath);

declare variable $mgmt:CONFIRM_YES_KEY as xs:string := 'yes';
declare variable $mgmt:CONFIRM_NO_KEY as xs:string := 'no';
declare variable $mgmt:CONFIRM_YESNO_KEY as xs:string := 'confirm';
declare variable $mgmt:CONFIRM_OLDOWNER_KEY as xs:string := 'oldOwner';
declare variable $mgmt:CONFIRM_NEWOWNER_KEY as xs:string := 'newOwner';
declare variable $mgmt:CONFIRM_SERVERID_KEY as xs:string := 'serverId';
declare variable $mgmt:CONFIRM_ID_KEY as xs:string := 'id';
declare variable $mgmt:CONFIRM_MAILID_KEY as xs:string := 'emailId';

declare variable $mgmt:confirmModule as xs:string := 'confirm.xql';
declare variable $mgmt:confirmModuleURI as xs:string := string-join(($mgmt:publicBaseURI,$core:relLogicCol,$mgmt:confirmModule),'/');

(:::::::::::::::::::::::)
(: Management Document :)
(:::::::::::::::::::::::)

declare function mgmt:getManagementDoc0()
	as element(xcesc:managementData)
{
	if(doc-available($mgmt:mgmtDocPathURI)) then (
		doc($mgmt:mgmtDocPathURI)/element()
	) else (
		let $newDoc := <xcesc:managementData><xcesc:users/><xcesc:servers/></xcesc:managementData>
		let $mgmtColURI := xmldb:encode($mgmt:mgmtCol)
		let $dummy := xmldb:create-collection("/",$mgmtColURI)
		let $retElem := doc(xmldb:store($mgmtColURI,$mgmt:mgmtDocURI,$newDoc,'application/xml'))/element()
		(: Only the owner can look at/change this file, and group people can only look at :)
		let $empty := xmldb:set-resource-permissions($mgmt:mgmtColURI,$mgmt:mgmtDocURI,$mgmt:adminUser,$mgmt:xcescGroup,7*64+4*8)
		return $retElem
	)
};

declare function mgmt:createUser($nickname as xs:string,$nickpass as xs:string,$firstName as xs:string,$lastName as xs:string,$organization as xs:string,$eMails as element(xcesc:eMail)+, $references as element(xcesc:reference)*, $roles as element(xcesc:role)*)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc := mgmt:getManagementDoc0()
		return
			if(empty($mgmtDoc//xcesc:user[@nickname eq $nickname]) and ($nickname eq $mgmt:adminUser or not(xmldb:exists-user($nickname)))) then (
				let $id:=util:uuid()
				(: Perhaps in the future we will add bloggers group... :)
				let $status := if($nickname ne $mgmt:adminUser) then ( "unconfirmed" ) else ( "enabled" )
				let $password := if($nickname ne $mgmt:adminUser) then ( $nickpass ) else ( $mgmt:adminPass )
				let $newUser:=<xcesc:user id="{$id}" nickname="{$nickname}" nickpass="{$password}" firstName="{$firstName}" lastName="{$lastName}" organization="{$organization}" status="{$status}">
					{
						(: eMail curation, because at the beginning they are unconfirmed by default :)
						for $eMail in $eMails
						let $eMailId := util:uuid()
						return
							<xcesc:eMail id="{$eMailId}" status="{$status}">{$eMail/text()}</xcesc:eMail>
					}
					<xcesc:references>{$references}</xcesc:references>
					<xcesc:roles>{
						if($nickname eq $mgmt:adminUser) then (
							for $role in $mgmt:roles[@isSuperUser eq 'true']
							return
								<xcesc:role name="{$role/@name}"/>
						) else
							()
						,
						$roles
					}</xcesc:roles>
				</xcesc:user>
				return (
					upd:insertInto($mgmtDoc//xcesc:users,$newUser),
					if($status eq 'unconfirmed') then (
						mailcore:send-email(<mail>
							<to>{$mgmt:adminMail}</to>
							<subject>{$mgmt:projectName} User Registration request</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} User Registration request for '{$nickname}'</head>
										<body>
											<p>Received user registration request</p>
											<ul>
												<li><b>User:</b> {$nickname}</li>
												<li><b>First name:</b> {$firstName}</li>
												<li><b>Last name:</b> {$lastName}</li>
												<li><b>Organization:</b> {$organization}</li>
												<li><b>E-mail(s):</b> {string-join($eMails/text(),', ')}</li>
												<li><b>Reference(s):</b><ul>{
													for $reference in $references
													return
														<li><a href="{$reference/text()}">{$reference/@description/string()}</a> ({$reference/@kind/string()})</li>
												}</ul></li>
											</ul>
											<div align="center">
												<a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_ID_KEY}={$id}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_YES_KEY}">Approve new user {$nickname}</a> <b>or</b>
												<a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_ID_KEY}={$id}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_NO_KEY}">Reject new user {$nickname}</a>?
											</div>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>)
					) else
						()
					,
					$id
				)
			) else (
				util:log-system-err(string-join(("On user creation, user",$nickname,"already existed"),' ')),
				error((),string-join(("On user creation, user",$nickname,"already existed"),' '))
			)
	(: } :)
};

declare function mgmt:getManagementDoc()
	as element(xcesc:managementData)
{
	let $mgmtDoc := mgmt:getManagementDoc0()
	return
		if($mgmtDoc//xcesc:user[@nickname eq $mgmt:adminUser]) then (
			$mgmtDoc
		) else (
			let $dumb := mgmt:createUser($mgmt:adminUser,$mgmt:adminPass,concat($mgmt:projectName,' root admin'),'','',<xcesc:eMail>{$mgmt:adminMail}</xcesc:eMail>,(),())
			return
				$mgmtDoc
		)
};

(: It obtains the whole user configuration, by id :)
declare function mgmt:getUserFromId($id as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@id eq $id]
};

declare function mgmt:getActiveUserFromId($id as xs:string)
	as element(xcesc:user)?
{
	mgmt:getUserFromId($id)[@status eq 'enabled']
};

declare function mgmt:is-super-user($rulerDoc as element(xcesc:user))
	as xs:boolean
{
	exists($mgmt:roles[@isSuperUser eq 'true'][@name = $rulerDoc//xcesc:role[not(@isDenied)]/@name])
};

declare function mgmt:is-super-user($id as xs:string)
	as xs:boolean
{
	let $rulerDoc := mgmt:getActiveUserFromId($id)
	return
		if (exists($rulerDoc)) then (
			mgmt:is-super-user($rulerDoc)
		) else (
			false()
		)
};

declare function mgmt:has-user-role($rulerDoc as element(xcesc:user), $role as xs:string, $userDoc as element(xcesc:user))
	as xs:boolean
{
	if(mgmt:is-super-user($rulerDoc) or $userDoc/@id eq $rulerDoc/@id or $rulerDoc//xcesc:role[@name eq $role][not(@isDenied)]) then (
		true()
	) else (
		false()
	)
};

declare function mgmt:has-user-server-role($rulerDoc as element(xcesc:user), $role as xs:string, $userDoc as element(xcesc:server))
	as xs:boolean
{
	if(mgmt:is-super-user($rulerDoc) or $serverDoc/@managerId eq $rulerDoc/@id or $rulerDoc//xcesc:role[@name eq $role][not(@isDenied)]) then (
		true()
	) else (
		false()
	)
};

declare function mgmt:has-user-id-role($id as xs:string, $role as xs:string, $userDoc as element(xcesc:user))
	as xs:boolean
{
	let $rulerDoc := mgmt:getActiveUserFromId($id)
	return
		if(exists($rulerDoc)) then (
			mgmt:has-user-role($rulerDoc,$role,$userDoc)
		) else (
			false()
		)
};

declare function mgmt:has-user-id-server-role($id as xs:string, $role as xs:string, $serverDoc as element(xcesc:server))
	as xs:boolean
{
	let $rulerDoc := mgmt:getActiveUserFromId($id)
	return
		if(exists($rulerDoc)) then (
			mgmt:has-user-server-role($rulerDoc,$role,$serverDoc)
		) else (
			false()
		)
};

declare function mgmt:has-nickname-role($nickname as xs:string, $role as xs:string, $userDoc as element(xcesc:user))
	as xs:boolean
{
	let $rulerDoc := mgmt:getActiveUserFromNickname($nickname)
	return
		if(exists($rulerDoc)) then (
			mgmt:has-user-role($rulerDoc,$role,$userDoc)
		) else (
			false()
		)
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@nickname eq $nickname]
};

declare function mgmt:getUserIdFromNickname($nickname as xs:string)
	as xs:string?
{
	mgmt:getUserFromNickname($nickname)/@id/string()
};

declare function mgmt:getPasswordFromNickname($nickname as xs:string)
	as xs:string?
{
	mgmt:getUserFromNickname($nickname)/@nickpass/string()
};

declare function mgmt:getAuthTokensForSessionFromNickname($nickname as xs:string)
	as xs:string+
{
	let $userDoc := mgmt:getUserFromNickname($nickname)
	return
		if(mgmt:is-super-user($userDoc)) then (
			$mgmt:adminUser , $mgmt:adminPass , $userDoc/@nickpass/string()
		) else (
			$userDoc/@nickname/string() , $userDoc/@nickpass/string() , $userDoc/@nickpass/string()
		)
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getActiveUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getUserFromNickname($nickname)[@status eq 'enabled']
};

(:::::::::::)
(: Servers :)
(:::::::::::)

(: It requests changes on server's ownership :)
declare function mgmt:requestChangeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string)
	as empty-sequence()
{
	(: (# exist:batch-transaction #) { :)
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getActiveUserFromId($newOwnerId)
	let $oldUserDoc:=mgmt:getActiveUserFromId($oldOwnerId)
	return
		if($newOwnerId ne '' and empty($userDoc)) then
			error( () ,string-join( ("On server ownership change, user",$newOwnerId,"was not available"),' '))
		else (
			let $serverDoc := $mgmtDoc//xcesc:server[@id eq $serverId][@managerId eq $oldOwnerId]
			return
				if(empty($serverDoc)) then
					error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else (
					upd:replaceValue($serverDoc/@futureManagerId,$newOwnerId)
					,
					if(exists($userDoc)) then (
						mgmt:send-mail-to-user($newOwnerId,<mail>
							<subject>{$mgmt:projectName} confirmation: server ownership change</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} confirmation: server '{$serverDoc/@name/string()}' ownership change</head>
										<body>
											<p>{$oldUserDoc/@firstName/string()} {$oldUserDoc/@lastName/string()} ({$oldUserDoc/@nickname/string()}), the owner of the server '{$serverDoc/@name}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> affirms you want to accept the server's ownership.</p>
											<p>
												Do you <a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_OLDOWNER_KEY}={$oldOwnerId}&amp;{$mgmt:CONFIRM_SERVERID_KEY}={$serverId}&amp;{$mgmt:CONFIRM_NEWOWNER_KEY}={$newOwnerId}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_YES_KEY}">agree</a> with the ownership change
												or you <a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_OLDOWNER_KEY}={$oldOwnerId}&amp;{$mgmt:CONFIRM_SERVERID_KEY}={$serverId}&amp;{$mgmt:CONFIRM_NEWOWNER_KEY}={$newOwnerId}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_NO_KEY}">reject</a> it?
											</p>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>)
					) else
						()
				)
		)
	(: } :)
};

declare function mgmt:changeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string)
	as empty-sequence()
{
	mgmt:changeServerOwnership($oldOwnerId,$serverId,$newOwnerId,true())
};

declare function mgmt:changeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string,$answer as xs:boolean)
	as empty-sequence()
{
	(: (# exist:batch-transaction #) { :)
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getActiveUserFromId($newOwnerId)
	return
		if(empty($userDoc)) then (
			error((),string-join(("On server ownership change, user",$newOwnerId,"was not available"),' '))
		) else (
			let $serverDoc := $mgmtDoc//xcesc:server[@id eq $serverId][@managerId eq $oldOwnerId][@futureManagerId eq $newOwnerId]
			return
				if(empty($serverDoc)) then
					error( () , string-join( ("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' ') )
				else (
					upd:replaceValue($serverDoc/@futureManagerId,'')
					,
					if($answer) then (
						upd:replaceValue($serverDoc/@managerId,$newOwnerId)
						,
						mgmt:send-mail-to-user($oldOwnerId,<mail>
							<subject>{$mgmt:projectName} notification: server ownership changed</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} notification: server '{$serverDoc/@name/string()}' ownership changed</head>
										<body>
											<p>{$userDoc/@firstName/string()} {$userDoc/@lastName/string()} ({$userDoc/@nickname/string()}), hass accepted the ownership of the server '{$serverDoc/@name/string()}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
											<p>You are no more the owner.</p>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>)
					) else (
						mgmt:send-mail-to-user($oldOwnerId,<mail>
							<subject>{$mgmt:projectName} notification: server ownership rejection</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} notification: server '{$serverDoc/@name/string()}' ownership rejection</head>
										<body>
											<p>{$userDoc/@firstName/string()} {$userDoc/@lastName/string()} ({$userDoc/@nickname/string()}), has rejected the ownership of the server '{$serverDoc/@name/string()}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
											<p>You are still the owner.</p>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>)
					)
				)
		)
	(: } :)
};

(:~
 : It creates a server
 :	@author José María Fernández
 :)
declare function mgmt:createServer($serverConfig as element(xcesc:server))
	as xs:string?
{
	(mgmt:createServer($serverConfig/@name,$serverConfig/@managerId,$serverConfig/@uri,$serverConfig/@type eq $mgmt:partServer,$serverConfig/xcesc:description/text(),$serverConfig/xcesc:kind/text(),$serverConfig/xcesc:otherParams/xcesc:param,$serverConfig/xcesc:references/xcesc:reference))
};

(: And programmatically :)
(: Only enabled users can create servers :)
declare function mgmt:createServer($name as xs:string,$managerId as xs:string,$uri as xs:anyURI,$isParticipant as xs:boolean,$description as xs:string?,$domains as xs:string+,$params as element(xcesc:param)+,$references as element(xcesc:reference)*)
	as xs:string? 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if($mgmtDoc//xcesc:user[@id eq $managerId][@status eq 'enabled']) then
				let $id:=util:uuid()
				let $newServer:=<xcesc:server id="{$id}" name="{$name}" managerId="{$managerId}" futureManagerId="" uri="{$uri}" type="{if($isParticipant) then $mgmt:partServer else $mgmt:evalServer}">
					<xcesc:description><![CDATA[{$description}]]></xcesc:description>
					{
						for $domain in $domains
						return
							<xcesc:kind>{$domain}</xcesc:kind>
					}
					<xcesc:otherParams>{$params}</xcesc:otherParams>
					<xcesc:references>{$references}</xcesc:references>
				</xcesc:server>
				return (
					upd:insertInto($mgmtDoc//xcesc:servers,$newServer),
					mgmt:send-mail-to-user($managerId,<mail>
						<subject>{$mgmt:projectName} notification: server registered</subject>
						<message>
							<xhtml>
								<html>
									<head>{$mgmt:projectName} notification: server '{$newServer/@name/string()}' has been registered</head>
									<body>
										<p>The server '{$newServer/@name/string()}' is registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
										<p>You are now the owner.</p>
									</body>
								</html>
							</xhtml>
						</message>
					</mail>)
					,
					$id
				)
			else
				error((),string-join(("On server creation, user",$managerId,"is unknown"),' '))
	(: } :)
};

(: It deletes a server :)
declare function mgmt:deleteServer($managerId as xs:string,$id as xs:string)
	as empty-sequence() 
{
	(: (# exist:batch-transaction #) { :)
		let $serverDoc := mgmt:getManagementDoc()//xcesc:server[@id eq $id][@managerId eq $managerId]
		return
			if(empty($serverDoc)) then
				error((),string-join(("On server deletion, server",$id,"owned by",$managerId,"is unknown"),' '))
			else
				upd:delete($serverDoc)
	(: } :)
};

(: It returns the set of available participant and evaluation online servers :)
declare function mgmt:getOnlineServers()
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
	mgmt:getOnlineParticipants(current-dateTime())
	(: } :)
};

(: It returns the set of available online servers from a kind :)
declare function mgmt:getOnlineServers($serverType as xs:string)
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
		let $currentDateTime:=current-dateTime()
		return mgmt:getOnlineServers($currentDateTime,$serverType)
	(: } :)
};

(: It returns the set of available participant online servers at a specified date :)
declare function mgmt:getOnlineParticipants($currentDateTime as xs:dateTime)
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
	mgmt:getOnlineServers($currentDateTime,$mgmt:partServer)
	(: } :)
};

(: It returns the set of available participant online servers at a specified date :)
declare function mgmt:getOnlineEvaluators($currentDateTime as xs:dateTime)
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
	mgmt:getOnlineServers($currentDateTime,$mgmt:evalServer)
	(: } :)
};

(: It returns the set of available online servers of a any type :)
declare function mgmt:getOnlineServers($currentDateTime as xs:dateTime)
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		return $mgmtDoc//xcesc:server[@id eq $mgmtDoc//xcesc:user[@status eq 'enabled']/@id][empty(xcesc:downTime[xs:dateTime(@since)<=$currentDateTime][empty(@until) or xs:dateTime(@until)>$currentDateTime])]
	(: } :)
};

(: It returns the set of available online servers of a matching type :)
declare function mgmt:getOnlineServers($currentDateTime as xs:dateTime,$serverType as xs:string)
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		return $mgmtDoc//xcesc:server[@id eq $mgmtDoc//xcesc:user[@status eq 'enabled']/@id][@type eq $serverType][empty(xcesc:downTime[xs:dateTime(@since)<=$currentDateTime][empty(@until) or xs:dateTime(@until)>$currentDateTime])]
	(: } :)
};

(: It obtains the whole server configuration :)
declare function mgmt:getServer($id as xs:string)
	as element(xcesc:server)?
{
	mgmt:getManagementDoc()//xcesc:server[@id eq $id]
};

declare function mgmt:getServer($id as xs:string,$managerId as xs:string)
	as element(xcesc:server)?
{
	let $serverDoc := mgmt:getServer($id)
	return
		if(exists($serverDoc) and mgmt:has-user-id-server-role($managerId,'SERVER.UPDATE',$serverDoc)) then
			$serverDoc
		else
			()
};

declare function mgmt:getServers($ids as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@id = $ids]
};

(: It obtains the whole server configuration :)
declare function mgmt:getServersFromName($name as xs:string)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@name eq $name]
};

declare function mgmt:getServersFromNames($names as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@name = $names]
};

declare function mgmt:getServersFromOwnerId($id as xs:string)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@managerId eq $id]
};

(:~
 : It updates most pieces of the server declaration.
 : 
 : @author José María Fernández
 :)
declare function mgmt:updateServer($managerId as xs:string,$serverConfig as element(xcesc:server))
	as empty-sequence()
{
	(: (# exist:batch-transaction #) { :)
		let $serverDoc:=mgmt:getServer($serverConfig/@id,$managerId)
		let $justNow := current-dateTime()
		return
			if($serverDoc) then (
				for $server in $serverDoc[xcesc:description != $serverConfig/xcesc:description]
				return
					upd:replaceNode($serverDoc/xcesc:description,$serverConfig/xcesc:description)
				,
				for $server in $serverDoc[@name ne $serverConfig/@name]
				return
					upd:replaceValue($serverDoc/@name,$serverConfig/@name)
				,
				for $server in $serverDoc[@uri ne $serverConfig/@uri]
				return
					upd:replaceValue($serverDoc/@uri,$serverConfig/@uri)
				,
				if(not(deep-equal($serverDoc/xcesc:otherParams,$serverConfig/xcesc:otherParams))) then
					upd:replaceNode($serverDoc/xcesc:otherParams,$serverConfig/xcesc:otherParams)
				else
					()
				,
				if(not(deep-equal($serverDoc/xcesc:references,$serverConfig/xcesc:references))) then
					upd:replaceNode($serverDoc/xcesc:references,$serverConfig/xcesc:references)
				else
					()
				,
				for $newDown in $serverConfig/xcesc:downTime
				let $oldDown := $serverDoc/xcesc:downTime[@id eq $newDown/@id] 
				return
					if(empty($oldDown)) then
						if(exists($newDown/@since) and ( empty($newDown/@until) or xs:dateTime($newDown/@since) < xs:dateTime($newDown/@until) ) ) then (
							upd:insertInto($serverDoc,
								<xcesc:downTime
									id="{util:uuid()}"
									since="{$newDown/@since}"
									managerId="{$newDown/@managerId}"
									managerName="{$newDown/@managerName}"
								>{if(exists($newDown/@until)) then $newDown/@until else (),$newDown/node()}</xcesc:downTime>
							)
						) else
							()
					else (
						if(xs:dateTime($oldDown/@since) > $justNow and xs:dateTime($newDown/@since) >= $justNow and xs:dateTime($oldDown/@since) != xs:dateTime($newDown/@since)) then
							upd:replaceValue($oldDown/@since,$newDown/@since/string())
						else
							()
						,
						if(empty($oldDown/@until) and exists($newDown/@until)) then
							if(xs:dateTime($oldDown/@since) <= xs:dateTime($newDown/@until)) then
								upd:insertInto($oldDown,$newDown/@until)
							else
								(:
								upd:insertInto($oldDown,attribute { 'until' } { if($justNow > xs:dateTime($oldDown/@since)) then $justNow else $oldDown/@since/string() })
								:)
								()
						else
							()
						,
						if($oldDown/@managerId ne $newDown/@managerId) then (
							upd:replaceValue($oldDown/@managerId,$newDown/@managerId/string())
							, 
							upd:replaceValue($oldDown/@managerName,$newDown/@managerName/string()) 
						) else
							()
					)
				,
				(: Deleted downtimes, but only the ones which has not started :)
				for $oldDown in $serverDoc/xcesc:downTime[not(@id = $newDown/@id)]
				return
					(: We can only delete the downtimes which has not started :)
					if(xs:dateTime($oldDown/@since) > $justNow) then
						upd:delete($oldDown)
					else
						if(exists($oldDown/@until)) then
							if(xs:dateTime($oldDown/@until) > $justNow) then (
								upd:replaceValue($oldDown/@until,$justNow/string())
								,
								if($oldDown/@managerId ne $managerId) then (
									upd:replaceValue($oldDown/@managerId,$managerId)
									, 
									upd:replaceValue($oldDown/@managerName,mgmt:getUserFromId($managerId)/@nickname/string())
								) else
									() 
							) else
								()
						else (
							upd:insertInto($oldDown, attribute { 'until' } { $justNow/string() })
							,
							if($oldDown/@managerId ne $managerId) then (
								upd:replaceValue($oldDown/@managerId,$managerId)
								, 
								upd:replaceValue($oldDown/@managerName,mgmt:getUserFromId($managerId)/@nickname/string())
							) else
								() 
						)
			) else
				error((),string-join(("On server update, server",$serverConfig/@id,"owned by",$managerId,"is unknown"),' '))
	(: } :)
};

(:::::::::)
(: Users :)
(:::::::::)

(: User creation :)
(: From XForms :)
(: And the programatic way :)

(: This user confirmation function ends the user registration process in one or other sense :)
(: It also sends both notification and confirmation e-mails :)
declare function mgmt:confirmUser($id as xs:string,$answer as xs:boolean)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		let $userConfig := $mgmtDoc//xcesc:user[@id eq $id][@status eq 'unconfirmed']
		return
			if(exists($userConfig) and not(xmldb:exists-user($userConfig/@nickname))) then (
				if($answer) then (
					(: Perhaps in the future we will add bloggers group... :)
					let $emp:=system:as-user(
						collection($core:configColURI)//meta:metaManagement[1]/@user/string(),
						collection($core:configColURI)//meta:metaManagement[1]/@password/string(),
						xmldb:create-user($userConfig/@nickname,$userConfig/@nickpass,($mgmt:xcescGroup),())
					)
					return (
						upd:replaceValue($userConfig/@status,'enabled'),
						mailcore:send-email(<mail>
							<to>{$mgmt:adminMail}</to>
							<subject>{$mgmt:projectName} User Registration approval: {$userConfig/@nickname/string()}</subject>
							<message>
								<text>User {$userConfig/@nickname/string()} has been created at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
							</message>
						</mail>),
						mgmt:sendConfirmEMails($id),
						$id
					)
				) else (
					mgmt:deleteUser($id,$userConfig/@nickname),
					mailcore:send-email(<mail>
						<to>{$mgmt:adminMail}</to>
						<subject>{$mgmt:projectName} User Registration rejection: {$userConfig/@nickname/string()}</subject>
						<message>
							<text>User {$userConfig/@nickname/string()} has been rejected at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
						</message>
					</mail>)
				)
			) else (
				util:log-system-err(string-join(("On user creation, user",$id,"already existed"),' ')),
				error((),string-join(("On user creation, user",$id,"already existed"),' '))
			)
	(: } :)
};

(: This mail confirmation function ends the mail registration process in one or other sense :)
declare function mgmt:confirmEMail($id as xs:string,$eMailId as xs:string,$answer as xs:boolean)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $userConfig := mgmt:getUserFromId($id)
		let $mailConfig := $userConfig/xcesc:eMail[@id eq $eMailId][@status eq 'unconfirmed']
		return
			if($answer) then (
				upd:replaceValue($mailConfig/@status,'enabled'),
				mailcore:send-email(<mail>
					<to>{$mailConfig/text()}</to>
					<bcc>{$mgmt:adminMail}</bcc>
					<subject>{$mgmt:projectName}: e-mail for user {$userConfig/@nickname/string()} has been enabled</subject>
					<message>
						<text>User {$userConfig/@nickname/string()} has enabled e-mail address {$mailConfig/text()} for notifications at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
					</message>
				</mail>),
				$eMailId
			) else (
				upd:delete($mailConfig),
				mailcore:send-email(<mail>
					<to>{$mailConfig/text()}</to>
					<bcc>{$mgmt:adminMail}</bcc>
					<subject>{$mgmt:projectName}: user {$userConfig/@nickname/string()} has rejected this e-mail address</subject>
					<message>
						<text>User {$userConfig/@nickname/string()} has rejected e-mail address {$mailConfig/text()} for notifications at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
					</message>
				</mail>)
			)
	(: } :)
};

declare function mgmt:sendConfirmEMails($id as xs:string)
	as empty-sequence()
{
		let $userConfig := mgmt:getUserFromId($id)[not(@status = ('unconfirmed','deleted'))]
		return
			mailcore:send-email(
				for $email in $userConfig/xcesc:eMail[@status eq 'unconfirmed']
				return 
					<mail>
						<to>{concat($userConfig/@firstName/string(),' ',$userConfig/@lastName/string())} &lt;{$email/text()}&gt;</to>
						<subject>{$mgmt:projectName} confirmation: e-mail for user {$userConfig/@nickname/string()}</subject>
						<message>
							<xhtml>
								<html>
									<head>{$mgmt:projectName} confirmation: e-mail for user '{$userConfig/@nickname/string()}'</head>
									<body>
										<p>User '{$userConfig/@nickname/string()}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> affirms (s)he manages this e-mail address.</p>
										<p>
											Do you <a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_ID_KEY}={$userConfig/@id/string()}&amp;{$mgmt:CONFIRM_MAILID_KEY}={$email/@id/string()}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_YES_KEY}">confirm the e-mail address</a> or
											<a href="{$mgmt:confirmModuleURI}?{$mgmt:CONFIRM_ID_KEY}={$userConfig/@id/string()}&amp;{$mgmt:CONFIRM_MAILID_KEY}={$email/@id/string()}&amp;{$mgmt:CONFIRM_YESNO_KEY}={$mgmt:CONFIRM_NO_KEY}">reject the e-mail registration</a>?
										</p>
									</body>
								</html>
							</xhtml>
						</message>
					</mail>
			)
};

declare function mgmt:user-template()
	as element(xcesc:users)
{
	<xcesc:users>
		<xcesc:user id="" nickname="" nickpass="" firstName="" lastName="" organization="">
			<xcesc:eMail/>
			<xcesc:references>
				<xcesc:reference/>
			</xcesc:references>
			<xcesc:roles/>
		</xcesc:user>
	</xcesc:users>
};

declare function mgmt:servers-template()
	as element(xcesc:users)
{
	<xcesc:servers>
		<xcesc:server id="" name="" managerId="" futureManagerId="" uri="" type="">
			<xcesc:description/>
			<xcesc:kind/>
			<xcesc:otherParams>
				<xcesc:param/>
			</xcesc:otherParams>
			<xcesc:references>
				<xcesc:reference/>
			</xcesc:references>
		</xcesc:server>
	</xcesc:servers>
};

declare function mgmt:empty-user-template()
	as element(xcesc:users)
{
	<xcesc:users />
};

declare function mgmt:empty-servers-template()
	as element(xcesc:users)
{
	<xcesc:servers/>
};

declare function mgmt:createUser($userConfig as element(xcesc:user))
	as xs:string?
{
	(: Roles must be set later :)
	mgmt:createUser($userConfig/@nickname/string(),$userConfig/@nickpass/string(),$userConfig/@firstName/string(),$userConfig/@lastName/string(),$userConfig/@organization/string(),$userConfig/xcesc:eMail,$userConfig/xcesc:references/xcesc:reference,())
};

(: User deletion :)
declare function mgmt:deleteUser($id as xs:string,$nickname as xs:string)
	as empty-sequence() 
{
	(: (# exist:batch-transaction #) { :)
	if($nickname ne $mgmt:adminUser) then (
		let $mgmtDoc := mgmt:getManagementDoc()
		let $userDoc := $mgmtDoc//xcesc:user[@id eq $id][@nickname eq $nickname]
		return
			if(empty($userDoc)) then
				 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname,"or some of them are unknown"),' '))
			else (
				if(not($userDoc/@status = ('unconfirmed','deleted'))) then (
				 	if(xmldb:exists-user($nickname)) then (
						system:as-user(
							collection($core:configColURI)//meta:metaManagement[1]/@user/string(),
							collection($core:configColURI)//meta:metaManagement[1]/@password/string(),
							xmldb:delete-user($nickname)
						)
					) else ()
					,
					mgmt:send-mail-to-user($id,
						<mail>
							<subject>{$mgmt:projectName} notification: user {$userDoc/@nickname/string()} has been deleted</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} notification: user '{$userDoc/@nickname/string()}' has been deleted</head>
										<body>
											<p>User '{$userDoc/@nickname/string()}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> has been deleted.</p>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>
					)
				) else (),
				upd:replaceValue($userDoc/@status,'deleted')
			)
	) else
		 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname),' '))
	(: } :)
};

declare function mgmt:send-mail-to-user($id as xs:string,$message as element(mail))
	as empty-sequence()
{
	let $userDoc := mgmt:getUserFromId($id)
	return
		mailcore:send-email(
			for $email at $pos in $userDoc/xcesc:eMail[@status eq 'enabled']
			return
				<mail>
					<to>{$userDoc/@firstName/string()} {$userDoc/@lastName/string()} &lt;{$email/text()}&gt;</to>
					{
						(
							$message/to,
							$message/reply-to,
							$message/cc,
							$message/bcc,
							(: Only a notification for the first sent e-mail :)
							if($pos eq 1) then (
								<bcc>{$mgmt:adminMail}</bcc>
							) else ()
							,
							$message/subject,
							$message/message,
							$message/attachment
						)
					}
				</mail>
		)
};

declare function mgmt:deleteDeletedUsers($users as element(xcesc:deletedUser)*)
	as empty-sequence() 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc := mgmt:getManagementDoc()
		for $deluser in $users[@id ne '' and @nickname ne ''], $userDoc in $mgmtDoc//xcesc:user[@id eq $deluser/@id][@nickname eq $deluser/@nickname]
		return
			mgmt:deleteUser($deluser/@id,$deluser/@nickname)
	(: } :)
};



declare function mgmt:getRestrictedInfoFromId($id as xs:string)
	as element(xcesc:user)?
{
	for $userDoc in mgmt:getActiveUserFromId($id)
	return
		element { node-name($userDoc) } {
			for $child in $userDoc/@*
			return
				if(not($child/local-name() = ('nickpass','password'))) then (
					$child
				) else (
					(: Blanking these sensible attributes :)
					attribute { $child/local-name() } { }
				)
			,
			$userDoc/node()
		}
};

declare function mgmt:getRestrictedServerInfoFromId($id as xs:string)
	as element(xcesc:server)*
{
	for $serverDoc in mgmt:getServersFromOwnerId($id)
	return
		element { node-name($serverDoc) } {
			for $child in $serverDoc/@*
			return
				if(not($child/local-name() = ('nickpass','password'))) then (
					$child
				) else (
					(: Blanking these sensible attributes :)
					attribute { $child/local-name() } { }
				)
			,
			$serverDoc/node()
		}
};

declare function mgmt:getRestrictedUserListFromId($id as xs:string)
	as element(xcesc:users)
{
	<xcesc:users>{
		if(mgmt:is-super-user($id)) then (
			for $userDoc in mgmt:getManagementDoc()//xcesc:user[@status ne 'deleted']
			return
				element { node-name($userDoc) } {
					for $child in $userDoc/@*
					return
						if(not($child/local-name() = ('nickpass','password'))) then (
							$child
						) else
							( )
					,
					$userDoc/node()
				}
		) else (
			mgmt:getRestrictedInfoFromId($id)
		)
	}</xcesc:users>
};

declare function mgmt:getRestrictedServerListFromId($id as xs:string)
	as element(xcesc:servers)
{
	<xcesc:servers>{
		if(mgmt:is-super-user($id)) then (
			for $serverDoc in mgmt:getManagementDoc()//xcesc:server
			return
				element { node-name($serverDoc) } {
					for $child in $serverDoc/@*
					return
						if(not($child/local-name() = ('nickpass','password'))) then (
							$child
						) else
							( )
					,
					$serverDoc/node()
				}
		) else (
			mgmt:getRestrictedServerInfoFromId($id)
		)
	}</xcesc:servers>
};

(: It obtains the whole set of users :)
declare function mgmt:getUsers()
	as element(xcesc:user)*
{
	mgmt:getManagementDoc()//xcesc:user
};

(: It obtains the whole set of active users :)
declare function mgmt:getActiveUsers()
	as element(xcesc:user)*
{
	mgmt:getManagementDoc()//xcesc:user[@status eq 'enabled']
};

(: It updates most pieces of the user declaration :)
declare function mgmt:updateUser($id as xs:string,$userConfig as element(xcesc:user))
	as empty-sequence() 
{
	(: (# exist:batch-transaction #) { :)
		let $userDoc0:=mgmt:getUserFromNickname($userConfig/@nickname)
		let $userDoc := if(mgmt:has-user-id-role($id,'USER.UPDATE',$userDoc0)) then ( 
			$userDoc0[@status ne 'unconfirmed' and @status ne 'deleted']
		) else
			()
		return
			if($userDoc) then (
				if($userConfig/@status eq 'deleted') then (
					mgmt:deleteUser($id,$userConfig/@nickname)
				) else (
					if($userConfig/@status ne 'unconfirmed') then (
						for $user in $userDoc[@status ne $userConfig/@status]
						return
							upd:replaceValue($userDoc/@status,$userConfig/@status)
					) else
						()
					,
					for $user in $userDoc[@firstName ne $userConfig/@firstName]
					return
						upd:replaceValue($userDoc/@firstName,$userConfig/@firstName)
					,
					for $user in $userDoc[@lastName ne $userConfig/@lastName]
					return
						upd:replaceValue($userDoc/@lastName,$userConfig/@lastName)
					,
					for $user in $userDoc[@organization ne $userConfig/@organization]
					return
						upd:replaceValue($userDoc/@organization,$userConfig/@organization)
					,
					if(not(deep-equal($userDoc/xcesc:eMail,$userConfig/xcesc:eMail))) then (
						for $mail in $userConfig/xcesc:eMail
						let $oldMail := $userDoc/xcesc:eMail[@id eq $mail/@id] 
						return
							if(exists($oldMail)) then (
								if($oldMail/text() ne $mail/text()) then (
									upd:replaceNode($oldMail,<xcesc:eMail id="{util:uuid()}" status="unconfirmed">{$mail/text()}</xcesc:eMail>)
								) else (
									if($oldMail/@status ne $mail/@status) then (
										upd:replaceValue($oldMail/@status,$mail/@status) 
									) else
										()
								)
							) else (
								upd:insertInto($userDoc,<xcesc:eMail id="{util:uuid()}" status="unconfirmed">{$mail/text()}</xcesc:eMail>)
							)
						,
						upd:delete($userDoc/xcesc:eMail[not(@id = $userConfig/xcesc:eMail/@id)][@status ne 'unconfirmed'])
						,
						mgmt:sendConfirmEMails($id)
					) else
						()
					,
					if(not(deep-equal($userDoc/xcesc:references,$userConfig/xcesc:references))) then
						upd:replaceNode($userDoc/xcesc:references,$userConfig/xcesc:references)
					else
						()
					,
					(: Roles can only be updated when user is allowed to do that :)
					if(mgmt:has-user-id-role($id,'USER.GRANT.ROLE',$userDoc) and not(deep-equal($userDoc/xcesc:roles,$userConfig/xcesc:roles))) then
						upd:replaceNode($userDoc/xcesc:roles,$userConfig/xcesc:roles)
					else
						()
				)
			) else
				error((),string-join(("On user update,",$userConfig/@nickname,"changes from",$id,"are not allowed"),' '))
	(: } :)
};


declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string)
	as empty-sequence() 
{
	mgmt:changeUserPass($id,$nickname,$oldpass,$newpass,false())
};

declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string,$reset as xs:boolean)
	as empty-sequence() 
{
	(: (# exist:batch-transaction #) { :)
	if($nickname ne $mgmt:adminUser) then (
		let $userDoc0:=mgmt:getUserFromNickname($nickname)
		let $userDoc := if(mgmt:has-user-id-role($id,'USER.PASSWORD.UPDATE',$userDoc0)) then ( 
			$userDoc0[@status ne 'unconfirmed' and @status ne 'deleted']
		) else
			()
		return
			if($userDoc and ($reset or xmldb:authenticate('/db',$nickname,$oldpass))) then (
				system:as-user(
					collection($core:configColURI)//meta:metaManagement[1]/@user/string(),
					collection($core:configColURI)//meta:metaManagement[1]/@password/string(),
					xmldb:change-user($nickname,$newpass,(),())
				)
			) else
				error((),string-join(("On user password update,",$nickname,"password changes from",$id,"are not allowed"),' '))
	) else
		error((),string-join(("On user password update,",$nickname,"password changes are not allowed"),' '))
	(: } :)
};

