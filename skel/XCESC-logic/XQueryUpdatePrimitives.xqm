(:~
 : Module which hides specific XQuery update extensions onto its primitives
 : @author José María Fernández
 :)
xquery version "1.0" encoding "UTF-8";

module namespace upd = 'http://www.cnio.es/scombio/xcesc/1.0/xquery/XQueryUpdatePrimitives';

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

(:~
 : Inserts $content immediately before $target
 : <ol>
 :	<li>Effects on nodes in $content:
 :		<ol>
 :			<li>For each node in $content, the parent property is set to parent($target).</li>
 :			<li>If the type-name property of parent($target) is xs:untyped, then upd:setToUntyped() is invoked on each element or attribute node in $content.</li>
 :		</ol>
 :	</li>
 :	<li>Effects on parent($target):
 :		<ol>
 :			<li>The children property of parent($target) is modified to add the nodes in $content just before $target, preserving their order.</li>
 :			<li>If at least one of the nodes in $content is an element or text node, upd:removeType(parent($target)) is invoked.</li>
 :		</ol>
 :	</li>
 :	<li>All the namespace bindings of parent($target) are marked for namespace propagation.</li>
 : </ol>
 : @author José María Fernández
 : @param $target It must be an element, text, processing instruction, or comment node with a non-empty parent property.
 : @param $content It must be a sequence containing only element, text, processing instruction, and comment nodes.
 :)
declare function upd:insertBefore($target as node(),$content as node()+)
	as empty-sequence()
{
	update insert $content preceding $target
};

(:~
 : Inserts $content immediately after $target.
 : <p>The semantics of <code>upd:insertAfter</code> are identical to
 : the semantics of <code>upd:insertBefore</code>, except that Rule 2a
 : is changed as follows:</p>
 : <ul>
 : <li>
 : <p>The <code>children</code> property of
 : <code>parent($target)</code> is modified to add the nodes in
 : <code>$content</code> just after <code>$target</code>, preserving
 : their order.</p>
 : </li>
 : </ul>
 : @author José María Fernández
 : @param $target It must be an element, text, processing instruction, or comment node with a non-empty parent property.
 : @param $content It must be a sequence containing only element, text, processing instruction, and comment nodes.
 :)
declare function upd:insertAfter($target as node(),$content as node()+)
	as empty-sequence()
{
	update insert $content following $target
};

(:~
 : Inserts $content as the children of $target, in an implementation-dependent position.
 : <p>The semantics of <code>upd:insertInto</code> are identical to
 : the semantics of <code>upd:insertBefore</code>, except that
 : <code>$target</code> is substituted everywhere for
 : <code>parent($target)</code>, and Rule 2a is changed as
 : follows:</p>
 : <ul>
 : <li>
 : <p>The <code>children</code> property of <code>$target</code> is
 : changed to add the nodes in <code>$content</code> in
 : implementation-dependent positions, preserving their relative
 : order.</p>
 : </li>
 : </ul>
 : @author José María Fernández
 : @param $target It must be an element or document node. $content must be a sequence containing only element, text, processing instruction, and comment nodes.
 : @param $content The content to insert into.
 :)
declare function upd:insertInto($target as node(),$content as node()+)
	as empty-sequence()
{
	update insert $content into $target
};

(:~
 : Inserts $content as the first children of $target.
 : <p>The semantics of <code>upd:insertIntoAsFirst</code> are
 : identical to the semantics of <code>upd:insertBefore</code>, except
 : that <code>$target</code> is substituted everywhere for
 : <code>parent($target)</code>, and Rule 2a is changed as
 : follows:</p>
 : <ul>
 : <li>
 : <p>The <code>children</code> property of <code>$target</code> is
 : changed to add the nodes in <code>$content</code> as the first
 : children, preserving their order.</p>
 : </li>
 : </ul>
 : @author José María Fernández
 : @param $target It must be an element or document node.
 : @param $content It must be a sequence containing only element, text, processing instruction, and comment nodes.
 :)
declare function upd:insertIntoAsFirst($target as node(),$content as node()+)
	as empty-sequence()
{
	update insert $content preceding $target/child::node()[1]
};

(:~
 : Inserts $content as the last children of $target.
 : <p>The semantics of <code>upd:insertIntoAsLast</code> are identical
 : to the semantics of <code>upd:insertBefore</code>, except that
 : <code>$target</code> is substituted everywhere for
 : <code>parent($target)</code>, and Rule 2a is changed as
 : follows:</p>
 : <ul>
 : <li>
 : <p>The <code>children</code> property of <code>$target</code> is
 : changed to add the nodes in <code>$content</code> as the last
 : children, preserving their order.</p>
 : </li>
 : </ul>
 : @author José María Fernández
 : @param $target It must be an element or document node.
 : @param $content It must be a sequence containing only element, text, processing instruction, and comment nodes.
 :)
