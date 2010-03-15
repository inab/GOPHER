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

declare variable $mgmt:configCol as xs:string := "/db/XCESC-config";
declare variable $mgmt:configColURI as xs:string := xmldb:encode($mgmt:configCol);

declare variable $mgmt:configRoot as element(mgmt:systemManagement) := collection($mgmt:configColURI)//mgmt:systemManagement[1];

declare variable $mgmt:partServer as xs:string := 'participant';
declare variable $mgmt:evalServer as xs:string := 'evaluator';

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

(: It changes a server's ownership :)
declare function mgmt:changeServerOwnership($oldOwnerId as xs:string,$serverId as xs:string,$newOwnerId as xs:string)
	as empty()
{
	(: (# exist:batch-transaction #) { :)
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getUserFromId($newOwnerId)
	return
		if(empty($userDoc)) then
			error((),string-join(("On server ownership change, user",$newOwnerId,"was not found"),' '))
		else (
			let $serverDoc := $mgmtDoc//xcesc:server[@id eq $serverId][@managerId eq $oldOwnerId]
			return
				if(empty($serverDoc)) then
					error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else
					update value $serverDoc/@managerId with $newOwnerId
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
declare function mgmt:createServer($name as xs:string,$managerId as xs:string,$uri as xs:anyURI,$isParticipant as xs:boolean,$description as xs:string?,$domains as xs:string+,$params as element(xcesc:param)+,$references as element(xcesc:reference)*)
	as xs:string? 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if($mgmtDoc//xcesc:user[@id eq $managerId]) then
				let $id:=util:uuid()
				let $newServer:=<xcesc:server id="{$id}" name="{$name}" managerId="{$managerId}" uri="{$uri}" type="{if($isParticipant) then $mgmt:partServer else $mgmt:evalServer}">
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
		let $serverDoc := mgmt:getManagementDoc()//xcesc:server[@id eq $id and @managerId eq $managerId]
		return
			if(empty($serverDoc)) then
				 error((),string-join(("On server deletion",$id,"owned by",$managerId,"is unknown"),' '))
			else
				update delete $serverDoc
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
declare function mgmt:createUser($nickname as xs:string,$nickpass as xs:string,$firstName as xs:string,$lastName as xs:string,$organization as xs:string,$eMails as element(xcesc:eMail)+, $references as element(xcesc:reference)*)
	as xs:string?
{
	(: (# exist:batch-transaction #) { :)
		let $warn := util:log-system-err("KENOKENNOKNEO")
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if(empty($mgmtDoc//xcesc:user[@nickname eq $nickname]) and not(xmldb:exists-user($nickname))) then (
				let $id:=util:uuid()
				(: Perhaps in the future we will add bloggers group... :)
				let $emp:=system:as-user(
					collection($mgmt:configColURI)//meta:metaManagement[1]/@user/string(),
					collection($mgmt:configColURI)//meta:metaManagement[1]/@password/string(),
					xmldb:create-user($nickname,$nickpass,($mgmt:xcescGroup),())
				)
				let $newUser:=<xcesc:user id="{$id}" nickname="{$nickname}" firstName="{$firstName}" lastName="{$lastName}" organization="{$organization}" status="enabled">
					{$eMails}
					{$references}
				</xcesc:user>
				return (
					update insert $newUser into $mgmtDoc//xcesc:users,
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
		let $userDoc := $mgmtDoc//xcesc:user[@id eq $id and @nickname eq $nickname]
		return
			if(empty($userDoc)) then
				 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname,"or some of them are unknown"),' '))
			else (
				system:as-user(
					collection($mgmt:configColURI)//meta:metaManagement[1]/@user/string(),
					collection($mgmt:configColURI)//meta:metaManagement[1]/@password/string(),
					xmldb:delete-user($nickname)
				),
				update delete $userDoc
			)
	(: } :)
};

declare function mgmt:deleteDeletedUsers($users as element(xcesc:deletedUser)*)
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $mgmtDoc := mgmt:getManagementDoc()
		for $deluser in $users[@id ne '' and @nickname ne ''], $userDoc in $mgmtDoc//xcesc:user[@id eq $deluser/@id and @nickname eq $deluser/@nickname]
		return (
			system:as-user(
				collection($mgmt:configColURI)//meta:metaManagement[1]/@user/string(),
				collection($mgmt:configColURI)//meta:metaManagement[1]/@password/string(),
				xmldb:delete-user($deluser/@nickname)
			),
			update delete $userDoc
		)
	(: } :)
};



(: It obtains the whole user configuration, by id :)
declare function mgmt:getUserFromId($id as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@id eq $id]
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@nickname eq $nickname]
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUsers()
	as element(xcesc:user)*
{
	mgmt:getManagementDoc()//xcesc:user
};

(: It updates most pieces of the user declaration :)
declare function mgmt:updateUser($id as xs:string,$userConfig as element(xcesc:user))
	as empty() 
{
	(: (# exist:batch-transaction #) { :)
		let $userDoc:=mgmt:getUserFromNickname($userConfig/@nickname)[@id eq $id]
		return
			if($userDoc) then (
				for $user in $userDoc[@status ne $userConfig/@status]
				return
					update value $userDoc/@status with $userConfig/@status
				,
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
				if(not(deep-equal($userDoc/xcesc:eMail,$userConfig/xcesc:eMail))) then
					update replace $userDoc/xcesc:eMail with $userConfig/xcesc:eMail
				else
					()
				,
				if(not(deep-equal($userDoc/xcesc:reference,$userConfig/xcesc:reference))) then
					update replace $userDoc/xcesc:reference with $userConfig/xcesc:reference
				else
					()
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
		let $userDoc:=mgmt:getUserFromNickname($nickname)[@id eq $id]
		return
			if($userDoc and ($reset or xmldb:authenticate('/db',$nickname,$oldpass))) then (
				system:as-user(
					collection($mgmt:configColURI)//meta:metaManagement[1]/@user/string(),
					collection($mgmt:configColURI)//meta:metaManagement[1]/@password/string(),
					xmldb:change-user($nickname,$newpass,(),())
				)
			) else
				error((),string-join(("On user password update",$nickname,"password changes from",$id,"are not allowed"),' '))
	(: } :)
};

