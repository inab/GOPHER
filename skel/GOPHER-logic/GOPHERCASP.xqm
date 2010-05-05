(:
	GOPHERCASP.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace casp="http://www.cnio.es/scombio/gopher/1.0/xquery/jobManagement/GOPHERCASP";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace gmod="http://www.cnio.es/scombio/gopher/1.0/xquery/javaModule" at "java:org.cnio.scombio.jmfernandez.GOPHER.GOPHERModule";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace job="http://www.cnio.es/scombio/xcesc/1.0/xquery/jobManagement" at "xmldb:exist:///db/XCESC-logic/jobManagement.xqm";

(: Binary FASTA files :)
declare variable $casp:pdbfile as xs:string := 'filtered-pdb.fas';
declare variable $casp:pdbprefile as xs:string := 'filtered-pdbpre.fas';
declare variable $casp:blastReportFile as xs:string := 'blastReport.txt';
declare variable $casp:PREPDB as xs:string := $job:configRoot/job:custom[@key='PREPDB_PATH'][1]/string();
declare variable $casp:PREPDBURI as xs:anyURI := xs:anyURI($job:configRoot/job:custom[@key='PREPDB_URI'][1]/string());
declare variable $casp:PDB as xs:string := $job:configRoot/job:custom[@key='PDB_PATH'][1]/string();
declare variable $casp:dynCoreJar as xs:string := $job:configRoot/job:custom[@key='dynCoreJar'][1]/string();
declare variable $casp:dynCoreQueryMethod as xs:string := $job:configRoot/job:custom[@key='dynCoreQueryMethod'][1]/string();
declare variable $casp:dynCoreSeedMethod as xs:string := $job:configRoot/job:custom[@key='dynCoreSeedMethod'][1]/string();

(:
	This function calls the underlying implementation to generate the seed further used
	to generate the queries
:)
declare function casp:doSeed($physicalScratch as xs:string)
	as document-node(element(xcesc:experiment))
{
	(: Sixth, let's compute the unique entries :)
	gmod:generate-seed(
		$casp:dynCoreJar,
		$casp:dynCoreSeedMethod,
		$casp:PREPDBURI,
		$casp:PDB,
		$casp:pdbprefile,
		$casp:pdbfile,
		$physicalScratch,
		$job:configRoot/job:custom[@key='ENV'][1]/env,
		$job:configRoot/job:custom[@key='CONFIG'][1]/config
	)
};

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function casp:doQueriesComputation($lastCol as xs:string,$newCol as xs:string,$physicalScratch as xs:string)
	as document-node(element(xcesc:experiment))
{
	let $oldpdb:=string-join(($lastCol,xmldb:encode($casp:pdbfile)),'/')
	let $oldpdbpre:=string-join(($lastCol,xmldb:encode($casp:pdbprefile)),'/')
	let $newpdb:=string-join(($newCol,xmldb:encode($casp:pdbfile)),'/')
	let $newpdbpre:=string-join(($newCol,xmldb:encode($casp:pdbprefile)),'/')
	(: Sixth, let's compute the unique entries :)
	return
		gmod:compute-unique-entries(
			$casp:dynCoreJar,
			$casp:dynCoreQueryMethod,
			$oldpdbpre,
			$oldpdb,
			$casp:PREPDBURI,
			$casp:PDB,
			$physicalScratch,
			$job:configRoot/job:custom[@key='ENV'][1]/env,
			$job:configRoot/job:custom[@key='CONFIG'][1]/config
		)
};