declare function upd:insertIntoAsLast($target as node(),$content as node()+)
	as empty-sequence()
{
	update insert $content into $target
};

(:~
 : Inserts $content as attributes of $target.
 : <ol class="enumar">
 : <li>
 : <p>For each node <code>$A</code> in <code>$content</code>:</p>
 : <ol class="enumla">
 : <li>
 : <p>The <code>parent</code> property of <code>$A</code> is set to
 : <code>$target</code>.</p>
 : </li>
 : <li>
 : <p>If the <code>type-name</code> property of <code>$target</code>
 : is <code>xs:untyped</code>, then <code><a href="#id-upd-set-to-untyped">upd:setToUntyped</a>($A)</code> is
 : invoked.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>The following properties of <code>$target</code> are
 : changed:</p>
 : <ol class="enumla">
 : <li>
 : <p><code>attributes</code>: Modified to add the nodes in
 : <code>$content</code>.</p>
 : </li>
 : <li>
 : <p><code>namespaces:</code> Modified to add namespace bindings for
 : any attribute namespace prefixes in <code>$content</code> that did
 : not already have bindings. These bindings are <a title="mark" href="#dt-mark">marked for namespace propagation</a>.</p>
 : </li>
 : <li>
 : <p><code><a href="#id-upd-remove-type">upd:removeType</a>($target)</code> is
 : invoked.</p>
 : </li>
 : </ol>
 : </li>
 : </ol>
 : @author José María Fernández
 : @param $target
 : @param $content
 :)
declare function upd:insertAttributes($target as element(),$content as attribute()+)
	as empty-sequence()
{
	update insert $content into $target
};

(:~
 : It deletes the node from the external storage which hosts it
 : <ol class="enumar">
 : <li>
 : <p>If <code>$target</code> has a parent node <code>$P</code>,
 : then:</p>
 : <ol class="enumla">
 : <li>
 : <p>The <code>parent</code> property of <code>$target</code> is set
 : to empty.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is an attribute node, the
 : <code>attributes</code> property of <code>$P</code> is modified to
 : remove <code>$target</code>.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is a non-attribute node, the
 : <code>children</code> property of <code>$P</code> is modified to
 : remove <code>$target</code>.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is an element, attribute, or text node,
 : and <code>$P</code> is an element node, then <code><a href="#id-upd-remove-type">upd:removeType</a>($P)</code> is invoked.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>If <code>$target</code> has no parent, the <a title="XDM instance" href="#dt-xdm-instance">XDM instance</a> is
 : unchanged.</p>
 : </li>
 : </ol>
 : <div class="note">
 : <p class="prefix"><b>Note:</b></p>
 : <p>Deleted nodes are detached from their parent nodes; however, a
 : node deletion has no effect on variable bindings or on the set of
 : available documents or collections during processing of the current
 : query.</p>
 : </div>
 : <div class="note">
 : <p class="prefix"><b>Note:</b></p>
 : <p>Multiple <code>upd:delete</code> operations may be applied to
 : the same node during execution of a query; this is not an
 : error.</p>
 : </div>
 : @author José María Fernández
 : @param $target The node to delete from the storage
 :)
declare function upd:delete($target as node())
	as empty-sequence()
{
	typeswitch ($target)
		case document-node() return xmldb:remove(util:collection-name($target),util:document-name($target))
		case element() return
			typeswitch ($target/parent::node())
				case document-node() return xmldb:remove(util:collection-name($target),util:document-name($target))
				default return update delete $target
		default return update delete $target
};

