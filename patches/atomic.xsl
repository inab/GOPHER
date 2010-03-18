<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:param name="oldowner">blogadmin</xsl:param>
    <xsl:param name="newowner">xcesc</xsl:param>
    <xsl:param name="AtomicVirtual">Atomic</xsl:param>
    
    <xsl:template match="/">
        <xsl:apply-templates select="*|comment()|text()|processing-instruction()"/>
    </xsl:template>
    
    <xsl:template match="*" priority="2">
        <xsl:element name="{name(.)}" namespace="{namespace-uri(.)}">
		<xsl:choose>
			<xsl:when test="name(.)='form'">
        		    <xsl:for-each select="@*">
                		<xsl:choose>
                		    <xsl:when test="name(.)='action' and starts-with(.,'/')">
                        		<xsl:attribute name="{name(.)}">
                        		    <xsl:value-of select="concat('/',$AtomicVirtual,.)"/>
                        		</xsl:attribute>
                		    </xsl:when>
                		    <xsl:otherwise>
                        		<xsl:copy-of select="."/>
                		    </xsl:otherwise>
                		</xsl:choose>
        		    </xsl:for-each>
			</xsl:when>
			<xsl:otherwise>
        		    <xsl:for-each select="@*">
                		<xsl:choose>
                		    <xsl:when test="name(.)='href' and starts-with(.,'/')">
                        		<xsl:attribute name="{name(.)}">
                        		    <xsl:value-of select="concat('/',$AtomicVirtual,.)"/>
                        		</xsl:attribute>
                		    </xsl:when>
                		    <xsl:when test="name(.)='owner' and .=$oldowner">
                        		<xsl:attribute name="{name(.)}">
                        		    <xsl:value-of select="$newowner"/>
                        		</xsl:attribute>
                		    </xsl:when>
                		    <xsl:otherwise>
                        		<xsl:copy-of select="."/>
                		    </xsl:otherwise>
                		</xsl:choose>
        		    </xsl:for-each>
			</xsl:otherwise>
		</xsl:choose>    
            <!--
            <xsl:apply-templates select="@*"/>
            -->
            <xsl:apply-templates select="*|comment()|text()|processing-instruction()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="comment()|text()|processing-instruction()" priority="0">
        <xsl:copy-of select="."/>
    </xsl:template>
</xsl:stylesheet>
