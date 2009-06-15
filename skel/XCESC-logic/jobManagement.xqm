(:
	jobManagement.xqm
:)
xquery version "1.0";

module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";

(: The results collection :)
declare variable $job:dataCol as xs:string := concat(('/db/',collection($mgmt:configCol)//job:jobManagement[1]/@collection/string()));
declare variable $job:resultsBaseCol as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/@roundsSubCollection/string();
declare variable $job:resultsCol as xs:string := string-join(($job:dataCol,$job:resultsBaseCol),'/');

(: Last round document :)
declare variable $job:lastRoundDoc as xs:string := 'lastRound.xml';
declare variable $job:lastRoundDocPath  as xs:string := string-join(($job:resultsCol,$job:lastRoundDoc),'/');

(: Scratch dir and storage patterns :)
declare variable $job:physicalScratch as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/@physicalScratch/string();

(: Queries document :)
declare variable $job:queriesDoc as xs:string := 'roundData.xml';

(: BaseURL :)
declare variable $job:logicCol as xs:string := 'XCESC-logic';
declare variable $job:pobox as xs:string := 'pobox.xq';
declare variable $job:poboxURI as xs:string := string-join(($mgmt:publicBaseURI,$job:logicCol,$job:pobox),'/');
declare variable $job:evapobox as xs:string := 'evapobox.xql';
declare variable $job:evaURI as xs:string := string-join(($mgmt:publicBaseURI,$job:logicCol,$job:evapobox),'/');

(: Misc :)
declare variable $job:partServer as xs:string := "participant";

(:::::::::::::::::::::::)
(: Last Round Document :)
(:::::::::::::::::::::::)

declare function job:getLastRoundDocument()
	as element(xcesc:lastRound)
{
	if(doc-available($job:lastRoundDocPath)) then (
		doc($job:lastRoundDocPath)/element()
	) else (
		let $newDoc := <xcesc:lastRound date=""/>
		return doc(xmldb:store($job:resultsCol,$job:lastRoundDoc,$newDoc,'application/xml'))/element()
	)
};

(: Next round task :)

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function job:doQueriesComputation($currentDateTime as xs:dateTime)
	as element(xcesc:experiment)
{
	(# exist:batch-transaction #) {
		(: First, get the last round document :)
		let $currentDate:=xs:date($currentDateTime)
		let $lastDoc:=job:getLastRoundDocument()
		(: Third, snapshot of last round's date :)
		let $lastDateTime:=$lastDoc/@timeStamp
		let $lastDate:=xs:date($lastDateTime)
		let $lastCol:=string-join(($job:resultsCol,$lastDate),'/')
		let $physicalScratch:=string-join(($job:physicalScratch,$currentDate),'/')
		let $roundCol:=xmldb:create-collection($job:resultsCol,$currentDate)
		let $newCol:=string-join(($job:resultsCol,$currentDate),'/')
		
		let $queriesComputation := collection($mgmt:configCol)//job:jobManagement[1]/job:queriesComputation
		let $dynLoad := util:import-module($queriesComputation/@namespace,'dyn',$queriesComputation/@module),
			util:function(QName($queriesComputation/@namespace,$queriesComputation/@entryPoint),3)
		(: Sixth, let's compute the unique entries :)
		let $queriesDoc := util:call($dynLoad,$lastCol,$newCol,$physicalScratch)
		
		(: Seventh, time to store and update! :)
		let $stored:=xmldb:store-files-from-pattern($newCol,$physicalScratch,$queriesComputation/@storagePattern)
		let $storedExperiment:=xmldb:store($newCol,$job:queriesDoc,$queriesDoc,'application/xml')/element()
		return
			update value $lastDoc/@timeStamp with $currentDateTime,
			update insert (attribute stamp { $currentDateTime }, attribute baseStamp { $lastDateTime }) into $storedExperiment,
			$storedExperiment
	}
};

declare function job:doRound($currentDate as xs:date,$storedExperiment as element(xcesc:experiment),$onlineServers as element(xcesc:server)*)
	as empty()
{
	(: Fourth, get online servers based on currentDateTime :)
	let $querySet:=$storedExperiment//xcesc:query
	let $targetSet:=$storedExperiment//xcesc:target
	let $jobs:=for $job in $querySet
		return <xcesc:job targetId="{$job/@queryId}" status="submitted"/>
	(: Fifth, submit jobs!!!! :)
	for $onlineServer in $onlineServers
		let $ticketId:=util:uuid()
		let $poboxURI := string-join(($job:poboxURI,$currentDate,$ticketId),'/')
		let $queries:=if($onlineServer/@type=$job:partServer) then
			return <xcesc:queries callback="{$poboxURI}">{$querySet}</xcesc:queries>
		else
			return <xcesc:toEvaluate callback="{$poboxURI}">{$targetSet}</xcesc:toEvaluate>
		let $sendDateTime:=current-dateTime()
		let $ret:=httpclient:post($onlineServer/@uri,$queries,false,())
	return
		(# exist:batch-transaction #) {
			update insert <xcesc:participant ticket="{$ticketId}" startStamp="{$sendDateTime}">
			{$onlineServer}
			{
				if($ret/@statusCode='200' or $ret/@statusCode='202') then
					$jobs
				else
					<xcesc:errorMessage statusCode="$ret/@statusCode">{$ret/httpclient:body/*}</xcesc:errorMessage>
			}
			</xcesc:participant>  into $storedExperiment
		}
};

declare function job:doNextRound()
	as empty()
{
	(: Fourth, get online servers based on currentDateTime :)
	let $currentDateTime:=current-dateTime()
	return
		job:doRound(xs:date($currentDateTime),job:doQueriesComputation($currentDateTime),mgmt:getOnlineServers($currentDateTime))
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
	let $baseCol:=string-join(($job:resultsCol,$baseRound),'/')
	let $newCol:=string-join(($job:resultsCol,$newRound),'/')
	let $empty:=xmldb:copy($baseCol,$newCol)
	let $newRoundsDoc := doc(string-join(($newCol,$job:queriesDoc),'/'))/element()
	let $empty2 := (# exist:batch-transaction #) {
		update value $newRoundsDoc/@baseStamp with $newRoundsDoc/@stamp,
		update value $newRoundsDoc/@stamp with current-dateTime(),
		if(empty($newRoundsDoc/@test)) then
			update insert attribute test { true } into $newRoundsDoc
		else
			()
	}
	let $empty3 := job:doRound($newRound,$newRoundsDoc,$servers) 
		return $newRound
};

declare function job:joinResults($round as xs:string,$ticket as xs:string,$answers as xcesc:answers)
	as xs:positiveInteger
{
	(# exist:batch-transaction #) {
		let $partElem:=doc(string-join(($job:resultsCol,$round,$job:queriesDoc),'/'))//xcesc:participant[@ticket=$ticket]
		return
			if(exists($partElem)) then
				(
				for $answer in $answers//xcesc:answer,$job in $partElem//xcesc:job[@targetId=$answer/@targetId]
				let $matches:=$answer//xcesc:match
				return
					(
						update insert attribute stopStamp { current-dateTime() } into $job,
						update value $job/@status with 'finished',
						if(exists($answer/@message)) then
							update insert attribute lastMessage { $answer/@message } into $job
						else
							()
						,
						if(exists($matches)) then
							update insert $matches into $job
						else
							()
					) 
				),200
			else
				404
	}
};
