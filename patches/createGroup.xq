xquery version "1.0";

(:
	$Id$
:)

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

let $group := "@GROUP@"
let $groupController := "@GROUPCONTROLLER@"
return
	if(not(xmldb:group-exists($group))) then (
		xmldb:create-group($group,$groupController)
	) else (
	)
