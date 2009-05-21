xquery version "1.0";

(:
	$Id$
:)

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

if xmldb:exists-user("@USER@") then (
	let $prevgroups := xmldb:get-user-groups("@USER@")
	let $prevhome := xmldb:get-user-home("@USER@")
	xmldb:change-user("@USER@","@PASS@",($prevgroups,"@GROUP@"),$prevhome)
) else
	xmldb:create-user("@USER@","@PASS@",("@GROUP@"),())
