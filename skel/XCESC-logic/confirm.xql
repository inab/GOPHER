xquery version "1.0" encoding "UTF-8";

(::pragma exist:output-size-limit -1::)
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

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
		response:set-status-code(400)
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
					system:as-user($mgmt:adminUser,$mgmt:adminPass,
						util:catch("*",
							(: Write code here! :)
							let $emp1 := mgmt:changeServerOwnership($oldOwnerId,$serverId,$newOwnerId,$answer)
							return
								response:set-status-code(200)
							,
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC change server ownership ({$oldOwnerId}, {$serverId}, {$newOwnerId}, {$answer}) job: {$util:exception-message}.</error>)
							return
								response:set-status-code(500)
						)
					)
				)
			) else (
				if(empty($mailId)) then (
					(: TODO: return checks :)
					(: User confirmation :)
					system:as-user($mgmt:adminUser,$mgmt:adminPass,
						util:catch("*",
							(: Write code here! :)
							let $emp1 := mgmt:confirmUser($id,$answer)
							return
								response:set-status-code(200)
							,
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC user creation confirmation ({$id}, {$answer}) job: {$util:exception-message}.</error>)
							return
								response:set-status-code(500)
						)
					)
				) else (
					(: TODO: return checks :)
					(: Mail confirmation :)
					system:as-user($mgmt:adminUser,$mgmt:adminPass,
						util:catch("*",
							(: Write code here! :)
							let $emp1 := mgmt:confirmEMail($id,$mailId,$answer)
							return
								response:set-status-code(200)
							,
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC change server ownership ({$id}, {$mailId}, {$answer}) job: {$util:exception-message}.</error>)
							return
								response:set-status-code(500)
						)
					)
				)
			)
	)
