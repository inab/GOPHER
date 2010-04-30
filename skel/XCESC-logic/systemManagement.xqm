(:
	systemManagement.xqm
:)
xquery version "1.0";

module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement";

declare namespace meta="http://www.cnio.es/scombio/xcesc/1.0/xquery/metaManagement";
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace core = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/core' at 'xmldb:exist:///db/XCESC-logic/core.xqm';
import module namespace mailcore = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/mailCore' at 'xmldb:exist:///db/XCESC-logic/mailCore.xqm';

declare variable $mgmt:configRoot as element(mgmt:systemManagement) := collection($core:configColURI)//mgmt:systemManagement[1];

declare variable $mgmt:partServer as xs:string := 'participant';
declare variable $mgmt:evalServer as xs:string := 'evaluator';

declare variable $mgmt:projectName as xs:string := $mgmt:configRoot/@projectName/string();

declare variable $mgmt:adminUser as xs:string := $mgmt:configRoot/mgmt:admin/@user/string();
declare variable $mgmt:adminPass as xs:string := $mgmt:configRoot/mgmt:admin/@password/string();

declare variable $mgmt:xcescGroup as xs:string := $mgmt:configRoot/@group/string();

declare variable $mgmt:mgmtCol as xs:string := $mgmt:configRoot/@collection/string();
declare variable $mgmt:mgmtColURI as xs:string := xmldb:encode($mgmt:mgmtCol);
declare variable $mgmt:mgmtDoc as xs:string := $mgmt:configRoot/@managementDoc/string();
declare variable $mgmt:mgmtDocURI as xs:string := xmldb:encode($mgmt:mgmtDoc);

declare variable $mgmt:publicServerPort as xs:string := $mgmt:configRoot/@publicServerPort/string();
declare variable $mgmt:publicBaseURI as xs:string := concat(
	if($mgmt:publicServerPort eq '443') then 'https' else 'http',
	'://',
	$mgmt:configRoot/@publicServerName/string(),
	if($mgmt:publicServerPort ne '80' and $mgmt:publicServerPort ne '443') then concat(':',$mgmt:publicServerPort) else '',
	$mgmt:configRoot/@publicBasePath/string()
	);

declare variable $mgmt:mgmtDocPath as xs:string := string-join(($mgmt:mgmtCol,$mgmt:mgmtDoc),'/');
declare variable $mgmt:mgmtDocPathURI as xs:string := xmldb:encode($mgmt:mgmtDocPath);

declare variable $mgmt:confirmModule as xs:string := 'confirm.xql';
declare variable $mgmt:confirmModuleURI as xs:string := string-join(($mgmt:publicBaseURI,$core:relLogicCol,$mgmt:confirmModule),'/');


(:::::::::::::::::::::::)
(: Management Document :)
(:::::::::::::::::::::::)

declare function mgmt:getManagementDoc()
	as element(xcesc:managementData)
{
	if(doc-available($mgmt:mgmtDocPathURI)) then (
		doc($mgmt:mgmtDocPathURI)/element()
	) else (
		let $newDoc := <xcesc:managementData><xcesc:users/><xcesc:servers/></xcesc:managementData>
		let $mgmtColURI := xmldb:encode($mgmt:mgmtCol)
		let $dummy := xmldb:create-collection("/",$mgmtColURI)
		let $retElem := doc(xmldb:store($mgmtColURI,$mgmt:mgmtDocURI,$newDoc,'application/xml'))/element()
		(: Only the owner can look at/change this file :)
		let $empty := xmldb:set-resource-permissions($mgmt:mgmtColURI,$mgmt:mgmtDocURI,$mgmt:adminUser,$mgmt:xcescGroup,7*64)
		return $retElem
	)
};

(:::::::::::)
(: Servers :)
(:::::::::::)

