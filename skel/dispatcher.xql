xquery version "1.0";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace atom="http://www.w3.org/2005/Atom" at "atom.xql";
import module namespace text="http://exist-db.org/xquery/text";

declare function exist:extract-feed($uri as xs:string) {
    let $path := substring-after($uri, request:get-context-path())
	return
        replace($path, "^/*(.*?)/*?$", "$1")
};

declare function exist:extract-page($uri as xs:string) as xs:string+ {
    let $path := substring-after($uri, request:get-context-path())
    return
        if (ends-with($path, '/')) then
            exist:extract-feed($path)
        else
            subsequence(text:groups($path, '^/?(.*)/([^/]+)$'), 2)
};

let $uri := request:get-uri()
let $action := request:get-parameter('action', ())[1]
let $addFeed := request:get-parameter('add-feed', ())
return
    if (matches($uri, "/(xmlrpc|forms|chiba|Flux|FluxHelper|PlainHtml|view|rest|atom/|webdav|thumbs|scripts|styles|assets|images|AtomicWiki.png|logo.jpg)")) then
        <exist:ignore>
            <exist:cache-control cache="yes"/>
        </exist:ignore>
        
    else if (ends-with($uri, '.xql')) then
        if (ends-with($uri, 'upload.xql')) then (
			util:log("DEBUG", ("FEED: ", request:get-parameter("feed", ()))),
            <exist:dispatch>
				<exist:forward url="/upload.xql"/>
			</exist:dispatch>
        ) else
            <exist:dispatch>
				<exist:forward url="/{replace($uri, '.*/([^/]+)$', '$1')}"/>
			</exist:dispatch>
            
    else if ($addFeed) then
        <exist:dispatch>
			<exist:redirect url="{replace($uri, '^(.*/)[^/]*$', '$1')}{$addFeed}/"/>
		</exist:dispatch>
        
    else if ($action eq 'preview') then
        <exist:dispatch>
			<exist:forward url="/preview.xql">
            	<exist:add-parameter name="feed" value="{exist:extract-feed($uri)}"/>
			</exist:forward>
        </exist:dispatch>
        
    else if ($action = ('store-comment', 'load-comment')) then (
		util:log("DEBUG", ("URL: ", $uri)),
        <exist:dispatch>
			<exist:forward url="/comment.xql">
            	<exist:add-parameter name="feed" value="{exist:extract-feed($uri)}"/>
			</exist:forward>
        </exist:dispatch>
    )
    else if (matches($uri, "\.\w+\??")) then
        <exist:dispatch>
			<exist:forward url="/rest{atom:wiki-root()}{$uri}"/>
		</exist:dispatch>
            
	else
        let $params := exist:extract-page($uri)
        return
            if (count($params) eq 2) then
                <exist:dispatch>
					<exist:forward url="/index.xql">
                    	<exist:add-parameter name="feed" value="{$params[1]}"/>
                    	<exist:add-parameter name="ref" value="{$params[2]}"/>
					</exist:forward>
                </exist:dispatch>
            else
                <exist:dispatch>
					<exist:forward url="/index.xql">
                    	<exist:add-parameter name="feed" value="{exist:extract-feed($uri)}"/>
					</exist:forward>
                </exist:dispatch>
