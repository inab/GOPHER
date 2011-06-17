xquery version "1.0";

(:
	$Id$
:)

declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

let $suffixes := tokenize("@SUFFIXLIST@", ",\s*")
let $colname := "@COLNAME@"
let $perm := @PERM@
for $doc in collection($colname)
let $docname := util:document-name($doc)
	for $suffix in $suffixes
	return
		if(ends-with($docname,$suffix)) then (
			xmldb:chmod-resource($colname,$docname,$perm)
		) else (
		)