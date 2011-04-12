<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	exclude-result-prefixes="xsl xhtml"
	xmlns:xcesc="http://www.cnio.es/scombio/xcesc/1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xhtml="http://www.w3.org/1999/xhtml"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xf="http://www.w3.org/2002/xforms"
	xmlns:ev="http://www.w3.org/2001/xml-events"
	xmlns="http://www.w3.org/1999/xhtml"
>
	<xsl:param name="xslt.xcesc_template_path"/>
	<xsl:param name="xslt.xcesc_project_name"/>
	
	<xsl:variable name="template" select="document($xslt.xcesc_template_path)/xhtml:html"/>
	
	<xsl:output method="xhtml"/>
	
	<xsl:template match="/">
		<xsl:copy-of select="processing-instruction()|comment()"/>
		<html>
			<xsl:copy-of select="$template/@*"/>
			<xsl:copy-of select="xhtml:html/@*"/>
			<xsl:apply-templates select="xhtml:html"/>
		</html>
	</xsl:template>
	
	<xsl:template match="xhtml:html">
			<head>
				<xsl:copy-of select="$template/xhtml:head/@*"/>
				<title><xsl:value-of select="$xslt.xcesc_project_name"/> - <xsl:value-of select="xhtml:head/xhtml:title"/></title>
				
				<!-- Due some bugs in eXist <=> Saxon interaction, next sentence must travel through templates -->
				<!--
				<xsl:copy-of select="$template/xhtml:head/node()"/>
				-->
				<xsl:apply-templates select="$template/xhtml:head/node()" mode="copy"/>
				<xsl:copy-of select="xhtml:head/node()[not(self::xhtml:title)]"/>
			</head>
			<body>
				<xsl:copy-of select="$template/xhtml:body/@*"/>
				<xsl:apply-templates select="$template/xhtml:body/node()" mode="copy">
					<xsl:with-param name="content" select="."/>
				</xsl:apply-templates>
			</body>
	</xsl:template>
	
	<!-- Due some bugs in eXist <=> Saxon interaction, we need these templates -->
	<xsl:template match="*[@id = 'title']" mode="copy">
		<xsl:param name="content"/>
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="copy"/>
			<h2 class="doctitle"><xsl:copy-of select="$content//xhtml:div[@id = 'title']/node()"/></h2>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="*[@id = 'contents']" mode="copy">
		<xsl:param name="content"/>
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="copy"/>
			<xsl:copy-of select="$content//xhtml:div[@id = 'contents']/node()"/>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="node()" mode="copy">
		<xsl:param name="content"/>
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="copy"/>
			<xsl:apply-templates select="node()" mode="copy">
				<xsl:with-param name="content" select="$content"/>
			</xsl:apply-templates>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="@*" mode="copy">
		<xsl:copy/>
	</xsl:template>
</xsl:stylesheet>