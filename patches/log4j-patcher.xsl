<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:param name="oldbase">${exist.home}/webapp/WEB-INF/logs</xsl:param>
	<xsl:param name="newbase">${exist.logsdir}</xsl:param>

	<xsl:output doctype-system="log4j.dtd" encoding="UTF-8" indent="yes"/>
	
	<xsl:template match="param[@name = 'File']">
		<xsl:choose>
			<xsl:when test="starts-with(@value,$oldbase)">
				<param name="{@name}" value="{concat($newbase,substring-after(@value,$oldbase))}"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:copy>
					<xsl:apply-templates select="@*"/>
					<xsl:apply-templates/>
				</xsl:copy>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="appender[last()]">
		<xsl:copy>
			<xsl:apply-templates select="@*"/>
			<xsl:apply-templates/>
		</xsl:copy>
		
		<xsl:comment> Appenders for WebDAV and XCESC cron </xsl:comment>
		
		<appender name="exist.webdav" class="org.apache.log4j.RollingFileAppender">
			<param name="File" value="${{exist.logsdir}}/webdav.log"/>
			<param name="MaxFileSize" value="500KB"/>
			<param name="Encoding" value="UTF-8"/>
			<layout class="org.apache.log4j.PatternLayout">
				<param name="ConversionPattern" value="%d [%t] %-5p (%F [%M]:%L) - %m %n"/>
			</layout>
		</appender>
		
		<appender name="xcesc.cron" class="org.apache.log4j.RollingFileAppender">
			<param name="File" value="${{exist.logsdir}}/XCESC-cron.log"/>
			<param name="MaxFileSize" value="500KB"/>
			<param name="MaxBackupIndex" value="3"/>
			<param name="Encoding" value="UTF-8"/>
			<layout class="org.apache.log4j.PatternLayout">
				<param name="ConversionPattern" value="%d [%t] %-5p (%F [%M]:%L) - %m %n"/>
			</layout>
		</appender>
	</xsl:template>
	
	<xsl:template match="category[last()]">
		<xsl:copy>
			<xsl:apply-templates select="@*"/>
			<xsl:apply-templates/>
		</xsl:copy>
		
		<xsl:comment> Categories for WebDAV and XCESC cron </xsl:comment>
		
		<category name="org.exist.http.webdav" additivity="false">
			<priority value="debug"/>
			<appender-ref ref="exist.webdav"/>
		</category>
		
		<category name="xcesc.cron" additivity="false">
			<priority value="debug"/>
			<appender-ref ref="xcesc.cron"/>
		</category>
	</xsl:template>
	
	<!-- standard copy template -->
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*"/>
			<xsl:apply-templates/>
		</xsl:copy>
	</xsl:template>	
</xsl:stylesheet>