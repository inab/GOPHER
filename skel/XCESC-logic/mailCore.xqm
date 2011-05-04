(:
	mailCore.xqm
:)
xquery version "1.0" encoding "UTF-8";

module namespace mailcore = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/mailCore';

declare namespace meta="http://www.cnio.es/scombio/xcesc/1.0/xquery/metaManagement";
declare namespace xcesc="http://www.cnio.es/scombio/xcesc/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";

import module namespace util="http://exist-db.org/xquery/util";

import module namespace mail='http://exist-db.org/xquery/mail';
import module namespace core='http://www.cnio.es/scombio/xcesc/1.0/xquery/core' at "xmldb:exist:///db/XCESC-logic/core.xqm";

(:
declare variable $mailcore:mailCoreRoot as element(mailcore:mailCore) := collection($core:configColURI)//mailcore:mailCore[1];
declare variable $mailcore:mailConfiguration as element(properties) := $mailcore:mailCoreRoot/properties[1];
declare variable $mailcore:mailTemplate as element(mail) := $mailcore:mailCoreRoot/mail[1];
:)
declare variable $mailcore:mailCoreRoot as element(mailcore:mailCore) := subsequence(collection($core:configColURI)//mailcore:mailCore,1,1);
declare variable $mailcore:mailConfiguration as element(properties) := subsequence($mailcore:mailCoreRoot/properties,1,1);
declare variable $mailcore:mailTemplate as element(mail) := subsequence($mailcore:mailCoreRoot/mail,1,1);

(:
	This method sends e-mails, ignoring from elements and adding default ones from configuration
:)
declare function mailcore:send-email($messages as element(mail)+)
	as empty-sequence()
{
	let $session := mail:get-mail-session($mailcore:mailConfiguration)
	for $message in $messages
	let $fixedmessage := <mail>
		{$mailcore:mailTemplate/*}
		{$message/reply-to}
		{$message/to}
		{$message/cc}
		{$message/bcc}
		{$message/subject}
		{$message/message}
		{$message/attachment}
	</mail>
	return
		mail:send-email($session,$fixedmessage)
};
