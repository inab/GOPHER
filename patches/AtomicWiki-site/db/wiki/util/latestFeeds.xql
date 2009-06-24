declare namespace wiki="http://exist-db.org/xquery/wiki";

import module namespace cfg="http://atomic.exist-db.org/xq/config" at "configuration.xql";
import module namespace atom="http://www.w3.org/2005/Atom" at "atom.xql";
import module namespace gui='http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement' at 'xmldb:exist:///db/XCESC-logic/guiManagement.xqm';

<div class="entry-list" xmlns="http://www.w3.org/1999/xhtml">
{
let $entries :=
    for $entry in collection(atom:wiki-root())//atom:entry[not(atom:category) 
    or atom:category[@scheme = "http://exist-db.org/NS/wiki/type/"]/@term != "comment"]
    order by xs:dateTime($entry/atom:updated) descending
    return $entry
for $entry in subsequence($entries, 1, 15)
let $feed := atom:get-feed($entry) 
let $feedPath := if (string-length($feed) eq 0) then $feed else concat('/', $feed)
let $url :=
    if ($entry/wiki:id) then
        concat(cfg:get-html-uri(), gui:get-gui-path() , $feedPath, "/", $entry/wiki:id)
    else
        concat(cfg:get-html-uri(), gui:get-gui-path() , $feedPath, "/?id=", $entry/atom:id)
return
    <div class="entry-list-entry">
        <div class="date">
            {substring($entry/atom:updated, 1, 10)}
        </div>
        <a href="{$url}">
            {$entry/atom:title/text()}
        </a>
    </div>
}
</div>
