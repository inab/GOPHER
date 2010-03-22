xquery version "1.0";

declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
import module namespace mgmt="http://www.cnio.es/scombio/xcesc/1.0/xquery/systemManagement" at "xmldb:exist:///db/XCESC-logic/systemManagement.xqm";


let $dummy:=session:set-current-user($mgmt:adminUser,$mgmt:adminPass)
let $dumpost:=if(request:get-method() eq 'POST') then (
	util:catch('*',
		let $data:=request:get-data()
		let $deleteUsers:=mgmt:deleteDeletedUsers($data//xcesc:deletedUser)
		for $user in $data//xcesc:user
		return
			if(exists($user/@id) and $user/@id ne '') then (
				mgmt:updateUser($user/@id,$user)
			,
				if(not(empty($user/@nickpass) or ($user/@nickpass eq ''))) then (
					mgmt:changeUserPass($user/@id,$user/@nickname,'',$user/@nickpass,true)
				) else (
				)
			) else (
				let $uid:=mgmt:createUser($user)
				return ()
			)
		,
		let $errmsg:=concat("Exception while loading expected result: ", $util:exception-message)
		let $err1:=util:log-system-err($errmsg)
		let $err2:=response:set-status-code(500)
		let $err3:=response:set-header('X-XCESC-error-message',$errmsg)
		return $errmsg
	)
) else ()
return if(empty($dumpost)) then (
	let $dum2 := util:declare-option('exist:serialize',"method=xhtml media-type=text/xml process-xsl-pi=no")
	let $content := <html xmlns="http://www.w3.org/1999/xhtml"
		xmlns:sample="http://www.agencexml.com/sample"
		xmlns:xcesc="http://www.cnio.es/scombio/xcesc/1.0"
 		xmlns:xforms="http://www.w3.org/2002/xforms"
		xmlns:ev="http://www.w3.org/2001/xml-events"
		xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<head>
		<title>GOPHER User Management</title>
		<meta name="description" content="GOPHER User Management"/>
		<meta name="keywords" content="AJAX, Javascript, Web, XForms, XSLTForms, Exemples, Samples"/>
		
        	<link rel="shortcut icon" href="../style/GOPHER-favicon.ico"
		type="image/vnd.microsoft.icon"/>
	        <link rel="icon" href="../style/GOPHER-favicon.ico" type="image/vnd.microsoft.icon"/>
		<link rel="stylesheet" type="text/css" href="../style/default-style.css"/>
		
		<style type="text/css"><![CDATA[
			.amount input {
			width : 60px;
			}

			.desc input {
			width : 100px;
			}

			.delete button {
			padding : 0px;
			}
		]]></style>
		<xforms:model id="default-model">
			<xforms:instance id="users">
				<xcesc:users>
					{
						let $users := mgmt:getUsers()
						return if(empty($users)) then
							<xcesc:user nickname="" nickpass="" firstName="" lastName="" organization="">
								<xcesc:eMail></xcesc:eMail>
							</xcesc:user>
						else
							$users
					}
					<!--
					<xcesc:user nickname="Nick" nickpass="dr" firstName="Hola" lastName="doctor Nick" organization="Mi casa">
						<xcesc:eMail>Reeves@reeves.org</xcesc:eMail>
					</xcesc:user>
					-->
				</xcesc:users>
			</xforms:instance>
			<!--
			<xforms:instance>
				<sample:balance>
					<sample:transaction>
						<sample:date>2004-05-06</sample:date>
						<sample:desc>Salery</sample:desc>
						<sample:withdraw>false</sample:withdraw>
						<sample:amount>5000.00</sample:amount>
					</sample:transaction>
					<sample:transaction>
						<sample:date>2004-05-06</sample:date>
						<sample:desc>News Paper</sample:desc>
						<sample:withdraw>true</sample:withdraw>
						<sample:amount>2.00</sample:amount>
					</sample:transaction>
					<sample:totals>
						<sample:in>0</sample:in>
						<sample:out>0</sample:out>
						<sample:total>0</sample:total>
					</sample:totals>
				</sample:balance>
			</xforms:instance>
			<xforms:bind nodeset="sample:transaction/sample:date" type="xsd:date"/>
			<xforms:bind nodeset="sample:transaction/sample:amount" type="xforms:amount"/>
			<xforms:bind nodeset="sample:totals/sample:in" type="xforms:amount" calculate="sum(/sample:balance/sample:transaction[sample:withdraw='false']/sample:amount)"/>
			<xforms:bind nodeset="sample:totals/sample:out" type="xforms:amount" calculate="sum(/sample:balance/sample:transaction[sample:withdraw='true']/sample:amount)"/>
			<xforms:bind nodeset="sample:totals/sample:total" type="xforms:amount" calculate="../sample:in - ../sample:out"/>
			-->
			
			<xforms:bind nodeset="instance('users')">
				<xforms:bind nodeset="xcesc:user">
					<xforms:bind nodeset="@nickname" type="xsd:string" required="true()"/>
					<xforms:bind nodeset="@nickpass" type="xsd:string" />
					<xforms:bind nodeset="@id" type="xsd:string" readonly="true()"/>
					<xforms:bind nodeset="@firstName" type="xsd:string" required="true()"/>
					<xforms:bind nodeset="@lastName" type="xsd:string" required="true()"/>
					<xforms:bind nodeset="@organization" type="xsd:string" required="true()"/>
					<xforms:bind nodeset="xcesc:eMail" type="xsd:string" required="true()"/>
				</xforms:bind>
			</xforms:bind>

			<xforms:submission ref="/xcesc:users" mediatype="application/xml" id="s01" method="post" replace="all" action="{tokenize(request:get-servlet-path(),'/')[last()]}">
				<xforms:message level="modeless" ev:event="xforms-submit-error">Submit error.</xforms:message>
			</xforms:submission>
		</xforms:model>
	</head>
	<body>
		<div align="center"><h3>GOPHER User Management</h3></div>
		<div id="xformControl">
			<span>
				<input type="checkbox" onclick="$('console').style.display = this.checked? 'block' : 'none';" checked="checked"/> Debug
			</span>
		</div>
		<xforms:repeat nodeset="xcesc:user" id="usuarios" appearance="full">
                    <xforms:output ref="@id">
                        <xforms:label>XCESC user Id</xforms:label>
                        <xforms:hint>XCESC Id assigned to the user</xforms:hint>
                    </xforms:output>
                    <xforms:input ref="@nickname">
                        <xforms:label>User name</xforms:label>
                        <xforms:hint>The user name you are using in GOPHER</xforms:hint>
                    </xforms:input>

                    <xforms:secret ref="@nickpass">
                        <xforms:label>User password</xforms:label>
                        <xforms:hint>The password you want to set at the beginning</xforms:hint>
                    </xforms:secret>

                    <xforms:input ref="@firstName">
                        <xforms:label>First Name(s)</xforms:label>
                        <xforms:hint>Your first name(s)</xforms:hint>
                    </xforms:input>
                    <xforms:input ref="@lastName">
                        <xforms:label>Last Name(s)</xforms:label>                        
                        <xforms:hint>Your last name(s)</xforms:hint>
                    </xforms:input>
                    <xforms:input ref="@organization">
                        <xforms:label>Organization</xforms:label>                        
                        <xforms:hint>The main organization unit you are representing with this user and assessment</xforms:hint>
                    </xforms:input>
                    <xforms:input ref="xcesc:eMail">
                        <xforms:label>e-mail</xforms:label>                        
                        <xforms:hint>The e-mail you want GOPHER to use when it needs to contact you</xforms:hint>
                    </xforms:input>
		    	<!--
			<xforms:input ref="sample:date">
				<xforms:label>Date</xforms:label>
			</xforms:input>
			<xforms:select1 ref="sample:withdraw" appearance="minimal" incremental="true">
				<xforms:label>Type</xforms:label>
				<xforms:item>
					<xforms:label>Withdraw</xforms:label>
					<xforms:value>true</xforms:value>
				</xforms:item>
				<xforms:item>
					<xforms:label>Deposit</xforms:label>
					<xforms:value>false</xforms:value>
				</xforms:item>
			</xforms:select1>
			<xforms:input ref="sample:desc" class="desc">
				<xforms:label>Description</xforms:label>
			</xforms:input>
			<xforms:input ref="sample:amount[../sample:withdraw = 'false']" class="amount">
				<xforms:label>Deposit</xforms:label>
			</xforms:input>
			<xforms:input ref="sample:amount[../sample:withdraw = 'true']" class="amount">
				<xforms:label>Withdraw</xforms:label>
			</xforms:input>
			-->
			<xforms:trigger class="delete">
				<xforms:label>X</xforms:label>
				<xforms:action ev:event="DOMActivate">
					<xforms:insert nodeset="xcesc:deletedUser" position="after" at="last()"/>
					<xforms:setvalue ref="xcesc:deletedUser[last()]/@nickname" value="@nickname"/>
					<xforms:setvalue ref="xcesc:deletedUser[last()]/@id" value="@id"/>
					<xforms:delete nodeset="." at="1" if="count(//xcesc:user) > 1"/>
				</xforms:action>
			</xforms:trigger>
		</xforms:repeat>
		<!--
		<table>
			<tr>
				<td style="width: 350px;">Totals</td>
				<td style="width: 90px; text-align: right;">
					<xforms:output ref="sample:totals/sample:in"/>
				</td>
				<td style="width: 90px; text-align: right;">
					<xforms:output ref="sample:totals/sample:out"/>
				</td>
			</tr>
			<tr>
				<td>Balance</td>
				<td colspan="2" style="text-align: right;">
					<xforms:output ref="sample:totals/sample:total"/>
				</td>
			</tr>
		</table>
		<xforms:trigger>
			<xforms:label>New withdraw</xforms:label>
			<xforms:action ev:event="DOMActivate">
				<xforms:insert nodeset="sample:transaction" position="after" at="last()"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:date" value="substring-before(now(), 'T')"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:amount" value="'0.00'"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:withdraw">true</xforms:setvalue>
				<xforms:setvalue ref="sample:transaction[last()]/sample:desc"/>
			</xforms:action>
		</xforms:trigger>
		<xforms:trigger>
			<xforms:label>New deposit</xforms:label>
			<xforms:action ev:event="DOMActivate">
				<xforms:insert nodeset="sample:transaction" position="after" at="last()"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:date" value="substring-before(now(), 'T')"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:amount" value="'0.00'"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:withdraw">false</xforms:setvalue>
				<xforms:setvalue ref="sample:transaction[last()]/sample:desc"/>
			</xforms:action>
		</xforms:trigger>
		-->
		<xforms:trigger>
			<xforms:label>New user</xforms:label>
			<xforms:action ev:event="DOMActivate">
				<xforms:insert nodeset="xcesc:user" position="after" at="last()"/>
				<xforms:setvalue ref="xcesc:user[last()]/@nickname" value="''"/>
				<xforms:setvalue ref="xcesc:user[last()]/@nickpass" value="''"/>
				<xforms:setvalue ref="xcesc:user[last()]/@firstName" value="''"/>
				<xforms:setvalue ref="xcesc:user[last()]/@lastName" value="''"/>
				<xforms:setvalue ref="xcesc:user[last()]/@organization" value="''"/>
				<xforms:setvalue ref="xcesc:user[last()]/xcesc:eMail" value="''"/>
				<!--
				<xforms:setvalue ref="sample:transaction[last()]/sample:date" value="substring-before(now(), 'T')"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:amount" value="'0.00'"/>
				<xforms:setvalue ref="sample:transaction[last()]/sample:withdraw">false</xforms:setvalue>
				<xforms:setvalue ref="sample:transaction[last()]/sample:desc"/>
				-->
			</xforms:action>
		</xforms:trigger>
		<xforms:submit submission="s01">
			<xforms:label>Save</xforms:label>
		</xforms:submit>
		<xforms:trigger>
			<xforms:label>Reset</xforms:label>
			<xforms:dispatch name="xforms-reset" target="default-model" ev:event="DOMActivate"/>
		</xforms:trigger>
		<div id="console">
			</div>
	</body>
</html>
(:
return	transform:stream-transform($content,xs:anyURI('xmldb:exist///db/forms/xsltforms/xsltforms.xsl'),())
return	transform:transform($content,xs:anyURI('xmldb:exist:///db/forms/xsltforms/xsltforms.xsl'),())
:)
	return	document {
		(processing-instruction {'xml-stylesheet'} {'href="xsltforms/xsltforms.xsl" type="text/xsl"'}
		,
		$content)
	}
) else (
	let $dum2:=util:declare-option('exist:serialize',"method=text media-type=text/plain")
	return $dumpost
)
