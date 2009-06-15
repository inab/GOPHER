xquery version "1.0";

(:
	$Id$
:)

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

if ( xmldb:exists-user("@USER@") ) then (
	let $prevgroups := xmldb:get-user-groups("@USER@")
	let $prevhome := xmldb:get-user-home("@USER@")
	let $groups := tokenize("@GROUPS@", ",\s*")
	return
		xmldb:change-user("@USER@","@PASS@",distinct-values(($prevgroups,$groups)),$prevhome)
) else
	xmldb:create-user("@USER@","@PASS@",distinct-values(tokenize("@GROUPS@", ",\s*")),())
