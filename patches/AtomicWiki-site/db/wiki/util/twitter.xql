xquery version "1.0";

(: -----------------------------------------------------------------------
   A simple twitter client.
   -----------------------------------------------------------------------:)

declare namespace tc="http://exist-db.org/xquery/twitter-client";
declare namespace atom="http://www.w3.org/2005/Atom";
declare namespace html="http://www.w3.org/1999/xhtml";

import module namespace httpclient="http://exist-db.org/xquery/httpclient"
    at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: To access more than just the tweets posted by a single user (e.g. its friends timeline), 
   you need to authenticate with a valid twitter account. Enter the username/password pair
   below. :)
declare variable $tc:login := ( "user", "password" );

declare variable $tc:update-frequency := xs:dayTimeDuration("PT5M");

(: Create the HTTP basic authentication header if user credentials available :)
declare function tc:get-headers($credentials as xs:string*) {
    if (empty($credentials)) then
        ()
    else
        let $auth := concat('Basic ', util:string-to-binary(concat($credentials[1], ':', $credentials[2])))
        return
            <headers>
                <header name="Authorization" value="{$auth}"/>
            </headers>
};

(: Send an HTTP request to twitter to retrieve the timeline in Atom format :)
declare function tc:get-timeline($credentials as xs:string*, $userId as xs:string, $view as xs:string) {
    let $uri := xs:anyURI(
        concat("http://twitter.com/statuses/", $view, "_timeline/", $userId, ".atom?page=1")
    )
    let $headers := tc:get-headers($credentials)
    let $response := httpclient:get($uri, false(), $headers)
    return
        if ($response/@statusCode eq "200") then
            $response/httpclient:body/*
        else if ($response/httpclient:body//error) then
            $response/httpclient:body//error/string()
        else
            concat("Twitter reported an error. Code: ", $response/@statusCode)
};

(: Retrieve the timeline and store it into the db :)
declare function tc:update-timeline($credentials as xs:string*, $userId as xs:string, $view as xs:string) {
    let $null := xdb:create-collection("/db", "twitter")
    let $feed := tc:get-timeline($credentials, $userId, $view)
    return
        if (empty($feed) or $feed instance of xs:string) then
            $feed
        else
            let $docPath := xdb:store("/db/twitter", concat($userId, "_", $view, ".xml"), $feed)
            return
                doc($docPath)/atom:feed
};

(: Main function: returns the timeline in atom format. The data is cached within the database
   and will be renewed every few minutes. :)
declare function tc:timeline($credentials as xs:string*, $userId as xs:string, $view as xs:string) {
    let $feed := doc(concat("/db/twitter/", $userId, "_", $view, ".xml"))/atom:feed
    return
        if (exists($feed) and 
            (xs:dateTime($feed/atom:updated) + $tc:update-frequency) > current-dateTime()) then
            $feed
        else
            tc:update-timeline($credentials, $userId, $view)
};

(: Parse the twitter message string. This function will recognize user names, links
   and tags. :)
declare function tc:parse-content($content as xs:string) {
    let $filtered_text := $content
    let $filtered_text := replace($filtered_text,"(http://[A-z0-9/\.?=&amp;\-_%]+)",'<a href="$1" class="url" target="new">$1</a>')
    let $filtered_text := replace($filtered_text,"@([A-z0-9/\.\-_]+)", '<a href="http://twitter.com/$1" class="username">@$1</a>')
    let $filtered_text := replace($filtered_text,"^([A-z0-9/\.\-_]+):", '<a href="http://twitter.com/$1" class="username">$1</a>:')
    let $filtered_text := replace($filtered_text,"&amp;#([x0-9]+);","entity:$1")
    let $filtered_text := replace($filtered_text,"(&amp;)","$1amp;")
    let $filtered_text := replace($filtered_text,"#([A-z0-9/\-_]+)", '<a href="http://search.twitter.com/search?q=%23$1">#$1</a>')
    let $filtered_text := replace($filtered_text,"\[\[entity:([x0-9]+)\]\]","&amp;#$1;")
    let $filtered_text := concat("<span xmlns=""http://www.w3.org/1999/xhtml"" class='tw-body'>", $filtered_text, "</span>")
    return util:parse($filtered_text)
};

(: Format an atom entry :)
declare function tc:print-entry($entry as element(atom:entry), $showThumbs as xs:boolean) {
    let $currentDate := adjust-date-to-timezone(current-date(), xs:dayTimeDuration("PT0H"))
    let $date := xs:dateTime($entry/atom:published)
    let $dateLine :=
        if (xs:date($date) eq $currentDate) then
            xs:time($date)
        else
            $date
    return
        <li xmlns="http://www.w3.org/1999/xhtml">
            {
                if ($showThumbs) then (
                    <span class="tw-thumb">
                        <img src="{$entry/atom:link[@rel = 'image']/@href}" height="48" width="48"/>
                    </span>,
                    <span class="tw-content">
                        {tc:parse-content($entry/atom:content/node())}
                        <span class="tw-date">{$dateLine}</span>
                    </span>
                ) else
                    <span class="tw-content-simple">
                        {tc:parse-content($entry/atom:content/node())}
                        <span class="tw-date">{$dateLine}</span>
                    </span>
            }
        </li>
};

(: scan a set of HTML option elements and select the one whose value matches
   the $select argument :)
declare function tc:set-options($select as xs:string, $options as element(html:option)+) {
    for $opt in $options 
    return
        element { node-name($opt) } {
            if ($opt/@value eq $select) then
                attribute selected { "true" }
            else
                (),
            $opt/@*, $opt/node()
        }
};

let $user := 
    $entry/atom:category[@scheme="http://atomic.exist-db.org/config/twitter"][@term="user"]/string()
let $maxOpt := 
    $entry/atom:category[@scheme="http://atomic.exist-db.org/config/twitter"][@term="max-entries"]/string()
let $maxEntries := if ($maxOpt) then xs:double($maxOpt) else 10
let $thumbsOpt :=
    $entry/atom:category[@scheme="http://atomic.exist-db.org/config/twitter"][@term="thumbs"]/string()
let $showThumbs := $thumbsOpt = 'yes' 
let $viewOpt := $entry/atom:category[@scheme="http://atomic.exist-db.org/config/twitter"][@term="view"]/string()
let $view := if ($viewOpt) then $viewOpt else "user"
let $feed :=
    if ($user) then
        tc:timeline(
            if ($tc:login[1] eq 'user') then () else $tc:login,
            $user, $view
        )
    else ()
return
    <div xmlns="http://www.w3.org/1999/xhtml">
        <ul class="twitter">
        {
            if ($feed) then
                if ($feed instance of xs:string) then
                    <li>Twitter reported an error: {$feed}</li>
                else
                    let $entries :=
                        for $entry in $feed/atom:entry
                        order by xs:dateTime($entry/atom:published) descending
                        return $entry
                    for $entry in subsequence($entries, 1, xs:double($maxEntries))
                    return
                        tc:print-entry($entry, $showThumbs)
            else ()
        }
        </ul>
    </div>