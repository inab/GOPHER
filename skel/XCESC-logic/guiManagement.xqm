(:
	guiManagement.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace gui="http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace core = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/core' at 'xmldb:exist:///db/XCESC-logic/core.xqm';
import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";

(: Don't forget the starting slash! :)
declare variable $gui:guiDoc as element(gui:guiManagement) := collection($core:configColURI)//gui:guiManagement[1];
declare variable $gui:AtomicRoot as xs:string := concat('/',$gui:guiDoc/@AtomicWiki-logic/string());
declare variable $gui:AtomicVirtualRoot as xs:string := concat('/',$gui:guiDoc/@AtomicWiki-VirtualRoot/string());
declare variable $gui:realm as xs:string := concat('/',$gui:guiDoc/@realm/string());
declare variable $gui:template-content as element(html) := collection(xmldb:encode($gui:guiDoc/@style-col/string()))/id($gui:guiDoc/@template-id/string());

declare function gui:integrate-contents($title as xs:string, $content as node()*)
	as element(html)
{
	<html>
		<head>
			<title>{$title}</title>
			{ $gui:template-content/head/node() }
		</head>
		<body>
		{$gui:template-content/body/@*}
		{
			for $child in $gui:template-content/body/node()
			return
				if($child/@id eq 'contents') then
					<div id="contents">{$content}</div>
				else if($child/@id eq 'title') then
					<div id="title" align="center">
						<h2 style="color:#bb0909;">{$title}</h2>
					</div>
				else
					$child
		}
		</body>
	</html>
};

declare function gui:extract-path($uri as xs:string) as xs:string {
	let $cp := request:get-context-path()
	let $path := substring-after($uri, $cp)
	return if ($cp = '' and starts-with($uri,$gui:AtomicVirtualRoot)) then
		substring-after($path, $gui:AtomicVirtualRoot)
	else
		$path
};

(: Getting the base path of the Atomic Wiki installation :)
declare function gui:get-gui-path() as xs:string {
	(:
	let $retval := concat(request:get-context-path(),$gui:AtomicVirtualRoot)
	let $alert := util:log-system-err(("GUI PATH IS ",$retval))
	return $retval
	:)
	concat(request:get-context-path(),$gui:AtomicVirtualRoot)
};

(: Getting the relative base path of the Atomic Wiki installation :)
declare function gui:get-rel-gui-path() as xs:string {
	(:
	let $retval := concat(request:get-context-path(),$gui:AtomicVirtualRoot)
	let $alert := util:log-system-err(("GUI PATH IS ",$retval))
	return $retval
	:)
	substring(gui:get-gui-path(),1)
};


(: Getting the relative base path of the Atomic Wiki installation :)
declare function gui:get-public-base-URI() as xs:string {
	$mgmt:publicBaseURI
};
