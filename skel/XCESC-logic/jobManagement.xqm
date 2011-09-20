(:
	jobManagement.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";

import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace core = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/core' at 'xmldb:exist:///db/XCESC-logic/core.xqm';
import module namespace upd = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/XQueryUpdatePrimitives' at 'xmldb:exist:///db/XCESC-logic/XQueryUpdatePrimitives.xqm';
import module namespace mgmt = "http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";

(:
declare variable $job:configRoot as element(job:jobManagement) := collection($core:configColURI)//job:jobManagement[1];
:)
declare variable $job:configRoot as element(job:jobManagement) := subsequence(collection($core:configColURI)//job:jobManagement,1,1);

(: Deadlines :)
declare variable $job:intervalBeforeAssessment as xs:dayTimeDuration := xs:dayTimeDuration($job:configRoot/@intervalBeforeAssessment/string());
declare variable $job:participantDeadline as xs:dayTimeDuration := xs:dayTimeDuration($job:configRoot/@participantDeadline/string());
declare variable $job:evaluatorDeadline as xs:dayTimeDuration := xs:dayTimeDuration($job:configRoot/@evaluatorDeadline/string());

(: The results collection :)
declare variable $job:dataCol as xs:string := concat('/db/',$job:configRoot/@collection/string());
declare variable $job:resultsBaseCol as xs:string := $job:configRoot/@roundsSubCollection/string();
declare variable $job:resultsCol as xs:string := string-join(($job:dataCol,$job:resultsBaseCol),'/');
declare variable $job:resultsColURI as xs:string := xmldb:encode($job:resultsCol);

(: Last round document :)
declare variable $job:lastRoundDoc as xs:string := 'lastRound.xml';
declare variable $job:lastRoundDocURI as xs:string := xmldb:encode($job:lastRoundDoc);
declare variable $job:lastRoundDocPath as xs:string := string-join(($job:resultsCol,$job:lastRoundDoc),'/');
declare variable $job:lastRoundDocPathURI as xs:string := xmldb:encode($job:lastRoundDocPath);

(: Scratch dir and storage patterns :)
declare variable $job:physicalScratch as xs:string := $job:configRoot/@physicalScratch/string();

(: Queries document :)
declare variable $job:queriesDoc as xs:string := 'roundData.xml';
declare variable $job:queriesDocURI as xs:string := xmldb:encode($job:queriesDoc);
declare variable $job:assessPrefix as xs:string := 'assess-';
declare variable $job:assessPostfix as xs:string := '.xml';

(: BaseURL :)
declare variable $job:pobox as xs:string := 'pobox.xq';
declare variable $job:poboxURI as xs:string := string-join(($mgmt:publicBaseURI,$core:relLogicCol,$job:pobox),'/');
declare variable $job:evapobox as xs:string := 'evapobox.xql';
declare variable $job:evaURI as xs:string := string-join(($mgmt:publicBaseURI,$core:relLogicCol,$job:evapobox),'/');

(:::::::::::::::::::::::)
(: Last Round Document :)
(:::::::::::::::::::::::)

declare function job:getLastRoundDocument()
	as element(xcesc:lastRound)
{
	if(doc-available($job:lastRoundDocPathURI)) then (
		doc($job:lastRoundDocPathURI)/element()
	) else (
		let $newDoc := <xcesc:lastRound date=""/>
		return doc(xmldb:store($job:resultsColURI,$job:lastRoundDocURI,$newDoc,'application/xml'))/element()
	)
};

(: Next round task :)

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function job:plantSeed()
	as xs:dateTime
{
	(: (# exist:batch-transaction #) { :)
		(: First, get the last round document :)
		let $currentDateTime := current-dateTime()
		let $currentDateStr :=xs:string(xs:date($currentDateTime))
		let $lastDoc := job:getLastRoundDocument()
		(: Third, snapshot of last round's date :)
		let $lastDateTime := $lastDoc/@timeStamp
		let $lastDateStr:=xs:string(xs:date($lastDateTime))
		let $lastCol:=xmldb:encode(string-join(($job:resultsCol,$lastDateStr),'/'))
		let $physicalScratch:=string-join(($job:physicalScratch,$currentDateStr),'/')
		let $newCol:=xmldb:create-collection($job:resultsColURI,xmldb:encode($currentDateStr))
		
		let $queriesComputation := collection($core:configColURI)//job:jobManagement[1]/job:queriesComputation
		let $imod := util:import-module($queriesComputation/@namespace,'dyn',$queriesComputation/@module)
		(: Sixth, let's compute the unique entries :)
		let $queriesDoc := util:eval(concat("dyn:",xmldb:encode($queriesComputation/@seedEntryPoint),"($physicalScratch)"))
		
		(: Seventh, time to store and update! :)
		let $stored := xmldb:store-files-from-pattern($newCol,$physicalScratch,$queriesComputation/@storagePattern)
		(:
		let $storedExperiment:=doc(xmldb:store($newCol,$job:queriesDocURI,$queriesDoc,'application/xml'))/element()
		:)
		return (
			upd:replaceValue($lastDoc/@timeStamp,$currentDateTime),
			(:
			upd:insertInto($storedExperiment,(attribute stamp { $currentDateTime }, attribute baseStamp { $lastDateTime })),
			:)
			$currentDateTime
		)
	(: } :)
};

(:
	This function calls the underlying implementation to calculate the baseline
	from the queries, and then it attaches the baseline to the queries document
:)
declare function job:addBaseline($storedExperiment as element(xcesc:experiment))
	as element(xcesc:experiment)
{
	(: TODO :)
};

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function job:doQueriesComputation($currentDateTime as xs:dateTime)
	as element(xcesc:experiment)
{
	(: (# exist:batch-transaction #) { :)
		(: First, get the last round document :)
		let $currentDateStr:=xs:string(xs:date($currentDateTime))
		let $lastDoc:=job:getLastRoundDocument()
		(: Third, snapshot of last round's date :)
		let $lastDateTime:=$lastDoc/@timeStamp
		let $lastDateStr:=xs:string(xs:date($lastDateTime))
		let $lastCol:=xmldb:encode(string-join(($job:resultsCol,$lastDateStr),'/'))
		let $physicalScratch:=string-join(($job:physicalScratch,$currentDateStr),'/')
		let $newCol:=xmldb:create-collection($job:resultsColURI,xmldb:encode($currentDateStr))
		
		let $queriesComputation := collection($core:configColURI)//job:jobManagement[1]/job:queriesComputation
		let $imod := util:import-module($queriesComputation/@namespace,'dyn',$queriesComputation/@module)
		(: Sixth, let's compute the unique entries :)
		let $queriesDoc := util:eval(concat("dyn:",xmldb:encode($queriesComputation/@queryEntryPoint),"($lastCol,$newCol,$physicalScratch)"))
		
		(: Seventh, time to store and update! :)
		let $stored := xmldb:store-files-from-pattern($newCol,$physicalScratch,$queriesComputation/@storagePattern)
		let $storedExperiment := job:addBaseline(doc(xmldb:store($newCol,$job:queriesDocURI,$queriesDoc,'application/xml'))/element())
		return (
			upd:replaceValue($lastDoc/@timeStamp,$currentDateTime)
			,
			upd:insertInto($storedExperiment, (
					attribute name { $currentDateTime },
					attribute isAssessed { false() },
					attribute stamp { $currentDateTime },
					attribute baseStamp { $lastDateTime },
					attribute deadline { $currentDateTime + $job:participantDeadline }
				)
			)
		)
		
	(: } :)
};

declare function job:doRound($currentRound as xs:string,$storedExperiment as element(xcesc:experiment),$onlineServers as element(xcesc:server)*)
	as empty-sequence()
{
	(: Fourth, get online servers based on currentDateTime :)
	let $querySet:=$storedExperiment//xcesc:query
	(: Fifth, submit jobs!!!! :)
	let $basePobox := string-join(($job:poboxURI,$currentRound),'/')
	for $onlineServer in $onlineServers
		let $ticketId:=util:uuid()
		let $poboxURI := string-join(($basePobox,$ticketId),'/')
		let $queries := <xcesc:queries callback="{$poboxURI}">{$querySet}</xcesc:queries>
		let $sendDateTime:=current-dateTime()
		let $ret:=httpclient:post($onlineServer/@uri,$queries,false(),())
		let $acceptedQueries := $ret/httpclient:body/*[1]
		let $startDateTime := if(exists($acceptedQueries/@timeStamp)) then
				$acceptedQueries/@timeStamp/string()
			else
				$sendDateTime 
	return (
		(: (# exist:batch-transaction #) { :)
			upd:insertInto($storedExperiment,<xcesc:participant ticket="{$ticketId}" startStamp="{$startDateTime}">
				{$onlineServer}
				{
					if($ret/@statusCode eq '200' or $ret/@statusCode eq '202') then
						for $accepted in $querySet[@queryId = $acceptedQueries//@queryId]
							return <xcesc:job targetId="{$accepted/@queryId}" status="submitted"/>
					else
						<xcesc:errorMessage statusCode="$ret/@statusCode">{$ret/httpclient:body/*}</xcesc:errorMessage>
				}
				</xcesc:participant>
			) 
		(: } :)
	)
};

declare function job:doNextRound()
	as empty-sequence()
{
	(: Fourth, get online servers based on currentDateTime :)
	let $currentDateTime:=current-dateTime()
	return
		job:doRound(xs:date($currentDateTime),job:doQueriesComputation($currentDateTime),mgmt:getOnlineParticipants($currentDateTime))
};

(:
	This function launches a test round, based on an existing round,
	to a given number of servers (based on their Ids)
:)
declare function job:doTestRound($baseRound as xs:string,$serverIDs as xs:string+)
	as xs:string
{
	job:doTestRound($baseRound,mgmt:getServer($servers))
};

(:
	This function launches a test round, based on an existing round,
	to a given number of servers (based on their Ids)
:)
declare function job:doTestRoundFromNames($baseRound as xs:string,$serverNames as xs:string+)
	as xs:string
{
	job:doTestRound($baseRound,mgmt:getServersFromName($serverNames))
};

declare function job:doTestRound($baseRound as xs:string,$servers as element(xcesc:server)+)
	as xs:string
{
	let $newRound:=util:uuid()
	return job:doTestRound($baseRound,$newRound,$servers)
};

declare function job:doTestRound($baseRound as xs:string,$newRound as xs:string,$servers as element(xcesc:server)+)
	as xs:string
{
	let $newRound:=util:uuid()
	let $baseCol:=string-join(($job:resultsCol,$baseRound),'/')
	let $newCol:=string-join(($job:resultsCol,$newRound),'/')
	let $empty:=xmldb:copy(xmldb:encode($baseCol),xmldb:encode($newCol))
	let $newRoundsDoc := doc(xmldb:encode(string-join(($newCol,$job:queriesDoc),'/')))/element()
	let $empty2 := (: (# exist:batch-transaction #) { :)
	(
		upd:replaceValue($newRoundsDoc/@name , $newRound),
		upd:replaceValue($newRoundsDoc/@baseStamp , $newRoundsDoc/@stamp),
		upd:replaceValue($newRoundsDoc/@stamp , current-dateTime()),
		upd:replaceValue($newRoundsDoc/@deadline , current-dateTime() + $job:participantDeadline) ,
		if(empty($newRoundsDoc/@test)) then (
			upd:insertInto($newRoundsDoc,attribute test { true() }) 
		) else
			()
		,
		upd:replaceValue($newRoundsDoc/@isAssessed , false())
	)
	(: } :)
	let $empty3 := job:doRound($newRound,$newRoundsDoc,$servers) 
	return $newRound
};

declare function job:joinResults($round as xs:string,$ticket as xs:string,$timestamp as xs:dateTime,$answers as element(xcesc:answers))
	as xs:positiveInteger
{
	(: (# exist:batch-transaction #) { :)
		let $expElem:=doc(xmldb:encode(string-join(($job:resultsCol,$round,$job:queriesDoc),'/')))//xcesc:experiment[@name eq $round]
		return
			if (exists($expElem/@deadline) and xs:dateTime($expElem/@deadline) >= $timestamp) then (
				let $partElem:=$expElem/xcesc:participant[@ticket eq $ticket]
				return
					if(exists($partElem)) then (
						(
						for $answer in $answers/xcesc:answer
							let $matches:= (
								(: Match fixing and isolation :)
								for $match in $answer/xcesc:match
								return <xcesc:match source="{$match/@source}" timeStamp="{$timestamp}">{$match/node()}</xcesc:match>
							)
						return
							for $job in $partElem//xcesc:job[@targetId eq $answer/@targetId]
							return
								(
									if(exists($job/@stopStamp)) then
										upd:replaceValue($job/@stopStamp , $timestamp)
									else
										upd:insertInto($job, attribute stopStamp { $timestamp })
									,
									upd:replaceValue($job/@status , 'finished'),
									if(exists($answer/@message)) then
										upd:insertInto($job , attribute lastMessage { $answer/@message }) 
									else
										()
									,
									if(exists($matches)) then
										upd:insertInto($job , $matches)
									else
										()
								)
						),
						if(exists($partElem/@lastStamp)) then
							upd:replaceValue($partElem/@lastStamp , $timestamp)
						else
							upd:insertInto($partElem , attribute lastStamp { $timestamp })
						,
						200
					) else (
						404
					)
			) else (
				403
			)
	(: } :)
};

declare function job:joinAssessments($round as xs:string,$assessmentTicket as xs:string,$evaluatorTicket as xs:string,$timestamp as xs:dateTime,$answers as element(xcesc:answers))
	as xs:positiveInteger
{
	(: (# exist:batch-transaction #) { :)
		let $assessElem:=doc(xmldb:encode(string-join(($job:resultsCol,$round,concat($job:assessPrefix,$assessmentTicket,$job:assessPostfix)),'/')))//xcesc:assessment[@name eq $assessmentTicket]
		return
			if (exists($assessElem/@deadline) and xs:dateTime($assessElem/@deadline) >= $timestamp) then (
				let $evalElem:=$assessElem/xcesc:evaluator[@ticket eq $evaluatorTicket]
				return
					if(exists($evalElem)) then (
						(
						for $answer in $answers/xcesc:answer
							let $matches:= (
								(: Match fixing and isolation :)
								for $match in $answer/xcesc:jobEvaluation
								return <xcesc:jobEvaluation targetId="{$match/@targetId}" timeStamp="{$timestamp}">{$match/node()}</xcesc:jobEvaluation>
							)
						return
							for $job in $evalElem//xcesc:job[@participantTicket eq $answer/@targetId]
							return
								(
									if(exists($job/@stopStamp)) then (
										upd:replaceValue($job/@stopStamp , $timestamp)
									) else (
										upd:insertInto($job , attribute stopStamp { $timestamp })
									),
									upd:replaceValue($job/@status , 'finished'),
									if(exists($answer/@message)) then (
										upd:insertInto($job , attribute lastMessage { $answer/@message })
									) else
										()
									,
									if(exists($matches)) then (
										upd:insertInto($job , $matches) 
									) else
										()
								)
						),
						if(exists($evalElem/@lastStamp)) then
							upd:replaceValue($evalElem/@lastStamp , $timestamp)
						else
							upd:insertInto($evalElem , attribute lastStamp { $timestamp }) 
						,
						200
					) else (
						404
					)
			) else (
				403
			)
	(: } :)
};

declare function job:doAssessment($currentAssessment as xs:string,$round as xs:string,$onlineServers as element(xcesc:server)*,$dateTime as xs:dateTime,$isTest as xs:boolean)
	as empty-sequence()
{
	(: Assessment skeleton :)
	let $storedAssessment := doc(
		xmldb:store(
			string-join(($job:resultsCol,$round),'/'),
			concat($job:assessPrefix,$currentAssessment,$job:assessPostfix),
			<xcesc:assessment stamp="{$dateTime}" name="{$currentAssessment}" test="{$isTest}" deadline="{$dateTime + $job:evaluatorDeadline}"></xcesc:assessment>,
			'application/xml'
		)
	)/element()
	(: Fourth, get online servers based on currentDateTime :)
	let $storedExperimentDoc := doc(string-join(($job:resultsColURI,xmldb:encode($round),$job:queriesDocURI),'/'))
	let $storedExperiment := job:addBaseline($storedExperimentDoc/element())
	let $commonSet := ()
	let $targetSet := (
		for $participant in $storedExperiment//xcesc:participant
		return
			<xcesc:query queryId="{$participant/@ticket}">{
				for $target in $storedExperiment/xcesc:experiment/xcesc:target
				let $queryId := $target/xcesc:query/@queryId
				return
					<xcesc:answer targetId="{$queryId}">
						<xcesc:target id="{$target/@id}" namespace="{$target/@namespace}" description="{$target/@description}">
							{$target/@kind}
							{$target/node()}
							{$baseline}
						</xcesc:target>
						{$participant/xcesc:job[@targetId eq $queryId]/xcesc:match}
					<xcesc:answer>
			}</xcesc:query>
	)
	(: Fifth, submit jobs!!!! :)
	let $basePobox := string-join(($job:evaURI,$round,$currentAssessment),'/')
	for $onlineServer in $onlineServers
		let $ticketId:=util:uuid()
		let $poboxURI := string-join(($basePobox,$ticketId),'/')
		let $queries := <xcesc:queries callback="{$poboxURI}">{$commonSet}{$targetSet}</xcesc:queries>
		let $sendDateTime:=current-dateTime()
		let $ret:=httpclient:post($onlineServer/@uri,$queries,false(),())
		let $acceptedQueries := $ret/httpclient:body/*[1]
		let $startDateTime := if(exists($acceptedQueries/@timeStamp)) then
				$acceptedQueries/@timeStamp/string()
			else
				$sendDateTime 
	return (
		(: (# exist:batch-transaction #) { :)
			upd:insertInto($storedAssessment , <xcesc:evaluator ticket="{$ticketId}" startStamp="{$startDateTime}">
				{$onlineServer}
				{
					if($ret/@statusCode eq '200' or $ret/@statusCode eq '202') then
						for $accepted in $storedExperiment//xcesc:participant[@ticket = $acceptedQueries//@queryId]
							return <xcesc:job targetId="{$accepted/@ticket}" status="submitted"/>
					else
						<xcesc:errorMessage statusCode="$ret/@statusCode">{$ret/httpclient:body/*}</xcesc:errorMessage>
				}
				</xcesc:evaluator>
			)
	)
		(: } :)
};

declare function job:issueAssessments()
	as empty-sequence()
{
	let $currentDateTime:=current-dateTime()
	for $unassessed in collection($job:resultsColURI)//xcesc:experiment[not(@test)][not(@isAssessed)][($currentDateTime - xs:dateTime(@stamp)) > $job:intervalBeforeAssessment]
		let $rcol := tokenize(base-uri($unassessed),'/')[last()-1]
		let $assessmentTicket:=util:uuid()
		let $assess := job:doAssessment($assessmentTicket,$rcol,mgmt:getOnlineEvaluators($currentDateTime),$currentDateTime,false())
	return
		upd:replaceValue($unassessed/@isAssessed , true())
};
