<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:xf="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events">
	<xsl:param name="xslt.xcesc_template_path"/>
	<xsl:param name="xslt.xcesc_project_name"/>
	
	<xsl:variable name="template" select="document($xslt.xcesc_template_path)/xhtml:html"/>
	
	<xsl:output method="xml"/>
	
	<xsl:template match="xhtml:html">
		<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xf="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events">
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
				<xsl:variable name="content" select="."/>
				<xsl:for-each select="$template/xhtml:body/node()">
					<xsl:choose>
						<xsl:when test="@id = 'title'">
							<div id="title" align="center">
								<h2 class="doctitle"><xsl:copy-of select="$content//xhtml:div[@id = 'title']/node()"/></h2>
							</div>
						</xsl:when>
						<xsl:when test="@id = 'contents'">
							<div id="contents">
								<xsl:copy-of select="$content//xhtml:div[@id = 'contents']/node()"/>
							</div>
						</xsl:when>
						<xsl:otherwise>
							<!-- Due some bugs in eXist <=> Saxon interaction, next sentence must travel through templates -->
							<!--
							<xsl:copy-of select="."/>
							-->
							<xsl:apply-templates select="." mode="copy"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</body>
		</html>
	</xsl:template>
	
	<!-- Due some bugs in eXist <=> Saxon interaction, we need these templates -->
	<xsl:template match="node()" mode="copy">
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="copy"/>
			<xsl:apply-templates select="node()" mode="copy"/>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="@*" mode="copy">
		<xsl:copy/>
	</xsl:template>
</xsl:stylesheet>