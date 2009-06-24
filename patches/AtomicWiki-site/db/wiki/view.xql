xquery version "1.0";

(: 
    Defines the default view for the wiki. This script will be used if no other view
    is specified in the configuration.
:)

import module namespace rend="http://atomic.exist-db.org/xquery/render";
import module namespace cfg="http://atomic.exist-db.org/xq/config";
import module namespace request="http://exist-db.org/xquery/request";

import module namespace gui='http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement' at 'xmldb:exist:///db/XCESC-logic/guiManagement.xqm';
declare option exist:serialize "method=xhtml media-type=text/html indent=no
	highlight-matches=both
    doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
    doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";
    
let $input := request:get-attribute("model")
let $action := request:get-attribute("action")
let $path := if (request:get-attribute("path")) then request:get-attribute("path") else ""
let $loginStatus := request:get-attribute("login")

let $context := gui:get-gui-path()
return
	<html xmlns="http://www.w3.org/1999/xhtml">
		<head>
			<title>{ request:get-attribute("title") }</title>
			<meta name="feed" content="{$path}"/>
			<meta name="context" content="{$context}"/>
			<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
			{ rend:default-styles() }
			<link rel="stylesheet" type="text/css" href="{$context}/styles/default.css"/>
			<link rel="stylesheet" type="text/css" href="{$context}/db/wiki/util/twitter.css"/>
		</head>
		<body class="yui-skin-sam">
			<div id="doc3" class="yui-t1">
				<div id="page-head" class="hd">
				    <a href="http://code.google.com/p/atomicwiki">
						<img alt="AtomicWiki Logo" src="{$context}/AtomicWiki.png"/>
					</a>
					<div id="navbar">
						{ rend:navigation($path) }
						{ rend:titles($path, $loginStatus) }
					</div>
				</div>
				<div id="bd">
				    <div id="yui-main">
                        <div class="yui-b">
                            <div class="yui-ge">
                                <div class="yui-u noprint">
                                    { rend:sidemenu($loginStatus) }
                                    { rend:create-box("util", "QuickSearch", false()) }
                                    { if ($action = ('new', 'edit')) then rend:create-box("util", "MarkupHelp", true()) else () }
                                    { if ($path eq '') then rend:create-box-async("util", "TwitterFeed") else () }
                                </div>
                                <div id="weblog" class="yui-u first">
                                    { rend:display-errors($action, request:get-attribute("response")) }
                                    <div class="weblog-content">
                                    { rend:render-default($action, $path, $loginStatus, $input) }
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="yui-b noprint">
                        { rend:create-box("util", "MainLinks", false()) }
                        { rend:create-box("util", "LatestPosts", false()) }
                        <div class="subscribe">
                            { rend:atom-link($path) }
                        </div>
                    </div>
				</div>
				<div id="ft">AtomicWiki {$cfg:VERSION}</div>
			</div>
			{ rend:default-scripts() }
		</body>
	</html>