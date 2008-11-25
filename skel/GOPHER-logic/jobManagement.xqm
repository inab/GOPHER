(:
	jobManagement.xqm
:)
xquery version "1.0";

module namespace job="http://www.cnio.es/scombio/gopher/1.0/xquery/jobManagement";

import module namespace mgmt="http://www.cnio.es/scombio/gopher/1.0/xquery/systemManagement" at "systemManagement.xqm";
import module namespace gmod="http://www.cnio.es/scombio/gopher/1.0/xquery/javaModule" at "java:org.cnio.scombio.jmfernandez.GOPHER.GOPHERModule";

declare namespace httpclient="http://exist-db.org/xquery/httpclient";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace gopher="http://www.cnio.es/scombio/gopher/1.0";

(: The results collection :)
declare variable $job:resultsBaseCol as xs:string := 'rounds'; 
declare variable $job:resultsCol as xs:string := string-join(($mgmt:mgmtCol,$job:resultsBaseCol),'/');

(: Last round document :)
declare variable $job:lastRoundDoc as xs:string := 'lastRound.xml';
declare variable $job:lastRoundDocPath  as xs:string := string-join(($job:resultsCol,$job:lastRoundDoc),'/');

(: Binary FASTA files :)
declare variable $job:pdbfile as xs:string := 'filtered-pdb.fas';
declare variable $job:pdbprefile as xs:string := 'filtered-pdbpre.fas';
declare variable $job:blastReportFile as xs:string := 'blastReport.txt';
declare variable $job:physicalScratch as xs:string := '/tmp';

(: Queries document :)
declare variable $job:queriesDoc as xs:string := 'roundData.xml';

(: BaseURL :)
declare variable $job:logicCol as xs:string := 'GOPHER-logic';
declare variable $job:pobox as xs:string := 'pobox.xql';
declare variable $job:poboxURI as xs:string := string-join(('http://localhost:8088',$job:logicCol,$job:pobox),'/');

(:::::::::::::::::::::::)
(: Last Round Document :)
(:::::::::::::::::::::::)

declare function job:getLastRoundDocument()
	as element(gopher:lastRound)
{
	if(doc-available($job:lastRoundDocPath)) then (
		doc($job:lastRoundDocPath)/element()
	) else (
		let $newDoc := <gopher:lastRound date=""/>
		return doc(xmldb:store($job:resultsCol,$job:lastRoundDoc,$newDoc,'application/xml'))/element()
	)
};

(: Next round task :)

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function job:doQueriesComputation($currentDateTime as xs:dateTime)
	as element(gopher:experiment)
{
	(# exist:batch-transaction #) {
		(: First, get the last round document :)
		let $currentDate:=xs:date($currentDateTime)
		let $lastDoc:=job:getLastRoundDocument()
		(: Third, snapshot of last round's date :)
		let $lastDateTime:=$lastDoc/@timeStamp
		let $lastDate:=xs:date($lastDateTime)
		let $lastCol:=string-join(($job:resultsCol,$lastDate),'/')
		let $oldpdb:=string-join(($lastCol,$job:pdbfile),'/')
		let $oldpdbpre:=string-join(($lastCol,$job:pdbprefile),'/')
		let $roundCol:=xmldb:create-collection($job:resultsCol,$currentDate)
		let $newCol:=string-join(($job:resultsCol,$currentDate),'/')
		let $newpdb:=string-join(($newCol,$job:pdbfile),'/')
		let $newpdbpre:=string-join(($newCol,$job:pdbprefile),'/')
		let $physicalScratch:=string-join(($job:physicalScratch,$currentDate),'/')
		(: Sixth, let's compute the unique entries :)
		let $queriesDoc:=gmod:compute-unique-entries($oldpdbpre,$oldpdb,$physicalScratch)
		(: Seventh, time to store and update! :)
		let $stored:=xmldb:store-files-from-pattern($newCol,$physicalScratch,'*')
		let $storedExperiment:=xmldb:store($newCol,$job:queriesDoc,$queriesDoc,'application/xml')/element()
		return
			update value $lastDoc/@timeStamp with $currentDateTime,
			update insert (attribute stamp { $currentDateTime }, attribute baseStamp { $lastDateTime }) into $storedExperiment,
			$storedExperiment
	}
};

declare function job:doRound($currentDate as xs:date,$storedExperiment as element(gopher:experiment),$onlineServers as element(gopher:server)*)
	as empty()
{
	(: Fourth, get online servers based on currentDateTime :)
	let $querySet:=$storedExperiment//gopher:query
	let $jobs:=for $job in $querySet
		return <gopher:job targetId="{$job/@id}" status="submitted"/>
	(: Fifth, submit jobs!!!! :)
	for $onlineServer in $onlineServers
		let $ticketId:=util:uuid()
		let $poboxURI := string-join(($job:poboxURI,$currentDate,$ticketId),'/')
		let $queries:=<gopher:queries callback="{$poboxURI}">{$querySet}</gopher:queries>		 
		let $sendDateTime:=current-dateTime()
		let $ret:=httpclient:post($onlineServer/@uri,$queries,false,())
	return
		(# exist:batch-transaction #) {
			update insert <gopher:participant ticket="{$ticketId}" startStamp="{$sendDateTime}">
			{$onlineServer}
			{
				if($ret/@statusCode='200') then
					$jobs
				else
					<gopher:errorMessage statusCode="$ret/@statusCode">{$ret/httpclient:body/*}</gopher:errorMessage>
			}
			</gopher:participant>  into $storedExperiment
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

declare function job:doTestRound($baseRound as xs:string,$servers as element(gopher:server)+)
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

declare function job:joinResults($round as xs:string,$ticket as xs:string,$answers as gopher:answers)
	as xs:positiveInteger
{
	(# exist:batch-transaction #) {
		let $partElem:=doc(string-join(($job:resultsCol,$round,$job:queriesDoc),'/'))//gopher:participant[@ticket=$ticket]
		return
			if(exists($partElem)) then
				(
				for $answer in $answers//gopher:answer,$job in $partElem//gopher:job[@targetId=$answer/@targetId]
				let $matches:=$answer//gopher:match
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