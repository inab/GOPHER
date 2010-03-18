xquery version "1.0";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace conf="http://atomic.exist-db.org/config";

import module namespace atom="http://www.w3.org/2005/Atom"; 
import module namespace text="http://exist-db.org/xquery/text";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace gui="http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement" at "xmldb:exist:///db/XCESC-logic/guiManagement.xqm";

declare function exist:extract-feed($uri as xs:string)  as xs:string {
    replace(gui:extract-path($uri), "^/*(.*?)/*?$", "$1")
};

declare function exist:extract-page($uri as xs:string) as xs:string+ {
    if (ends-with($uri, '/')) then
        exist:extract-feed($uri)
    else
        subsequence(text:groups(gui:extract-path($uri), '^/?(.*)/([^/]+)$'), 2)
};

declare function exist:get-render-url($feedConfig as element(conf:feed-config), $view as element(conf:view)) {
    if ($view/@render) then
        <exist:forward url="{concat('/rest', $gui:AtomicVirtualRoot,util:collection-name($feedConfig), '/', $view/@render)}"/>
    else
	    <exist:forward url="/rest{$gui:AtomicVirtualRoot}/apply-theme.xql">
			<exist:add-parameter name="theme" value="{$view/@theme}"/>
		</exist:forward>
};

declare function exist:feed-config($feed as xs:string, $action as xs:string?) as element() {
    let $mode := 
        if ($action = ('new', 'edit')) then
            'edit'
        else
            'read'
    let $path := concat(atom:wiki-root(), $feed)
    let $configs :=
        for $config in collection(atom:wiki-root())/conf:feed-config
        let $cname := util:collection-name($config)
        where starts-with($path, $cname)
        order by string-length($cname) descending
        return $config
    return
        if (empty($configs)) then
            <exist:forward url="/view.xql"/>
        else
            let $feedConfig := $configs[1]
            let $view := 
                if ($feedConfig/conf:view[@type = $mode]) then 
                    $feedConfig/conf:view[@type = $mode]
                else
                    $feedConfig/conf:view[1]
            return
	    	exist:get-render-url($feedConfig, $view)
};

let $genuineuri := request:get-uri()
let $origuri := if ( $genuineuri eq $gui:AtomicVirtualRoot ) then concat($genuineuri,'/') else $genuineuri
let $uri := gui:extract-path($origuri)
let $action := request:get-parameter('action', ())[1]
let $addFeed := request:get-parameter('add-feed', ())
let $quiet := request:get-parameter("quiet", ())
return
    if (not(starts-with($uri , '/'))) then
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
    else if (matches($uri, "^/(scripts|styles|assets|images|AtomicWiki.png|logo.jpg|setup.xql)")) then
	<exist:dispatch>
		<exist:forward url="{$uri}"/>
	</exist:dispatch>

    else if (matches($uri, "^/(xmlrpc|atom/|webdav|rest|thumbs|db)")) then
	<exist:dispatch>
		<exist:redirect url="{$uri}"/>
	</exist:dispatch>

    else if (starts-with($uri, "/rest")) then
	let $newuri := substring-after($uri, '/rest')
	return
		<exist:dispatch>
			<exist:forward url="{$newuri}"/>
		</exist:dispatch>

    else if (not($exist:resource = 'setup.html' or doc-available("/db/atom/configuration.xml"))) then
	<exist:dispatch>
    		<exist:forward url="/setup.html">
			<exist:set-header name="Cache-Control" value="no-cache"/>
		</exist:forward>
	</exist:dispatch>    

    else if (ends-with($exist:resource, '.xql')) then
        if ($exist:resource = 'upload.xql') then (
		util:log("DEBUG", ("FEED: ", request:get-parameter("feed", ()))),
		<exist:dispatch>
			<exist:forward url="/upload.xql"/>
		</exist:dispatch>
        ) else
		<exist:dispatch>
			<exist:forward url="/{$exist:resource}"/>
		</exist:dispatch>
            
    else if ($addFeed) then
	<exist:dispatch>
		<exist:redirect url="{replace($uri, '^(.*/)[^/]*$', '$1')}{$addFeed}/?create=y"/>
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
		<exist:redirect url="/rest{atom:wiki-root()}{$uri}"/>
	</exist:dispatch>
            
    else
        let $params := exist:extract-page($uri)
	(:
		let $alert := util:log-system-err(($origuri,' ',$params," /{exist:feed-config($feed, $action)}"))
	:)
        return
		if (count($params) eq 2) then
			<exist:dispatch>
				<exist:forward url="/index.xql">
					<exist:add-parameter name="feed" value="{$params[1]}"/>
					<exist:add-parameter name="ref" value="{$params[2]}"/>
				</exist:forward>
				{
					if (not($quiet)) then
						<exist:view>
							{ exist:feed-config($params[1], $action) }
						</exist:view>
					else
						()
				}
			</exist:dispatch>
		else
			let $feed := exist:extract-feed($uri)
			(:
				let $alert := util:log-system-err(($origuri,' ',$feed,'  ',exist:feed-config($feed, $action)))
			:)
			return
				<exist:dispatch>
					<exist:forward url="/index.xql">
						<exist:add-parameter name="feed" value="{$feed}"/>
					</exist:forward>
					{
						if (not($quiet)) then
							<exist:view>
								{ exist:feed-config($feed, $action) }
							</exist:view>
						else
							()
					}
				</exist:dispatch>
