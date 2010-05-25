(: XQuery main module :)

xquery version "1.0" encoding "UTF-8";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

let $tokens := tokenize($exist:path,'/')
let $matches := for $token at $tokenpos in $tokens
return
	if(matches($token, '\.xq(l|ws)?$')) then (
		$tokenpos
	) else
		()
let $nummatches := count($matches)
let $subpath := string-join(subsequence($tokens,$matches[1]),'/')
return
if (not(starts-with($exist:path , '/'))) then
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
else if (not($tokens = 'controller.xql') and $nummatches > 0) then
	<exist:dispatch>
		<exist:forward url="{$exist:prefix}/{$subpath}"/>
	</exist:dispatch>
else
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