(: It requests changes on server's ownership :)
declare function mgmt:requestChangeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string)
	as empty()
{
	(: (# exist:batch-transaction #) { :)
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getActiveUserFromId($newOwnerId)
	let $oldUserDoc:=mgmt:getActiveUserFromId($oldOwnerId)
	return
		if($newOwnerId ne '' and empty($userDoc)) then
			error((),string-join(("On server ownership change, user",$newOwnerId,"was not available"),' '))
		else (
			let $serverDoc := $mgmtDoc//xcesc:server[@id eq $serverId][@managerId eq $oldOwnerId]
			return
				if(empty($serverDoc)) then
					error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else (
					update value $serverDoc/@futureManagerId with $newOwnerId
					,
					if(exists($userDoc)) then (
						mgmt:send-mail-to-user($newOwnerId,<mail>
							<subject>{$mgmt:projectName} confirmation: server ownership change</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} confirmation: server '{$serverDoc/@name}' ownership change</head>
										<body>
											<p>{$oldUserDoc/@firstName} {$oldUserDoc/@lastName} ({$oldUserDoc/@nickname}), the owner of the server '{$serverDoc/@name}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> affirms you want to accept the server's ownership.</p>
											<p>
												Do you <a href="{$mgmt:confirmModuleURI}?oldOwner={$oldOwnerId}&amp;serverId={$serverId}&amp;newOwner={$newOwnerId}&amp;confirm=yes">agree</a> with the ownership change
												or you <a href="{$mgmt:confirmModuleURI}?oldOwner={$oldOwnerId}&amp;serverId={$serverId}&amp;newOwner={$newOwnerId}&amp;confirm=no">reject</a> it?
											</p>
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

declare function mgmt:changeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string)
	as empty()
{
	changeServerOwnership($oldOwnerId,$serverId,$newOwnerId,true())
};

declare function mgmt:changeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string,$answer as xs:boolean)
	as empty()
{
	(: (# exist:batch-transaction #) { :)
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getActiveUserFromId($newOwnerId)
	return
		if(empty($userDoc)) then
			error((),string-join(("On server ownership change, user",$newOwnerId,"was not available"),' '))
		else (
			let $serverDoc := $mgmtDoc//xcesc:server[@id eq $serverId][@managerId eq $oldOwnerId][@futureManagerId eq $newOwnerId]
			return
				if(empty($serverDoc)) then
					error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else (
					update value $serverDoc/@futureManagerId with '',
					if($answer) then (
						update value $serverDoc/@managerId with $newOwnerId,
						mgmt:send-mail-to-user($oldOwnerId,<mail>
							<subject>{$mgmt:projectName} notification: server ownership changed</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} notification: server '{$serverDoc/@name}' ownership changed</head>
										<body>
											<p>{$userDoc/@firstName} {$userDoc/@lastName} ({$userDoc/@nickname}), hass accepted the ownership of the server '{$serverDoc/@name}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
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
										<head>{$mgmt:projectName} notification: server '{$serverDoc/@name}' ownership rejection</head>
										<body>
											<p>{$userDoc/@firstName} {$userDoc/@lastName} ({$userDoc/@nickname}), has rejected the ownership of the server '{$serverDoc/@name}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
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

(: It creates a server :)
declare function mgmt:createServer($serverConfig as element(xcesc:server))
	as xs:string?
{
	(mgmt:createServer($serverConfig/@name,$serverConfig/@managerId,$serverConfig/@uri,$serverConfig/@type eq $mgmt:partServer,$serverConfig/xcesc:description/text(),$serverConfig/xcesc:kind/text(),$serverConfig/xcesc:otherParams/xcesc:param,$serverConfig/xcesc:reference))
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
					{$references}
				</xcesc:server>
				return (
					update insert $newServer into $mgmtDoc//xcesc:servers,
					mgmt:send-mail-to-user($managerId,<mail>
						<subject>{$mgmt:projectName} notification: server registered</subject>
						<message>
							<xhtml>
								<html>
									<head>{$mgmt:projectName} notification: server '{$newServer/@name}' has been registered</head>
									<body>
										<p>The server '{$newServer/@name}' is registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a>.</p>
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
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $serverDoc := mgmt:getManagementDoc()//xcesc:server[@id eq $id][@managerId eq $managerId]
		return
			if(empty($serverDoc)) then
				 error((),string-join(("On server deletion",$id,"owned by",$managerId,"is unknown"),' '))
			else (
				update delete $serverDoc
			)
	(: } :)
};

(: It returns the set of available participant and evaluation online servers :)
declare function mgmt:getOnlineServers()
	as element(xcesc:server)*
{
	(: (# exist:batch-transaction #) { :)
		let $currentDateTime:=current-dateTime()
		return mgmt:getOnlineServers($currentDateTime,$mgmt:partServer)
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
declare function mgmt:getServer($id as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@id eq $id]
};

(: It obtains the whole server configuration :)
declare function mgmt:getServersFromName($name as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@name eq $name]
};

(: It updates most pieces of the server declaration :)
declare function mgmt:updateServer($managerId as xs:string,$serverConfig as element(xcesc:server))
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $serverDoc:=mgmt:getServer($serverConfig/@id)[@managerId eq $managerId]
		return
			if($serverDoc) then (
				for $server in $serverDoc[xcesc:description != $serverConfig/xcesc:description]
				return
					update replace $serverDoc/xcesc:description with $serverConfig/xcesc:description
				,
				for $server in $serverDoc[@name ne $serverConfig/@name]
				return
					update value $serverDoc/@name with $serverConfig/@name
				,
				for $server in $serverDoc[@uri ne $serverConfig/@uri]
				return
					update value $serverDoc/@uri with $serverConfig/@uri
				,
				if(not(deep-equal($serverDoc/xcesc:otherParams,$serverConfig/xcesc:otherParams))) then
					update replace $serverDoc/xcesc:otherParams with $serverConfig/xcesc:otherParams
				else
					()
				,
				if(not(deep-equal($serverDoc/xcesc:reference,$serverConfig/xcesc:reference))) then
					update replace $serverDoc/xcesc:reference with $serverConfig/xcesc:reference
				else
					()
				,
				for $newDown in $serverDoc/xcesc:downTime
				let $oldDown := $serverConfig/xcesc:downTime[@since eq $newDown/@since] 
				return
					if(empty($oldDown)) then
						update insert $newDown into $serverDoc
					else
						if(empty($oldDown/@until) and exists($newDown/@until)) then
							update insert $newDown/@until into $oldDown
						else
							()
			) else
				error((),string-join(("On server update",$serverConfig/@id,"owned by",$managerId,"is unknown"),' '))
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
						update value $userConfig/@status with 'enabled',
						mailcore:send-email(<mail>
							<to>{$mgmt:configRoot/mgmt:admin[1]/@mail}</to>
							<subject>{$mgmt:projectName} User Registration approval: {$userConfig/@nickname}</subject>
							<message>
								<text>User {$userConfig/@nickname} has been created at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
							</message>
						</mail>),
						mgmt:sendConfirmEMails($id),
						$id
					)
				) else (
					mgmt:deleteUser($id,$userConfig/@nickname),
					mailcore:send-email(<mail>
						<to>{$mgmt:configRoot/mgmt:admin[1]/@mail}</to>
						<subject>{$mgmt:projectName} User Registration rejection: {$userConfig/@nickname}</subject>
						<message>
							<text>User {$userConfig/@nickname} has been rejected at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
						</message>
					</mail>)
				)
			) else (
				util:log-system-err(string-join(("On server creation, user",$nickname,"already existed"),' ')),
				error((),string-join(("On user creation, user",$nickname,"already existed"),' '))
			)
	(: } :)
};

(: This mail confirmation function ends the mail registration process in one or other sense :)
declare function mgmt:confirmEMail($id as xs:string,$eMailId as xs:string,$answer as xs:boolean)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		let $mailConfig := $mgmtDoc//xcesc:user[@id eq $id]/xcesc:eMail[@id eq $eMailId][@status eq 'unconfirmed']
		return
			if($answer) then (
				update value $mailConfig/@status with 'enabled',
				mailcore:send-email(<mail>
					<to>{$mailConfig/text()}</to>
					<bcc>{$mgmt:configRoot/mgmt:admin[1]/@mail}</bcc>
					<subject>{$mgmt:projectName}: mail for user {$userConfig/@nickname} has been enabled</subject>
					<message>
						<text>User {$userConfig/@nickname} has enabled e-mail address {$mailConfig/text()} for notifications at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
					</message>
				</mail>),
				$eMailId
			) else (
				update delete $emailConfig,
				mailcore:send-email(<mail>
					<to>{$mailConfig/text()}</to>
					<bcc>{$mgmt:configRoot/mgmt:admin[1]/@mail}</bcc>
					<subject>{$mgmt:projectName}: user {$userConfig/@nickname} has rejected this e-mail address</subject>
					<message>
						<text>User {$userConfig/@nickname} has rejected e-mail address {$mailConfig/text()} for notifications at {$mgmt:projectName} ({$mgmt:publicBaseURI})</text>
					</message>
				</mail>)
			)
	(: } :)
};

declare function mgmt:sendConfirmEMails($id as xs:string)
	as empty()
{
		let $mgmtDoc:=mgmt:getManagementDoc()
		let $userConfig := $mgmtDoc//xcesc:user[@id eq $id][@status ne 'unconfirmed']
		return
			mailcore:send-email(
				for $email in $userConfig/xcesc:eMail[@status eq 'unconfirmed']
				return 
					<mail>
						<to>{$userConfig/@firstName} {$userConfig/@lastName} &lt;{$email/text()}&gt;</to>
						<subject>{$mgmt:projectName} confirmation: e-mail for user {$userConfig/@nickname}</subject>
						<message>
							<xhtml>
								<html>
									<head>{$mgmt:projectName} confirmation: e-mail for user '{$userConfig/@nickname}'</head>
									<body>
										<p>User '{$userConfig/@nickname}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> affirms (s)he manages this e-mail address.</p>
										<p>
											Do you <a href="{$mgmt:confirmModuleURI}?id={$userConfig/@id}&amp;emailId={$email/@id}&amp;confirm=yes">confirm the e-mail address</a> or
											<a href="{$mgmt:confirmModuleURI}?id={$userConfig/@id}&amp;emailId={$email/@id}&amp;confirm=no">reject the e-mail registration</a>?
										</p>
									</body>
								</html>
							</xhtml>
						</message>
					</mail>
			)
};

declare function mgmt:createUser($nickname as xs:string,$nickpass as xs:string,$firstName as xs:string,$lastName as xs:string,$organization as xs:string,$eMails as element(xcesc:eMail)+, $references as element(xcesc:reference)*)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if(empty($mgmtDoc//xcesc:user[@nickname eq $nickname]) and not(xmldb:exists-user($nickname))) then (
				let $id:=util:uuid()
				(: Perhaps in the future we will add bloggers group... :)
				let $newUser:=<xcesc:user id="{$id}" nickname="{$nickname}" firstName="{$firstName}" lastName="{$lastName}" organization="{$organization}" status="unconfirmed">
					{
						(: eMail curation, because at the beginning they are unconfirmed by default :)
						for $eMail in $eMails
						let $eMailId := util:uuid()
						return
							<xcesc:eMail id="{$eMailId}" status="unconfirmed">{$eMail/text()}</xcesc:eMail>
					}
					{$references}
				</xcesc:user>
				return (
					update insert $newUser into $mgmtDoc//xcesc:users,
					mailcore:send-email(<mail>
						<to>{$mgmt:configRoot/mgmt:admin[1]/@mail}</to>
						<subject>XCESC User Registration request</subject>
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
													<li><a href="{$reference/text()}">{$reference/@description}</a> ({$reference/@kind})</li>
											}</ul></li>
										</ul>
										<div align="center">
											<a href="{$mgmt:confirmModuleURI}?id={$id}&amp;confirm=yes">Approve new user {$nickname}</a> <b>or</b>
											<a href="{$mgmt:confirmModuleURI}?id={$id}&amp;confirm=no">Reject new user {$nickname}</a>?
										</div>
									</body>
								</html>
							</xhtml>
						</message>
					</mail>),
					$id
				)
			) else (
				util:log-system-err(string-join(("On server creation, user",$nickname,"already existed"),' ')),
				error((),string-join(("On user creation, user",$nickname,"already existed"),' '))
			)
	(: } :)
};

declare function mgmt:createUser($userConfig as element(xcesc:user))
	as xs:string?
{
	(mgmt:createUser($userConfig/@nickname/string(),$userConfig/@nickpass/string(),$userConfig/@firstName/string(),$userConfig/@lastName/string(),$userConfig/@organization/string(),$userConfig/xcesc:eMail,$userConfig/xcesc:reference))
};

(: User deletion :)
declare function mgmt:deleteUser($id as xs:string,$nickname as xs:string)
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc := mgmt:getManagementDoc()
		let $userDoc := $mgmtDoc//xcesc:user[@id eq $id][@nickname eq $nickname]
		return
			if(empty($userDoc)) then
				 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname,"or some of them are unknown"),' '))
			else (
				if($userDoc/@status ne 'unconfirmed' and $userDoc/@status ne 'deleted') then (
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
							<subject>{$mgmt:projectName} notification: user {$userConfig/@nickname} has been deleted</subject>
							<message>
								<xhtml>
									<html>
										<head>{$mgmt:projectName} notification: user '{$userConfig/@nickname}' has been deleted</head>
										<body>
											<p>User '{$userConfig/@nickname}' registered at <a href="{$mgmt:publicBaseURI}">{$mgmt:projectName}</a> has been deleted.</p>
										</body>
									</html>
								</xhtml>
							</message>
						</mail>
					)
				) else (),
				update value $userDoc/@status with 'deleted'
			)
	(: } :)
};

