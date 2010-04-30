xquery version "1.0";

(::pragma exist:output-size-limit -1::)
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace session="http://exist-db.org/xquery/session";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";

(: First, get the path info :)
let $confirm := request:get-parameter("confirm",())[1]
let $oldOwner := request:get-parameter("oldOwner",())[1]
let $newOwner := request:get-parameter("newOwner",())[1]
let $serverId := request:get-parameter("serverId",())[1]
let $id := request:get-parameter("id",())[1]
let $mailId := request:get-parameter("mailId",())[1]
return
	if(empty($confirm) or not($confirm = ("yes","no"))) then (
		(: Lost or invalid confirmation value :)
	) else (
		let $answer := if($confirm eq 'yes') then true() else false()
		return
			if(empty($id)) then (
				(: It is a server ownership change confirmation :)
				if(empty($oldOwner) or empty($newOwner) or empty($serverId)) then (
					(: Lack of parameters for server change ownership :)
					response:set-status-code(400)
				) else (
					(: TODO: return checks :)
					mgmt:changeServerOwnership($oldOwnerId,$serverId,$newOwnerId,$answer)
				)
			) else (
				if(empty($mailId)) then (
					(: TODO: return checks :)
					(: User confirmation :)
					mgmt:confirmUser($id,$answer)
				) else (
					(: TODO: return checks :)
					(: Mail confirmation :)
					mgmt:confirmEMail($id,$mailId,$answer)
				)
			)
	)
(:
	if (count($jobTokens) >= 2 and session:set-current-user($mgmt:adminUser,$mgmt:adminPass)) then (
		response:set-status-code(job:joinResults($jobTokens[0],$jobTokens[1],current-dateTime(),request:get-data())),
		session:invalidate-session()
	) else
		response:set-status-code(400)
:)
