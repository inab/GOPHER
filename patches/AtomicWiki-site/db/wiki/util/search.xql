xquery version "1.0";

declare namespace ws="http://atomic.exist-db.org/xquery/wiki-search";

declare namespace atom="http://www.w3.org/2005/Atom";
declare namespace html="http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/html expand-xincludes=yes";

import module namespace kwic="http://exist-db.org/xquery/kwic" at "kwic.xql";
import module namespace ft="http://exist-db.org/xquery/lucene";
import module namespace gui='http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement' at 'xmldb:exist:///db/XCESC-logic/guiManagement.xqm';

declare variable $ws:FIELDS :=
	<fields>
		<field name="title" path="atom:title"/>
		<field path="atom:content//html:p"/>
		<field path="atom:content//html:h1"/>
		<field path="atom:content//html:h2"/>
		<field path="atom:content//html:h3"/>
		<field path="atom:content//html:h4"/>
	</fields>
	;

declare function ws:create-link($root as node(), $docXPath as xs:string) as xs:string {
	let $entry := $root/ancestor-or-self::atom:entry
	let $feed := atom:get-feed($entry)
	let $feedPath := if (string-length($feed) eq 0) then $feed else concat('/', $feed)
	let $queryPart := concat("dq=", escape-uri($docXPath, true())) 
	return
    	if ($entry/wiki:id) then
        	concat(cfg:get-html-uri(), gui:get-gui-path(), $feedPath, "/", $entry/wiki:id, "?", $queryPart)
    	else
        	concat(cfg:get-html-uri(), gui:get-gui-path(), $feedPath, "/?id=", $entry/atom:id, '&amp;', $queryPart)
};

(:~
	Display the hits: this function first calls util:expand() to get an in-memory
	copy of each hit with full-text matches tagged with &lt;exist:match&gt;. It
	then calls dq:print-summary for each exist:match element.
:)
declare function ws:print($hits as element()+, $docXPath as xs:string, $mode as xs:string) 
as element()* {
	for $hit in $hits
	let $link := ws:create-link($hit, $docXPath)
	return
		if ($mode eq 'summary') then
			kwic:summarize($hit, <config xmlns="" width="80" table="no" link="{$link}"/>)
		else
			kwic:summarize($hit, <config xmlns="" width="30" table="yes" link="{$link}"/>)
};

(:~
	Print the hierarchical context of a hit.
:)
declare function ws:print-headings($entry as element(atom:entry)*, $docXPath as xs:string) {
	let $link := ws:create-link($entry, $docXPath)
	return
		if ($entry/atom:category[@scheme = "http://exist-db.org/NS/wiki/type/"]/@term = "comment") 
		then
			<a href="{$link}">{$entry/parent::atom:feed/atom:title/text()}</a>
		else
			<a href="{$link}">{$entry/atom:title/text()}</a>
};

(:~
	Display the query results.
:)
declare function ws:print-results($hits as element()*, $docXPath as xs:string, $mode as xs:string) {
	let $sections := $hits/ancestor::atom:entry
	return
		<div id="f-results">
			<p id="f-results-heading">Found: {count($hits)} in {count($sections)} sections.</p>
			{
				if ($mode eq 'summary') then
					for $section in $sections
					let $hitsInSect := $section//$hits
					return
						<div class="section">
							<div class="headings">{ ws:print-headings($section, $docXPath) }</div>
							{ ws:print($hitsInSect, $docXPath, $mode) }
						</div>
				else
					<table class="kwic">
					{
						for $section in $sections
						let $hitsInSect := $section//$hits
						return (
							<tr>
								<td class="headings" colspan="3">
								{ws:print-headings($section, $docXPath)}
								</td>
							</tr>,
							ws:print($hitsInSect, $docXPath, $mode)
						)
					}
					</table>
			}
		</div>
};

declare function ws:query-parts($field as xs:string?, $term as xs:string) {
	if ($field) then
		concat($ws:FIELDS/field[@name = $field]/@path, '[ft:query(., "', $term, '")]')
	else
		for $f in $ws:FIELDS/field
		return
			concat($f/@path, '[ft:query(., "', $term, '")]')
};

let $query := replace(request:get-parameter("q", ()), '"', '')
let $field := request:get-parameter("field", ())
let $mode := request:get-parameter("display", "summary")
return
	<div xmlns="http://www.w3.org/1999/xhtml">
		<form id="query-form" action="" method="POST">
			<span class="display-type">
				Display:
				<select name="display">
					<option value="summary">Summary</option>
					<option value="table">
						{ if ($mode eq 'table') then attribute selected { 'selected' } else () }
						Table
					</option>
				</select>
			</span>
			<div>
				<select name="field">
					<option value="">All</option>
					<option value="title">
						{ if ($field eq 'title') then attribute selected { 'selected' } else () }
						Title
					</option>
				</select>
				<input type="text" name="q" value="{$query}"/>
				<input type="submit"/>
			</div>
		</form>

		{
			if ($query) then
				let $parts := ws:query-parts($field, $query)
				let $xpath := string-join(
					for $p in $parts return
						concat("//", $p),
					" | "
				)
				let $orderedXPath := concat(
					"for $m in ", $xpath, 
					" order by ft:score($m) return $m"
				)
				let $docXPath := string-join(for $p in $parts return concat(".//", $p), " or ")
				let $hits := util:eval($orderedXPath)
				return
					ws:print-results($hits, $docXPath, $mode)
			else
				()
		}
	</div>