declare function mgmt:send-mail-to-user($id as xs:string,$message as element(mail))
	as empty()
{
	let $userDoc := $mgmtDoc//xcesc:user[@id eq $id]
	return
		mailcore:send-email(
			for $email at $pos in $userDoc/xcesc:eMail[@status eq 'enabled']
			return
				<mail>
					<to>{$userDoc/@firstName} {$userDoc/@lastName} &lt;{$email/text()}&gt;</to>
					{
						(
							$message/to,
							$message/reply-to,
							$message/cc,
							$message/bcc,
							(: Only a notification for the first sent e-mail :)
							if($pos eq 1) then (
								<bcc>{$mgmt:configRoot/mgmt:admin[1]/@mail}</bcc>
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
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc := mgmt:getManagementDoc()
		for $deluser in $users[@id ne '' and @nickname ne ''], $userDoc in $mgmtDoc//xcesc:user[@id eq $deluser/@id][@nickname eq $deluser/@nickname]
		return
			mgmt:deleteUser($deluser/@id,$deluser/@nickname)
	(: } :)
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
	mgmt:getManagementDoc()//xcesc:user[@id eq $id][@status eq 'enabled']
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@nickname eq $nickname]
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getActiveUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@nickname eq $nickname][@status eq 'enabled']
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
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $userDoc:=mgmt:getUserFromNickname($userConfig/@nickname)[@id eq $id][@status ne 'unconfirmed' and @status ne 'deleted']
		return
			if($userDoc) then (
				if($userConfig/@status eq 'deleted') then (
					mgmt:deleteUser($id,$userConfig/@nickname)
				) else (
					if($userConfig/@status ne 'unconfirmed') then (
						for $user in $userDoc[@status ne $userConfig/@status]
						return
							update value $userDoc/@status with $userConfig/@status
					) else (),
					for $user in $userDoc[@firstName ne $userConfig/@firstName]
					return
						update value $userDoc/@firstName with $userConfig/@firstName
					,
					for $user in $userDoc[@lastName ne $userConfig/@lastName]
					return
						update value $userDoc/@lastName with $userConfig/@lastName
					,
					for $user in $userDoc[@organization ne $userConfig/@organization]
					return
						update value $userDoc/@organization with $userConfig/@organization
					,
					if(not(deep-equal($userDoc/xcesc:eMail,$userConfig/xcesc:eMail))) then (
						for $mail in $userConfig/xcesc:eMail
						let $oldMail := $userDoc/xcesc:eMail[@id eq $mail/@id] 
						return
							if(exists($oldMail)) then (
								if($oldMail/text() ne $mail/text()) then (
									update replace $oldMail <xcesc:eMail id="{util:uuid()}" status="unconfirmed">{$mail/text()}</xcesc:eMail>
								) else (
									if($oldMail/@status ne $mail/@status) then (
										update value $oldMail/@status with $mail/@status 
									) else (
									)
								)
							) else (
								update insert <xcesc:eMail id="{util:uuid()}" status="unconfirmed">{$mail/text()}</xcesc:eMail> into $userDoc
							)
						,
						update delete $userDoc/xcesc:eMail[not(@id = $userConfig/xcesc:eMail/@id)][@status ne 'unconfirmed']
						,
						mgmt:sendConfirmEMails($id)
					) else
						()
					,
					if(not(deep-equal($userDoc/xcesc:reference,$userConfig/xcesc:reference))) then
						update replace $userDoc/xcesc:reference with $userConfig/xcesc:reference
					else
						()
				)
			) else
				error((),string-join(("On user update",$userConfig/@nickname,"changes from",$id,"are not allowed"),' '))
	(: } :)
};


declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string)
	as empty() 
{
	(mgmt:changeUserPass($id,$nickname,$oldpass,$newpass,false))
};

declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string,$reset as xs:boolean)
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $userDoc:=mgmt:getUserFromNickname($nickname)[@id eq $id][@status ne 'unconfirmed' and @status ne 'deleted']
		return
			if($userDoc and ($reset or xmldb:authenticate('/db',$nickname,$oldpass))) then (
				system:as-user(
					collection($core:configColURI)//meta:metaManagement[1]/@user/string(),
					collection($core:configColURI)//meta:metaManagement[1]/@password/string(),
					xmldb:change-user($nickname,$newpass,(),())
				)
			) else
				error((),string-join(("On user password update",$nickname,"password changes from",$id,"are not allowed"),' '))
	(: } :)
};