(:~
 : Replaces $target with $replacement.
 : @author José María Fernández
 : <ol class="enumar">
 : <li>
 : <p>Effects on nodes in <code>$replacement</code>:</p>
 : <ol class="enumla">
 : <li>
 : <p>For each node in <code>$replacement</code>, the
 : <code>parent</code> property is set to
 : <code>parent($target)</code>.</p>
 : </li>
 : <li>
 : <p>If the <code>type-name</code> property of
 : <code>parent($target)</code> is <code>xs:untyped</code>, then
 : <code><a href="#id-upd-set-to-untyped">upd:setToUntyped</a>()</code> is invoked
 : on each node in <code>$replacement</code>.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>Effect on <code>$target</code>:</p>
 : <ol class="enumla">
 : <li>
 : <p>The <code>parent</code> property of <code>$target</code> is set
 : to empty.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>Effects on <code>parent($target)</code>:</p>
 : <ol class="enumla">
 : <li>
 : <p>If <code>$target</code> is an attribute node, the
 : <code>attributes</code> property of <code>parent($target)</code> is
 : modified by removing <code>$target</code> and adding the nodes in
 : <code>$replacement</code> (if any).</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is an attribute node, the
 : <code>namespaces</code> property of <code>parent($target)</code> is
 : modified to add namespace bindings for any attribute namespace
 : prefixes in <code>$replacement</code> that did not already have
 : bindings. These bindings are <a title="mark" href="#dt-mark">marked
 : for namespace propagation</a>.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is an element, text, comment, or
 : processing instruction node, the <code>children</code> property of
 : <code>parent($target)</code> is modified by removing
 : <code>$target</code> and adding the nodes in
 : <code>$replacement</code> (if any) in the former position of
 : <code>$target</code>, preserving their order.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> or any node in <code>$replacement</code>
 : is an element, attribute, or text node, <code><a href="#id-upd-remove-type">upd:removeType</a>(parent($target))</code> is
 : invoked.</p>
 : </li>
 : </ol>
 : </li>
 : </ol>
 : @param $target must be a node that has a parent. If $target is an attribute node, $replacement must consist of zero or more attribute nodes.
 : If $target is an element, text, comment, or processing instruction node, $replacement must be consist of zero or more element, text, comment,
 : or processing instruction nodes.
 : @param $replacement The replacement node
 :)
declare function upd:replaceNode($target as node(),$replacement as node()*)
	as empty-sequence()
{
	if(count($replacement) ne 1) then (
		upd:insertBefore($target,$replacement),
		upd:delete($target)
	) else (
		update replace $target with $replacement
	)
};

(:~
 : Replaces the string value of $target with $string-value.
 : <ol class="enumar">
 : <li>
 : <p>If <code>$target</code> is an attribute node:</p>
 : <ol class="enumla">
 : <li>
 : <p><code>string-value</code> of <code>$target</code> is set to
 : <code>$string-value</code>.</p>
 : </li>
 : <li>
 : <p><code><a href="#id-upd-remove-type">upd:removeType</a>($target)</code> is
 : invoked.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>If <code>$target</code> is a text, comment, or processing
 : instruction node: <code>content</code> of <code>$target</code> is
 : set to <code>$string-value</code>.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> is a text node that has a parent,
 : <code><a href="#id-upd-remove-type">upd:removeType</a>(parent($target))</code> is
 : invoked.</p>
 : </li>
 : </ol>
 : @author José María Fernández
 : @param $target It must be an attribute, text, comment, or processing instruction node.
 : @param $string-value The new string value
 :)
declare function upd:replaceValue($target as node(),$string-value as xs:string)
	as empty-sequence()
{
	update value $target with $string-value
};

(:~
 : Replaces the existing children of the element node $target by the optional text node $text. The attributes of $target are not affected.
 : <ol class="enumar">
 : <li>
 : <p>For each node <code>$C</code> that is a child of
 : <code>$target</code>, the <code>parent</code> property of
 : <code>$C</code> is set to empty.</p>
 : </li>
 : <li>
 : <p>The <code>parent</code> property of <code>$text</code> is set to
 : <code>$target</code>.</p>
 : </li>
 : <li>
 : <p>Effects on <code>$target</code>:</p>
 : <ol class="enumla">
 : <li>
 : <p><code>children</code> is set to consist exclusively of
 : <code>$text</code>. If <code>$text</code> is an empty sequence,
 : then <code>$target</code> has no children.</p>
 : </li>
 : <li>
 : <p><code>typed-value</code> and <code>string-value</code> are set
 : to the <code>content</code> property of <code>$text</code>. If
 : <code>$text</code> is an empty sequence, then
 : <code>typed-value</code> is an empty sequence and
 : <code>string-value</code> is an empty string.</p>
 : </li>
 : <li>
 : <p><code><a href="#id-upd-remove-type">upd:removeType($target)</a></code> is
 : invoked.</p>
 : </li>
 : </ol>
 : </li>
 : </ol>
 : @author José María Fernández
 : @param $target The element with the text nodes to be replaced to
 : @param $text The text to replace the original text nodes of $target
 :)
declare function upd:replaceElementContent($target as element(),$text as text()?)
	as empty-sequence()
{
	update replace $target/text() with $text
};

