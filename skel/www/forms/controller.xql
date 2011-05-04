(: XQuery main module :)

xquery version "1.0" encoding "UTF-8";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";
import module namespace gui="http://www.cnio.es/scombio/xcesc/1.0/xquery/guiManagement" at "xmldb:exist:///db/XCESC-logic/guiManagement.xqm";

let $tokens := tokenize($exist:path,'/')
let $matches := for $token at $tokenpos in $tokens
return
	if(matches($token, '\.xhtml?$')) then (
		$tokenpos
	) else
		()
let $nummatches := count($matches)
return
if (not(starts-with($exist:path , '/')) or $tokens = 'controller.xql') then
	<exist:dispatch>
		<exist:redirect url="/"/>
	</exist:dispatch>
else if ($nummatches > 0) then
	(
	request:set-attribute('xslt.xcesc_template_path',xs:string(gui:get-template-uri('leftMiniLogos')))
	,
	request:set-attribute('xslt.xcesc_project_name',xs:string($mgmt:projectName))
	,
	<exist:dispatch>
		<exist:view>
			<exist:forward servlet="XSLTServlet">
				(: Apply integrate-contents.xsl stylesheet :)
				<exist:set-attribute name="xslt.stylesheet" value="{$exist:root}/style/integrate-contents.xsl"/>
				<exist:set-attribute name="xslt.output.indent" value="no"/>
				<exist:set-attribute name="xslt.output.media-type" value="application/xhtml+xml"/>
				<exist:set-attribute name="xslt.output.method" value="xhtml"/>
				<exist:set-attribute name="xslt.output.encoding" value="UTF-8"/>
			</exist:forward>
			{
				if(request:get-parameter('xsltforms',()) = 'off') then
					()
				else
					<exist:forward servlet="XSLTServlet">
						(: Apply xsltforms.xsl stylesheet :)
						<exist:set-attribute name="xslt.stylesheet" value="{$exist:root}{$exist:controller}/xsltforms/xsltforms.xsl"/>
						<exist:set-attribute name="xslt.output.omit-xml-declaration" value="yes"/>
						<exist:set-attribute name="xslt.output.indent" value="no"/>
						<exist:set-attribute name="xslt.output.media-type" value="text/html"/>
						<exist:set-attribute name="xslt.output.method" value="xhtml"/>
						<exist:set-attribute name="xslt.output.encoding" value="UTF-8"/>
						<exist:set-attribute name="xslt.baseuri" value="xsltforms/"/>
					</exist:forward>
			}
		</exist:view>
	</exist:dispatch>
	)
else
	<exist:ignore>
		<exist:cache-control cache="yes"/>
	</exist:ignore>
