xquery version "1.0" encoding "UTF-8";

(::pragma exist:output-size-limit -1::)
declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace gui="http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement" at "xmldb:exist:///db/XCESC-logic/guiManagement.xqm";

(: First, get the path info :)
let $confirm := request:get-parameter($mgmt:CONFIRM_YESNO_KEY,())[1]
let $oldOwnerId := request:get-parameter($mgmt:CONFIRM_OLDOWNER_KEY,())[1]
let $newOwnerId := request:get-parameter($mgmt:CONFIRM_NEWOWNER_KEY,())[1]
let $serverId := request:get-parameter($mgmt:CONFIRM_SERVERID_KEY,())[1]
let $id := request:get-parameter($mgmt:CONFIRM_ID_KEY,())[1]
let $mailId := request:get-parameter($mgmt:CONFIRM_MAILID_KEY,())[1]
let $fullRequest := concat(request:get-uri(),request:get-path-info(),'?',request:get-query-string())
return
	if(empty($confirm) or not($confirm = ($mgmt:CONFIRM_YES_KEY,$mgmt:CONFIRM_NO_KEY))) then (
		(: Lost or invalid confirmation value :)
		util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
		gui:integrate-contents(
			concat($mgmt:projectName,' User/Server Confirmation Error'),
			(
				<div align="center">
					<h3 style="color:red">The confirmation URL</h3>
					<h3>{$fullRequest}</h3>
					<h3 style="color:red">is ill-formed</h3>
				</div>
				,
				<div align="right">The {$mgmt:projectName} Team</div>
			)
		)
		,
		response:set-status-code(400)
	) else (
		let $answer := if($confirm eq $mgmt:CONFIRM_YES_KEY) then true() else false()
		return
			if(empty($id)) then (
				(: It is a server ownership change confirmation :)
				if(empty($oldOwnerId) or empty($newOwnerId) or empty($serverId)) then (
					(: Lack of parameters for server change ownership :)
					util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
					gui:integrate-contents(
						concat($mgmt:projectName,' Server Ownership Change Confirmation Error'),
						(
							<div align="center">
								<h1 style="color:red">The confirmation URL for server ownership change</h1>
								<h2>{$fullRequest}</h2>
								<h1 style="color:red">is ill-formed or incorrect</h1>
							</div>
							,
							<div align="right">The {$mgmt:projectName} Team</div>
						)
					)
					,
					response:set-status-code(400)
				) else (
					(: TODO: return checks :)
					system:as-user($mgmt:adminUser,$mgmt:adminPass,
						util:catch("*",
							(: Write code here! :)
							let $emp1 := mgmt:changeServerOwnership($oldOwnerId,$serverId,$newOwnerId,$answer)
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' Server Ownership Change Decision'),
									(
										<div align="center">
											<h1 style="color:green">Using request</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:green">you have {if($answer) then 'approved' else 'rejected'} server ownership change request</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(200)
							),
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC change server ownership ({$oldOwnerId}, {$serverId}, {$newOwnerId}, {$answer}) job: {$util:exception-message}.</error>)
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' Server Ownership Change Confirmation Error'),
									(
										<div align="center">
											<h1 style="color:red">The confirmation URL for server ownership change</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:red">had problems with its request</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(500)
							)
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
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' User Creation Decision'),
									(
										<div align="center">
											<h1 style="color:green">Using request</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:green">you have {if($answer) then 'approved' else 'rejected'} user creation request</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(200)
							),
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC user creation confirmation ({$id}, {$answer}) job: {$util:exception-message}.</error>)
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' User Creation Error'),
									(
										<div align="center">
											<h1 style="color:red">The confirmation URL for user creation confirmation</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:red">has fired some problem in the server</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(500)
							)
						)
					)
				) else (
					(: TODO: return checks :)
					(: Mail confirmation :)
					system:as-user($mgmt:adminUser,$mgmt:adminPass,
						util:catch("*",
							(: Write code here! :)
							let $emp1 := mgmt:confirmEMail($id,$mailId,$answer)
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' e-Mail Validation Decision'),
									(
										<div align="center">
											<h1 style="color:green">Using request</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:green">you have {if($answer) then 'approved' else 'rejected'} the ownership of e-mail address</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(200)
							),
							let $emp2 := util:log-app("error","xcesc.cron",<error>An error occurred on XCESC change server ownership ({$id}, {$mailId}, {$answer}) job: {$util:exception-message}.</error>)
							return (
								util:declare-option('exist:serialize',"method=xhtml media-type=text/html process-xsl-pi=no"),
								gui:integrate-contents(
									concat($mgmt:projectName,' e-Mail Validation Error'),
									(
										<div align="center">
											<h1 style="color:red">The confirmation URL for e-mail ownership confirmation</h1>
											<h2>{$fullRequest}</h2>
											<h1 style="color:red">has fired some problem in the server</h1>
										</div>
										,
										<div align="right">The {$mgmt:projectName} Team</div>
									)
								)
								,
								response:set-status-code(500)
							)
						)
					)
				)
			)
	)
