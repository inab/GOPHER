xquery version "1.0";

(:
	$Id$
:)

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

let $groups := tokenize("@GROUPS@", ",\s*")
let $gcr := (
	for $group in $groups
	return
		(: Creating non-existent groups :)
		if(not(xmldb:group-exists($group))) then (
			xmldb:create-group($group,"@GROUPCONTROLLER@")
		) else (
		)
	)
return
	if ( xmldb:exists-user("@USER@") ) then (
		let $prevgroups := xmldb:get-user-groups("@USER@")
		let $prevhome := xmldb:get-user-home("@USER@")
		return
			xmldb:change-user("@USER@","@PASS@",distinct-values(($prevgroups,$groups)),$prevhome)
	) else (
		xmldb:create-user("@USER@","@PASS@",distinct-values(tokenize("@GROUPS@", ",\s*")),())
	)
