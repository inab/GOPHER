(: XQuery main module :)

xquery version "1.0" encoding "UTF-8";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

if (not(starts-with($exist:path , '/'))) then
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
else if (not($exist:resource eq 'controller.xql') and matches($exist:resource, '\.xq(l|ws)?$')) then
	if(empty(xmldb:get-permissions('/db/XCESC-logic',$exist:resource))) then (
		<exist:dispatch>
			<exist:redirect url="/"/>
		</exist:dispatch>
	) else (
		<exist:dispatch>
			<exist:forward url="/{$exist:resource}"/>
		</exist:dispatch>
	)
else
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
