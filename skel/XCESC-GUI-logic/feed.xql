xquery version "1.0";

declare namespace atom="http://www.w3.org/2005/Atom";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";

declare option exist:serialize "method=text media-type=application/json";

(:
declare variable $atom:uri := concat($mgmt:publicBaseURI, "/atom/summary/wiki/blogs/eXist/");
:)
declare variable $atom:host := 'http://gopher.bioinfo.cnio.es';
declare variable $atom:uri := concat($atom:host, "/atom/summary/wiki/blogs/Atomic/");

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

let $uri := xs:anyURI($atom:uri)
let $response := doc($uri)
let $output :=
    util:serialize(atom:format-entry($response/atom:feed), "indent=no")
return
	concat("atomCallback('", $output, "');")
