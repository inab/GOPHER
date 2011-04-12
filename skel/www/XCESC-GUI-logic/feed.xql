xquery version "1.0";

declare namespace atom="http://www.w3.org/2005/Atom";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";

(:
declare variable $atom:uri := concat($mgmt:publicBaseURI, "/atom/summary/wiki/blogs/eXist/");
declare variable $atom:host := 'http://localhost:8088';
declare variable $atom:host := $mgmt:publicBaseURI;
declare variable $atom:uri := concat($atom:host, "/atom/summary/wiki/blogs/Atomic/");
:)


declare option exist:serialize "method=text media-type=application/json";

declare function atom:format-entry($feed as element()) {
    <ul>
    {
        for $entry in subsequence($feed//atom:entry, 1, 4)
        let $link := $entry/atom:link[@rel = 'alternate'][@type = 'text/html']/@href
        return
            <li>
                <p class="date">
                    {substring($entry/atom:published, 1, 10)}
                </p>
                <a href="{$link}">
                    {$entry/atom:title/text()}
                </a>
            </li>
    }
    </ul>
};

let $callback0 := request:get-parameter('callback',())
(: We are very serious about code injection :)
let $callback := if(empty($callback0) or $callback0[1] eq '' or matches($callback0[1],'[^$a-zA-Z0-9_.]')) then (
	'atomCallback'
) else (
	$callback0[1]
)
let $host := '127.0.0.1'
let $port := string(request:get-server-port())
(:
let $forwarded-host-port := tokenize(request:get-header('X-Forwarded-Host'),', *')[last()]
let $host := if(exists($forwarded-host-port)) then tokenize($forwarded-host-port,':')[1] else request:get-server-name()
let $port0 := if(exists($forwarded-host-port)) then tokenize($forwarded-host-port,':')[last()] else string(request:get-server-port())
let $port := if(empty($port0)) then $mgmt:publicServerPort else $port0
:)
let $atom:host := concat(if($port eq '443') then 'https' else 'http','://',$host,if(not($port = ('80','443'))) then concat(':',$port) else '')
let $atom:uri := concat($atom:host, "/atom/summary/wiki/blogs/Atomic/")
let $uri := xs:anyURI($atom:uri)
(:
let $response := doc($uri)
:)
let $response0 := httpclient:get($uri,false(),())
let $response := $response0[@statusCode eq '200']/httpclient:body[@type = ('xml','xhtml')]
let $output := util:serialize(if($response/atom:feed) then (
	atom:format-entry($response/atom:feed)
) else (
	<div>
		<b>Error while fetching feed ({$response0/@statusCode/string()}):</b><br/>
		{$response0/httpclient:body/*}
	</div>
), "indent=no")
return
	concat("try { ",$callback,"('", replace(replace(replace($output,'&#13;&#10;','\\n'), '&#10;','\\n'),'&#13;','\\n'), "'); } catch(e) { };")
