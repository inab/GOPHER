(:
	guiManagement.xqm
:)
xquery version "1.0";

module namespace gui="http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace util="http://exist-db.org/xquery/util";

(: Don't forget the starting slash! :)
declare variable $gui:AtomicRoot as xs:string := concat('/',collection($mgmt:configColURI)//gui:guiManagement[1]/@AtomicWiki-logic/string());
declare variable $gui:AtomicVirtualRoot as xs:string := concat('/',collection($mgmt:configColURI)//gui:guiManagement[1]/@AtomicWiki-VirtualRoot/string());

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
