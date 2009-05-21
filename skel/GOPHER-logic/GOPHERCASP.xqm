(:
	GOPHERCASP.xqm
:)
xquery version "1.0";

module namespace casp="http://www.cnio.es/scombio/gopher/1.0/xquery/jobManagement/GOPHERCASP";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace gmod="http://www.cnio.es/scombio/gopher/1.0/xquery/javaModule" at "java:org.cnio.scombio.jmfernandez.GOPHER.GOPHERModule";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace httpclient="http://exist-db.org/xquery/httpclient";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: Binary FASTA files :)
declare variable $casp:pdbfile as xs:string := 'filtered-pdb.fas';
declare variable $casp:pdbprefile as xs:string := 'filtered-pdbpre.fas';
declare variable $casp:blastReportFile as xs:string := 'blastReport.txt';
declare variable $casp:PREPDB as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/job:custom[@key='PREPDB_PATH'][1]/string();
declare variable $casp:PDB as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/job:custom[@key='PDB_PATH'][1]/string();
declare variable $casp:dynCoreJar as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/job:custom[@key='dynCoreJar'][1]/string();
declare variable $casp:dynCoreMethod as xs:string := collection($mgmt:configCol)//job:jobManagement[1]/job:custom[@key='dynCoreMethod'][1]/string();

(:
	This function calls the underlying implementation to calculate the queries,
	and then it stores them and the queries document
:)
declare function casp:doQueriesComputation($lastCol as xs:string,$newCol as xs:string,$physicalScratch as xs:string)
	as document-node(element(xcesc:experiment))
{
		let $oldpdb:=string-join(($lastCol,$casp:pdbfile),'/')
		let $oldpdbpre:=string-join(($lastCol,$casp:pdbprefile),'/')
		let $newpdb:=string-join(($newCol,$casp:pdbfile),'/')
		let $newpdbpre:=string-join(($newCol,$casp:pdbprefile),'/')
		(: Sixth, let's compute the unique entries :)
		return
			gmod:compute-unique-entries($casp:dynCoreJar,$casp:dynCoreMethod,$oldpdbpre,$oldpdb,$casp:PREPDB,$casp:PDB,$physicalScratch)
};
