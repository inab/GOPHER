(:
	systemManagement.xqm
:)
xquery version "1.0";

module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

declare variable $mgmt:configCol as xs:string := "/db/XCESC-config";

declare variable $mgmt:adminUser as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/mgmt:admin/@user/string();
declare variable $mgmt:adminPass as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/mgmt:admin/@password/string();

declare variable $mgmt:xcescGroup as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/@group/string();

declare variable $mgmt:mgmtCol as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/@collection/string();
declare variable $mgmt:mgmtDoc as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/@managementDoc/string();

declare variable $mgmt:publicBaseURI as xs:string := collection($mgmt:configCol)//mgmt:systemManagement[1]/@publicBaseURI/string();

declare variable $mgmt:mgmtDocPath as xs:string := string-join(($mgmt:mgmtCol,$mgmt:mgmtDoc),'/');

(:::::::::::::::::::::::)
(: Management Document :)
(:::::::::::::::::::::::)

declare function mgmt:getManagementDoc()
	as element(xcesc:managementData)
{
	if(doc-available($mgmt:mgmtDocPath)) then (
		doc($mgmt:mgmtDocPath)/element()
	) else (
		let $newDoc := <xcesc:managementData><xcesc:users/><xcesc:servers/></xcesc:managementData>
		let $retElem := doc(xmldb:store($mgmt:mgmtCol,$mgmt:mgmtDoc,$newDoc,'application/xml'))/element()
		(: Only the owner can look at/change this file :)
		let $empty := xmldb:set-resource-permissions($mgmt:mgmtCol,$mgmt:mgmtDoc,$mgmt:adminUser,$mgmt:xcescGroup,7*64)
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
	(# exist:batch-transaction #) {
	let $mgmtDoc:=mgmt:getManagementDoc()
	let $userDoc:=mgmt:getUserFromId($newOwnerId)
	return
		if(empty($userDoc)) then
			error((),string-join(("On server ownership change, user",$newOwnerId,"was not found"),' '))
		else
			let $serverDoc := $mgmtDoc//xcesc:server[@id=$serverId and @managerId=$oldOwnerId]
			return
				if(empty($serverDoc)) then
					 error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else
					update value $serverDoc/@managerId with $newOwnerId  
	}
};

(: It creates a server :)
declare function mgmt:createServer($name as xs:string,$managerId as xs:string,$uri as xs:anyURI,$isParticipant as xs:boolean,$description as xs:string?,$domains as xs:string+,$params as element(xcesc:param)+,$references as element(xcesc:reference)*)
	as xs:string? 
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if($mgmtDoc//xcesc:user[@id=$managerId]) then
				let $id:=util:uuid()
				let $newServer:=<xcesc:server id="{$id}" name="{$name}" managerId="{$managerId}" uri="{$uri}" type="{if($isParticipant) then 'participant' else 'evaluator'}">
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
	}
};

(: It deletes a server :)
declare function mgmt:deleteServer($managerId as xs:string,$id as xs:string)
	as empty() 
{
	(# exist:batch-transaction #) {
		let $serverDoc := mgmt:getManagementDoc()//xcesc:server[@id=$id and @managerId=$managerId]
		return
			if(empty($serverDoc)) then
				 error((),string-join(("On server deletion",$id,"owned by",$managerId,"is unknown"),' '))
			else
				update delete $serverDoc
	}  
};

(: It returns the set of available online servers :)
declare function mgmt:getOnlineServers()
	as element(xcesc:server)*
{
	(# exist:batch-transaction #) {
		let $currentDateTime:=current-dateTime()
		return mgmt:getOnlineServers($currentDateTime)
	}
};

(: It returns the set of available online servers :)
declare function mgmt:getOnlineServers($currentDateTime as xs:dateTime)
	as element(xcesc:server)*
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return $mgmtDoc//xcesc:server[@id=$mgmtDoc//xcesc:user[@status='enabled']/@id][empty(xcesc:downTime[xs:dateTime(@since)<=$currentDateTime][empty(@until) or xs:dateTime(@until)>$currentDateTime])]
	}
};

(: It obtains the whole server configuration :)
declare function mgmt:getServer($id as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@id=$id]
};

(: It obtains the whole server configuration :)
declare function mgmt:getServersFromName($name as xs:string+)
	as element(xcesc:server)*
{
	mgmt:getManagementDoc()//xcesc:server[@name=$name]
};