(:~
 : Changes the node-name of $target to $newName.
 : <ol class="enumar">
 : <li>
 : <p>If <code>$target</code> is an element node:</p>
 : <ol class="enumla">
 : <li>
 : <p><code>node-name</code> of <code>$target</code> is set to
 : <code>$newName</code>.</p>
 : </li>
 : <li>
 : <p><code><a href="#id-upd-remove-type">upd:removeType</a>($target)</code> is
 : invoked.</p>
 : </li>
 : <li>
 : <p>If <code>$newname</code> has no prefix and no namespace URI, the
 : <code>namespaces</code> property of <code>$target</code> is
 : modified by removing the binding (if any) for the empty prefix.</p>
 : </li>
 : <li>
 : <p>The <code>namespaces</code> property of <code>$target</code> is
 : modified to add a namespace binding derived from
 : <code>$newName</code>, if this binding did not already exist. This
 : binding is <a title="mark" href="#dt-mark">marked for namespace
 : propagation</a>.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>If <code>$target</code> is an attribute node:</p>
 : <ol class="enumla">
 : <li>
 : <p><code>node-name</code> of <code>$target</code> is set to
 : <code>$newName</code>.</p>
 : </li>
 : <li>
 : <p><code><a href="#id-upd-remove-type">upd:removeType</a>($target)</code> is
 : invoked.</p>
 : </li>
 : <li>
 : <p>If <code>$newName</code> is <code>xml:id</code>, the
 : <code>is-id</code> property of <code>$target</code> is set to
 : <code>true</code>.</p>
 : </li>
 : <li>
 : <p>If <code>$target</code> has a parent, the
 : <code>namespaces</code> property of <code>parent($target)</code> is
 : modified to add a namespace binding derived from
 : <code>$newName</code>, if this binding did not already exist. This
 : binding is <a title="mark" href="#dt-mark">marked for namespace
 : propagation</a>.</p>
 : </li>
 : </ol>
 : </li>
 : <li>
 : <p>If <code>$target</code> is a processing instruction node, its
 : <code>target</code> property is set to the local part of
 : <code>$newName</code>.</p>
 : </li>
 : </ol>
 : <div class="note">
 : <p class="prefix"><b>Note:</b></p>
 : <p>At the end of a <a title="snapshot" href="#dt-snapshot">snapshot</a>, if multiple attribute nodes with the
 : same parent have the same qualified name, an error will be raised
 : by <code>upd:applyUpdates</code>.</p>
 : </div>
 : @author José María Fernández
 : @param $target must be an element, attribute, or processing instruction node.
 : @param $newName The new QName of $target node
 :)
declare function upd:rename($target as node(),$newName as xs:QName)
	as empty-sequence()
{
	update rename $target as $newName
};

(:~
 : The XDM node tree rooted at $node is stored to the location specified by $uri.
 : @author José María Fernández
 : @param $node A node
 : @param $uri must be a valid absolute URI.
 :)
declare function upd:put($node as node(),$uri as xs:string)
	as empty-sequence()
{
	let $resolvedUri := resolve-uri($uri)
	let $tokens := tokenize($resolvedUri, '/')
	let $numTokens := count($tokens)
	let $docName := $tokens[$numTokens]
	let $colName := string-join(subsequence(sourceSeq, 1, $numTokens - 1), '/')
	return
		xmldb:store($colName,$docName,$node)
};

(:~
 :
 : @author José María Fernández
 : @param
 :)
(:
declare function upd:mergeUpdates($pul1 as pending-update-list,$pul2 as pending-update-list)
	as empty-sequence()
{
	error()
};
:)

(:~
 :
 : @author José María Fernández
 : @param
 :)
(:
declare function upd:applyUpdates($pul as pending-update-list,$revalidation-mode as xs:string,$inherit-namespaces as xs:boolean)
	as empty-sequence()
{
	error()
};
:)

(:~
 :
 : @author José María Fernández
 : @param
 :)
declare function upd:revalidate($top as node(),$revalidation-mode as xs:string)
	as empty-sequence()
{
	error()
};

(:~
 :
 : @author José María Fernández
 : @param
 :)
declare function upd:removeType($N as node())
	as empty-sequence()
{
	error()
};

(:~
 :
 : @author José María Fernández
 : @param
 :)
declare function upd:setToUntyped($N as node())
	as empty-sequence()
{
	error()
};

(:~
 :
 : @author José María Fernández
 : @param
 :)
declare function upd:propagateNamespace($element as element(),$prefix as xs:NCName,$uri as xs:anyURI)
	as empty-sequence()
{
	error()
};
