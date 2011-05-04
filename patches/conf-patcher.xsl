<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:param name="oldbase">${exist.home}/webapp/WEB-INF/logs</xsl:param>
	<xsl:param name="newbase">${exist.logsdir}</xsl:param>

	<xsl:output encoding="UTF-8" indent="yes"/>
	
	<xsl:template match="db-connection">
		<db-connection>
			<xsl:attribute name="cacheSize">@memory@</xsl:attribute>
			<xsl:attribute name="database">native</xsl:attribute>
			<xsl:attribute name="files">@data.dir@</xsl:attribute>
			<xsl:for-each select="@*">
				<xsl:choose>
					<xsl:when test="name() = 'cacheSize' or name() = 'database' or name() = 'files'">
						<!-- Ignore the attributes! -->
					</xsl:when>
					<xsl:otherwise>
						<xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
						    <xsl:value-of select="."/>
						</xsl:attribute>
						<!--
						<xsl:apply-templates select="."/>
						-->
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			
			<xsl:apply-templates select="*|text()|comment()|processing-instruction()" />
		</db-connection>
	</xsl:template>
	
	<xsl:template match="recovery">
		<recovery>
			<xsl:attribute name="journal-dir">@data.dir@</xsl:attribute>
			<xsl:attribute name="sync-on-commit">yes</xsl:attribute>
			<xsl:for-each select="@*">
				<xsl:choose>
					<xsl:when test="name() = 'journal-dir' or name() = 'sync-on-commit'">
						<!-- Ignore the attributes! -->
					</xsl:when>
					<xsl:otherwise>
						<xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
						    <xsl:value-of select="."/>
						</xsl:attribute>
						<!--
						<xsl:apply-templates select="."/>
						-->
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			
			<xsl:apply-templates select="*|text()|comment()|processing-instruction()" />
		</recovery>
	</xsl:template>
	
	<xsl:template match="scheduler">
		<scheduler>
			<xsl:for-each select="@*">
				<xsl:apply-templates select="."/>
			</xsl:for-each>
			<xsl:apply-templates select="*|text()|comment()|processing-instruction()" />
			
			<job type="user" name="weeklyGOPHERAssess" cron-trigger="0 0 22 ? * 4 *"
				xquery="/db/XCESC-logic/cronjobAssessWrapper.xql"
			/>

			<job type="user" name="weeklyGOPHER" cron-trigger="0 0 23 ? * 4 *"
				xquery="/db/XCESC-logic/cronjobWrapper.xql"
			/>

			<job type="system" name="backup"
				class="org.exist.storage.BackupSystemTask" 
				cron-trigger="0 0 */6 * * ?">
					<parameter name="dir" value="@backup.dir@"/>
					<parameter name="suffix" value=".zip"/>
					<parameter name="prefix" value="XCESC-backup-"/>
					<parameter name="collection" value="/db"/>
					<parameter name="user" value="@admin.user@"/>
					<parameter name="password" value="@admin.pass@"/>
					<parameter name="zip-files-max" value="28"/>
			</job>
			
		</scheduler>
	</xsl:template>
	
	<xsl:template match="builtin-modules">
		<builtin-modules>
			<xsl:for-each select="@*">
				<xsl:apply-templates select="."/>
			</xsl:for-each>
			<xsl:apply-templates select="*|text()|comment()|processing-instruction()" />
			
			<!-- Modules needed by AtomicWiki -->
			<module uri="http://www.w3.org/2005/Atom"
				src="resource:org/exist/atomic/atom.xql"/>
			<module uri="http://atomic.exist-db.org/xq/config"
				src="resource:org/exist/atomic/configuration.xql"/>
			<module uri="http://atomic.exist-db.org/xquery/data"
				src="resource:org/exist/atomic/data.xql"/>
			<module uri="http://atomic.exist-db.org/xquery/render"
				src="resource:org/exist/atomic/render.xql"/>
			<module uri="http://atomic.exist-db.org/x2cw"
				src="resource:org/exist/atomic/XHTML2CommonWiki.xql"/>
	
			<!-- Modules needed/used by XCESC-->
			<xsl:if test="not(./module[@class = 'org.exist.xquery.modules.math.MathModule'])">
				<module class="org.exist.xquery.modules.math.MathModule"
					uri="http://exist-db.org/xquery/math" />
			</xsl:if>
			<xsl:if test="not(./module[@class = 'org.exist.xquery.modules.mail.MailModule'])">
				<module class="org.exist.xquery.modules.mail.MailModule"
					uri="http://exist-db.org/xquery/mail" />
			</xsl:if>
			<xsl:if test="not(./module[@class = 'org.exist.xquery.modules.jfreechart.JFreeChartModule'])">
				<module class="org.exist.xquery.modules.jfreechart.JFreeChartModule"
					uri="http://exist-db.org/xquery/jfreechart"/> 
			</xsl:if>
		</builtin-modules>
	</xsl:template>
    <xsl:template match="*">
	<xsl:copy>
		<xsl:apply-templates select="@*|node()"/>
	</xsl:copy>
    </xsl:template>
    <xsl:template match="@*|comment()|text()|processing-instruction()">
        <xsl:copy-of select="."/>
    </xsl:template>
</xsl:stylesheet>