(: It updates most pieces of the server declaration :)
declare function mgmt:updateServer($managerId as xs:string,$serverConfig as element(xcesc:server))
	as empty() 
{
	(# exist:batch-transaction #) {
		let $serverDoc:=mgmt:getServer($serverConfig/@id)[@managerId = $managerId]
		return
			if($serverDoc) then (
				for $server in $serverDoc[xcesc:description != $serverConfig/xcesc:description]
				return
					update replace $serverDoc/xcesc:description with $serverConfig/xcesc:description
				,
				for $server in $serverDoc[@name != $serverConfig/@name]
				return
					update value $serverDoc/@name with $serverConfig/@name
				,
				for $server in $serverDoc[@uri != $serverConfig/@uri]
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
				let $oldDown := $serverConfig/xcesc:downTime[@since=$newDown/@since] 
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
	}
};

(:::::::::)
(: Users :)
(:::::::::)

(: User creation :)
declare function mgmt:createUser($nickname as xs:string,$nickpass as xs:string,$firstName as xs:string,$lastName as xs:string,$organization as xs:string,$eMails as element(xcesc:eMail)+,$references as element(xcesc:reference)*)
	as xs:string?
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if(empty($mgmtDoc//xcesc:user[@nickname=$nickname]) and not(xmldb:exists-user($nickname))) then
				let $id:=util:uuid()
				(: Perhaps in the future we will add bloggers group... :)
				let $emp:=xmldb:create-user($nickname,$nickpass,($mgmt:xcescGroup),())
				let $newUser:=<xcesc:user id="{$id}" nickname="{$nickname}" firstName="{$firstName}" lastName="{$lastName}" organization="{$organization}" status="enabled">
					{$eMails}
					{$references}
				</xcesc:user>
				return (
					update insert $newUser into $mgmtDoc//xcesc:users,
					$id
				)
			else
				error((),string-join(("On server creation, user",$nickname,"already existed"),' '))
	}
};

(: User deletion :)
declare function mgmt:deleteUser($id as xs:string,$nickname as xs:string)
	as empty() 
{
	(# exist:batch-transaction #) {
		let $mgmtDoc := mgmt:getManagementDoc()
		let $userDoc := $mgmtDoc//xcesc:user[@id=$id and @nickname=$nickname]
		return
			if(empty($userDoc)) then
				 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname,"or some of them are unknown"),' '))
			else
				xmldb:delete-user($nickname),
				update delete $userDoc
	}
};

(: It obtains the whole user configuration, by id :)
declare function mgmt:getUserFromId($id as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@id=$id]
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUserFromNickname($nickname as xs:string)
	as element(xcesc:user)?
{
	mgmt:getManagementDoc()//xcesc:user[@nickname=$nickname]
};

(: It updates most pieces of the user declaration :)
declare function mgmt:updateUser($id as xs:string,$userConfig as element(xcesc:user))
	as empty() 
{
	(# exist:batch-transaction #) {
		let $userDoc:=mgmt:getUserFromNickname($userConfig/@nickname)[@id = $id]
		return
			if($userDoc) then (
				for $user in $userDoc[@status != $userConfig/@status]
				return
					update value $userDoc/@status with $userConfig/@status
				,
				for $user in $userDoc[@firstName != $userConfig/@firstName]
				return
					update value $userDoc/@firstName with $userConfig/@firstName
				,
				for $user in $userDoc[@lastName != $userConfig/@lastName]
				return
					update value $userDoc/@lastName with $userConfig/@lastName
				,
				for $user in $userDoc[@organization != $userConfig/@organization]
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
	}
};


declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string)
	as empty() 
{
	(mgmt:changeUserPass($id,$nickname,$oldpass,$newpass,false))
};

declare function mgmt:changeUserPass($id as xs:string, $nickname as xs:string,$oldpass as xs:string,$newpass as xs:string,$reset as xs:boolean)
	as empty() 
{
	(# exist:batch-transaction #) {
		let $userDoc:=mgmt:getUserFromNickname($nickname)[@id = $id]
		return
			if($userDoc and ($reset or xmldb:authenticate('/db',$nickname,$oldpass))) then (
				xmldb:change-user($nickname,$newpass,(),())
			) else
				error((),string-join(("On user password update",$nickname,"password changes from",$id,"are not allowed"),' '))
	}
};

