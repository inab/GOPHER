(:
	systemManagement.xqm
:)
xquery version "1.0";

module namespace mgmt="http://www.cnio.es/scombio/gopher/1.0/xquery/systemManagement";

declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace gopher="http://www.cnio.es/scombio/gopher/1.0";

declare variable $mgmt:adminPass as xs:string := "";

declare variable $mgmt:mgmtCol as xs:string := "/db/GOPHER-data";
declare variable $mgmt:mgmtDoc as xs:string := "managementData.xml";
declare variable $mgmt:mgmtDocPath as xs:string := string-join(($mgmt:mgmtCol,$mgmt:mgmtDoc),'/');

(:::::::::::::::::::::::)
(: Management Document :)
(:::::::::::::::::::::::)

declare function mgmt:getManagementDoc()
	as element(gopher:managementData)
{
	if(doc-available($mgmt:mgmtDocPath)) then (
		doc($mgmt:mgmtDocPath)/element()
	) else (
		let $newDoc := <gopher:managementData><gopher:users/><gopher:servers/></gopher:managementData>
		return doc(xmldb:store($mgmt:mgmtCol,$mgmt:mgmtDoc,$newDoc,'application/xml'))/element()
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
			let $serverDoc := $mgmtDoc//gopher:server[@id=$serverId and @managerId=$oldOwnerId]
			return
				if(empty($serverDoc)) then
					 error((),string-join(("On server ownership change, server",$serverId,"is not owned by",$oldOwnerId),' '))
				else
					update value $serverDoc/@managerId with $newOwnerId  
	}
};

(: It creates a server :)
declare function mgmt:createServer($name as xs:string,$managerId as xs:string,$uri as xs:anyURI,$description as xs:string?,$params as element(gopher:param)+,$references as element(gopher:reference)*)
	as xs:string? 
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if($mgmtDoc//gopher:user[@id=$managerId]) then
				let $id:=util:uuid()
				let $newServer:=<gopher:server id="{$id}" name="{$name}" managerId="{$managerId}" uri="{$uri}">
					<gopher:description><![CDATA[{$description}]]></gopher:description>
					<gopher:otherParams>{$params}</gopher:otherParams>
					{$references}
				</gopher:server>
				return (
					update insert $newServer into $mgmtDoc//gopher:servers,
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
		let $serverDoc := mgmt:getManagementDoc()//gopher:server[@id=$id and @managerId=$managerId]
		return
			if(empty($serverDoc)) then
				 error((),string-join(("On server deletion",$id,"owned by",$managerId,"is unknown"),' '))
			else
				update delete $serverDoc
	}  
};

(: It returns the set of available online servers :)
declare function mgmt:getOnlineServers()
	as element(gopher:server)*
{
	(# exist:batch-transaction #) {
		let $currentDateTime:=current-dateTime()
		return mgmt:getOnlineServer($currentDateTime)
	}
};

(: It returns the set of available online servers :)
declare function mgmt:getOnlineServers($currentDateTime as xs:dateTime)
	as element(gopher:server)*
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return $mgmtDoc//gopher:server[@id=$mgmtDoc//gopher:user[@status='enabled']/@id][empty(gopher:downTime[xs:dateTime(@from)<=$currentDateTime][empty(@to) or xs:dateTime(@to)>$currentDateTime])]
	}
};

(: It obtains the whole server configuration :)
declare function mgmt:getServer($id as xs:string+)
	as element(gopher:server)*
{
	mgmt:getManagementDoc()//gopher:server[@id=$id]
};

(: It obtains the whole server configuration :)
declare function mgmt:getServersFromName($name as xs:string+)
	as element(gopher:server)*
{
	mgmt:getManagementDoc()//gopher:server[@name=$name]
};

(: It updates most pieces of the server declaration :)
declare function mgmt:updateServer($managerId as xs:string,$serverConfig as element(gopher:server))
	as empty() 
{
	(# exist:batch-transaction #) {
		let $serverDoc:=mgmt:getServer($serverConfig/@id)[@managerId = $managerId]
		return
			if($serverDoc) then (
				for $server in $serverDoc[gopher:description != $serverConfig/gopher:description]
				return
					update replace $serverDoc/gopher:description with $serverConfig/gopher:description
				,
				for $server in $serverDoc[@name != $serverConfig/@name]
				return
					update value $serverDoc/@name with $serverConfig/@name
				,
				for $server in $serverDoc[@uri != $serverConfig/@uri]
				return
					update value $serverDoc/@uri with $serverConfig/@uri
				,
				if(not(deep-equal($serverDoc/gopher:otherParams,$serverConfig/gopher:otherParams))) then
					update replace $serverDoc/gopher:otherParams with $serverConfig/gopher:otherParams
				else
					()
				,
				if(not(deep-equal($serverDoc/gopher:reference,$serverConfig/gopher:reference))) then
					update replace $serverDoc/gopher:reference with $serverConfig/gopher:reference
				else
					()
				,
				for $newDown in $serverDoc/gopher:downTime
				let $oldDown := $serverConfig/gopher:downTime[@from=$newDown/@from] 
				return
					if(empty($oldDown)) then
						update insert $newDown into $serverDoc
					else
						if(empty($oldDown/@to) and exists($newDown/@to)) then
							update insert $newDown/@to into $oldDown
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
declare function mgmt:createUser($nickname as xs:string,$firstName as xs:string,$lastName as xs:string,$organization as xs:string,$eMails as element(gopher:eMail)+,$references as element(gopher:reference)*)
	as xs:string?
{
	(# exist:batch-transaction #) {
		let $mgmtDoc:=mgmt:getManagementDoc()
		return
			if(empty($mgmtDoc//gopher:user[@nickname=$nickname])) then
				let $id:=util:uuid()
				let $newUser:=<gopher:user id="{$id}" nickname="{$nickname}" firstName="{$firstName}" lastName="{$lastName}" organization="{$organization}" status="enabled">
					{$eMails}
					{$references}
				</gopher:user>
				return (
					update insert $newUser into $mgmtDoc//gopher:users,
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
		let $userDoc := $mgmtDoc//gopher:user[@id=$id and @nickname=$nickname]
		return
			if(empty($userDoc)) then
				 error((),string-join(("On user deletion,",$id,"is not allowed to erase",$nickname,"or some of them are unknown"),' '))
			else
				update delete $userDoc
	}
};

(: It obtains the whole user configuration, by id :)
declare function mgmt:getUserFromId($id as xs:string)
	as element(gopher:user)?
{
	mgmt:getManagementDoc()//gopher:user[@id=$id]
};

(: It obtains the whole user configuration, by nickname :)
declare function mgmt:getUserFromNickname($nickname as xs:string)
	as element(gopher:user)?
{
	mgmt:getManagementDoc()//gopher:user[@nickname=$nickname]
};

(: It updates most pieces of the user declaration :)
declare function mgmt:updateUser($id as xs:string,$userConfig as element(gopher:user))
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
				if(not(deep-equal($userDoc/gopher:eMail,$userConfig/gopher:eMail))) then
					update replace $userDoc/gopher:eMail with $userConfig/gopher:eMail
				else
					()
				,
				if(not(deep-equal($userDoc/gopher:reference,$userConfig/gopher:reference))) then
					update replace $userDoc/gopher:reference with $userConfig/gopher:reference
				else
					()
			) else
				error((),string-join(("On user update",$userConfig/@nickname,"changes from",$id,"are not allowed"),' '))
	}
};

